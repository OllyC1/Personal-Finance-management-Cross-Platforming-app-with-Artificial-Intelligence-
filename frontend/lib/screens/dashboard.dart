import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/screens/reports.dart';
import 'package:frontend/screens/expenses.dart' as exp;
import 'package:frontend/screens/income.dart' as inc;
import 'package:frontend/screens/budget.dart';
import 'package:frontend/screens/savings.dart';
import 'package:frontend/screens/prediction.dart';
import 'package:frontend/services/auth_service.dart';
import 'dart:math' as math; // Fixed: Changed Math to math for Dart naming conventions
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';
import 'package:frontend/services/api_service_wrapper.dart'; // Import ApiServiceWrapper

/// Helper function that converts a dynamic value into a double.
double parseDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class DashboardScreen extends StatefulWidget {
  final String token;
  const DashboardScreen({super.key, required this.token});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  late AnimationController _animationController;
  
  // Data variables.
  String _username = '';
  double totalIncome = 0.0;
  double totalExpenses = 0.0;
  double totalSavings = 0.0;
  double totalBudget = 0.0;
  double totalDebt = 0.0;
  List<Map<String, dynamic>> budgets = [];
  List<Map<String, dynamic>> alerts = [];
  
  // UI state variables
  bool _isSidebarOpen = false;
  bool _isLoading = true;
  bool _showWelcomeAnimation = false;
  String _selectedTimeframe = 'This Month';
  final List<String> _timeframes = ['This Month', 'Last Month', 'Last 3 Months', 'This Year'];
  
  // For pull to refresh
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  // For animations
  final List<GlobalKey<AnimatedListState>> _listKeys = [
    GlobalKey<AnimatedListState>(),
    GlobalKey<AnimatedListState>(),
  ];

  double get balanceLeft =>
      totalIncome - (totalExpenses);

  /// Returns the current month in "yyyy-MM" format.
  String get currentMonthParam => DateFormat('yyyy-MM').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _loadData();
    
    // Show welcome animation if it's the first login of the day
    _checkIfFirstLogin();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _checkIfFirstLogin() async {
    final lastLogin = await _secureStorage.read(key: 'last_login_date');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    if (lastLogin != today) {
      setState(() {
        _showWelcomeAnimation = true;
      });
      await _secureStorage.write(key: 'last_login_date', value: today);
      
      // Hide welcome animation after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showWelcomeAnimation = false;
          });
        }
      });
    }
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    await Future.wait([
      _fetchUsername(),
      _fetchTotals(),
      _fetchAlerts(),
    ]);
    
    setState(() {
      _isLoading = false;
    });
    
    // Start animation
    _animationController.forward(from: 0.0);
  }

  /// Fetch the logged-in user's username from the backend.
  Future<void> _fetchUsername() async {
    try {
      // Get a fresh token using AuthService
      final authService = AuthService();
      final token = await authService.getIdToken(forceRefresh: true) ?? widget.token;
      
      // Fixed: Changed print to debugPrint and Math to math
      debugPrint('Using token for API call: ${token.substring(0, math.min(20, token.length))}...');
      
      final response = await ApiServiceWrapper().getUserProfile();
      
      setState(() {
        _username = response['username'] ?? '';
      });
    } catch (e) {
      _showError('Error fetching username: $e');
    }
  }

  Future<void> _fetchTotals() async {
    await Future.wait([
      _fetchTotalIncome(),
      _fetchTotalExpenses(),
      _fetchTotalBudget(),
      _fetchGoalsProgress(),
    ]);
  }

  Future<void> _fetchTotalIncome() async {
    try {
      final response = await ApiServiceWrapper().getIncome(month: currentMonthParam);
      setState(() {
        totalIncome = response.fold(
            0.0, (sum, income) => sum + (income['amount'] ?? 0));
      });
    } catch (e) {
      _showError('Error fetching income: $e');
    }
  }

  Future<void> _fetchTotalExpenses() async {
    try {
      final response = await ApiServiceWrapper().getExpenses(month: currentMonthParam);
      setState(() {
        totalExpenses = response.fold(
            0.0, (sum, expense) => sum + (expense['amount'] ?? 0));
      });
    } catch (e) {
      _showError('Error fetching expenses: $e');
    }
  }

  Future<void> _fetchTotalBudget() async {
    try {
      final response = await ApiServiceWrapper().getBudgets(month: currentMonthParam);
      setState(() {
        budgets = List<Map<String, dynamic>>.from(response);
        totalBudget = response.fold(
            0.0, (sum, budget) => sum + (budget['budget'] ?? 0));
      });
    } catch (e) {
      _showError('Error fetching budgets: $e');
    }
  }

  Future<void> _fetchGoalsProgress() async {
    try {
      final response = await ApiServiceWrapper().getGoalDetails();
      double savings = 0.0;
      double debt = 0.0;

      for (var goal in response) {
        if (goal['type'] != null && goal['progress'] != null) {
          final String goalType = (goal['type'] as String).toLowerCase();
          final double progress = parseDouble(goal['progress']);
          if (goalType == 'savings') {
            savings += progress;
          } else if (goalType == 'debt') {
            debt += progress;
          }
        }
      }
      setState(() {
        totalSavings = savings;
        totalDebt = debt;
      });
    } catch (e) {
      _showError('Error fetching goals progress: $e');
    }
  }

  Future<void> _fetchAlerts() async {
    try {
      final response = await ApiServiceWrapper().getAlerts(month: currentMonthParam);

      if (response.containsKey('alerts')) {
        final alertsData = response['alerts'];
        setState(() {
          alerts = List<Map<String, dynamic>>.from(alertsData);
        });
        if (alerts.isNotEmpty) {
          _showNotification('You have ${alerts.length} alerts', 'Check your budget status');
        }
      } else {
        _showError('No "alerts" key found in response');
      }
    } catch (e) {
      _showError('Error fetching alerts: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 4),
      ),
    );
  }
  
  void _showNotification(String title, String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      message,
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            // Scroll to alerts section
            Scrollable.ensureVisible(
              GlobalObjectKey('alerts_section').currentContext!,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          },
        ),
      ),
    );
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.blue.shade700),
            const SizedBox(width: 10),
            Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseAuth.instance.signOut();
                await _secureStorage.delete(key: 'authToken');
                if (!mounted) return; // Fixed: Check if widget is still mounted
                Navigator.pushReplacementNamed(context, '/login');
              } catch (e) {
                _showError('Logout failed: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/connection-test');
           },
            child: Text('Connection Diagnostics'),
          )
        ],
      ),
    );
  }

  

  Widget _buildSidebarOverlay() {
  return Positioned.fill(
    child: Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Semi-transparent background overlay that covers the entire screen
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isSidebarOpen = false;
                });
              },
              child: AnimatedOpacity(
                opacity: _isSidebarOpen ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ),
          ),
          
          // Sidebar with animation - using Material to ensure proper elevation
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: _isSidebarOpen ? 0 : -280,
            top: 0,
            bottom: 0,
            width: 280,
            child: Material(
              elevation: 16,
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {}, // Prevent tap from closing sidebar when tapping inside it
                onHorizontalDragEnd: (details) {
                  // Add swipe to close functionality
                  if (details.primaryVelocity! < 0) { // Swipe left
                    setState(() {
                      _isSidebarOpen = false;
                    });
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1E3A8A), // Dark blue
                        const Color(0xFF3B82F6), // Medium blue
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header with close button
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundImage: AssetImage('assets/Olly.jpg'),
                              radius: 30,
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _username.isNotEmpty ? _username : 'User',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Manage your finances',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Close button
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _isSidebarOpen = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      // Menu Items
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: AnimationLimiter(
                            child: Column(
                              children: AnimationConfiguration.toStaggeredList(
                                duration: const Duration(milliseconds: 600),
                                childAnimationBuilder: (widget) => SlideAnimation(
                                  horizontalOffset: -50.0,
                                  child: FadeInAnimation(
                                    child: widget,
                                  ),
                                ),
                                children: [
                                  _buildSidebarCategory('Financial Management'),
                                  SidebarActionItem(
                                    label: 'Dashboard',
                                    icon: Icons.dashboard_rounded,
                                    onTap: () {
                                      setState(() {
                                        _isSidebarOpen = false;
                                      });
                                    },
                                    isActive: true,
                                  ),
                                  SidebarActionItem(
                                    label: 'Manage Income',
                                    icon: Icons.attach_money_rounded,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => inc.IncomePage()),
                                      ).then((_) => _loadData());
                                      setState(() {
                                        _isSidebarOpen = false;
                                      });
                                    },
                                  ),
                                  SidebarActionItem(
                                    label: 'Manage Expenses',
                                    icon: Icons.money_off_rounded,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => exp.ExpensePage()),
                                      ).then((_) => _loadData());
                                      setState(() {
                                        _isSidebarOpen = false;
                                      });
                                    },
                                  ),
                                  SidebarActionItem(
                                    label: 'Set Budgets',
                                    icon: Icons.account_balance_wallet_rounded,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => BudgetPage()),
                                      ).then((_) => _loadData());
                                      setState(() {
                                        _isSidebarOpen = false;
                                      });
                                    },
                                  ),
                                  
                                  _buildSidebarCategory('Goals & Analysis'),
                                  SidebarActionItem(
                                    label: 'Financial Goals',
                                    icon: Icons.savings_rounded,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => SavingsDebtPage()),
                                      ).then((_) => _loadData());
                                      setState(() {
                                        _isSidebarOpen = false;
                                      });
                                    },
                                  ),
                                  SidebarActionItem(
                                    label: 'Reports & Insights',
                                    icon: Icons.analytics_rounded,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => ReportsPage()),
                                      ).then((_) => _loadData());
                                      setState(() {
                                        _isSidebarOpen = false;
                                      });
                                    },
                                  ),
                                  SidebarActionItem(
                                    label: 'Next Month Prediction',
                                    icon: Icons.calendar_today_rounded,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => PredictionPage()),
                                      ).then((_) => _loadData());
                                      setState(() {
                                        _isSidebarOpen = false;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Footer
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _logout,
                                icon: const Icon(Icons.logout_rounded, size: 18),
                                label: Text(
                                  'Logout',
                                  style: GoogleFonts.poppins(),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blue.shade800,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
  
  Widget _buildSidebarCategory(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.5),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection() {
    return AnimationConfiguration.staggeredList(
      position: 1,
      delay: const Duration(milliseconds: 100),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: Container(
            key: GlobalObjectKey('alerts_section'),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.notifications_rounded,
                            color: Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Alerts & Notifications',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: alerts.isEmpty ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          alerts.isEmpty ? 'All Clear' : '${alerts.length} Alerts',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: alerts.isEmpty ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Divider
                Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.1)),
                
                // Alerts content
                AnimatedCrossFade(
                  firstChild: _buildAlertsContent(),
                  secondChild: _buildEmptyAlertsContent(),
                  crossFadeState: alerts.isEmpty ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAlertsContent() {
    return AnimatedList(
      key: _listKeys[0],
      initialItemCount: alerts.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index, animation) {
        final alert = alerts[index];
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuint,
          )),
          child: Dismissible(
            key: Key('alert_${index}_${alert['_id'] ?? DateTime.now().toString()}'),
            background: Container(
              color: Colors.red.shade400,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) {
              setState(() {
                alerts.removeAt(index);
              });
              // Here you would also call an API to dismiss the alert on the server
            },
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    alert['category'] ?? 'Alert',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    alert['message'] ?? 'No details available',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onPressed: () {
                      // Navigate to relevant section based on alert category
                      String category = (alert['category'] ?? '').toLowerCase();
                      if (category.contains('budget')) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => BudgetPage()),
                        ).then((_) => _loadData());
                      } else if (category.contains('expense')) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => exp.ExpensePage()),
                        ).then((_) => _loadData());
                      }
                    },
                  ),
                ),
                if (index < alerts.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey.withOpacity(0.1),
                    indent: 16,
                    endIndent: 16,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildEmptyAlertsContent() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 60,
              color: Colors.green.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'All Clear!',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have no alerts or notifications at the moment.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummaryCard() {
    // Calculate percentages for the progress indicators
    double expensePercentage = totalBudget > 0 ? (totalExpenses / totalBudget).clamp(0.0, 1.0) : 0.0;
    double savingsPercentage = totalIncome > 0 ? (totalSavings / totalIncome).clamp(0.0, 1.0) : 0.0;
    
    return AnimationConfiguration.staggeredList(
      position: 0,
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E3A8A), // Dark blue
                  const Color(0xFF3B82F6), // Medium blue
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 0,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // If we have limited width, stack the elements vertically
                      if (constraints.maxWidth < 300) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Financial Summary',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  DateFormat('MMMM yyyy').format(DateTime.now()),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedTimeframe,
                                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
                                iconSize: 16,
                                isDense: true,
                                underline: const SizedBox(),
                                dropdownColor: Colors.blue.shade800,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedTimeframe = newValue;
                                      // Here you would fetch data for the selected timeframe
                                    });
                                  }
                                },
                                items: _timeframes.map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        );
                      } else {
                        // For wider screens, use a row with proper constraints
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Financial Summary',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    DateFormat('MMMM yyyy').format(DateTime.now()),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedTimeframe,
                                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
                                iconSize: 16,
                                isDense: true,
                                underline: const SizedBox(),
                                dropdownColor: Colors.blue.shade800,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedTimeframe = newValue;
                                      // Here you would fetch data for the selected timeframe
                                    });
                                  }
                                },
                                items: _timeframes.map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
                
                // Balance Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Current Balance',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: balanceLeft >= 0 ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                balanceLeft >= 0 ? 'Positive' : 'Negative',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: balanceLeft >= 0 ? Colors.green.shade300 : Colors.red.shade300,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Use FittedBox for the balance amount to prevent overflow
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '£${balanceLeft.abs().toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                balanceLeft >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                                color: balanceLeft >= 0 ? Colors.green.shade300 : Colors.red.shade300,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Progress Indicators
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Expenses Progress
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Expenses vs Budget',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Stack(
                                  children: [
                                    // Background
                                    Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    // Progress
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 800),
                                      curve: Curves.easeInOut,
                                      height: 8,
                                      width: MediaQuery.of(context).size.width * 0.5 * expensePercentage,
                                      decoration: BoxDecoration(
                                        color: expensePercentage > 0.9 ? Colors.red.shade300 : Colors.green.shade300,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '£${totalExpenses.toStringAsFixed(2)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                    Text(
                                      '£${totalBudget.toStringAsFixed(2)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Savings Progress
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Savings vs Income',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Stack(
                                  children: [
                                    // Background
                                    Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    // Progress
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 800),
                                      curve: Curves.easeInOut,
                                      height: 8,
                                      width: MediaQuery.of(context).size.width * 0.5 * savingsPercentage,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade300,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '£${totalSavings.toStringAsFixed(2)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                    Text(
                                      '£${totalIncome.toStringAsFixed(2)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(bool isWideScreen) {
    return AnimationConfiguration.staggeredList(
      position: 2,
      delay: const Duration(milliseconds: 200),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: GridView.count(
            crossAxisCount: isWideScreen ? 3 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 600),
              childAnimationBuilder: (widget) => SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: widget,
                ),
              ),
              children: [
                _buildInteractiveStatCard(
                  title: 'Total Income',
                  value: '£${totalIncome.toStringAsFixed(2)}',
                  color: Colors.green,
                  icon: Icons.attach_money_rounded,
                  backgroundImage: 'assets/income.jpg',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => inc.IncomePage()),
                    ).then((_) => _loadData());
                  },
                ),
                _buildInteractiveStatCard(
                  title: 'Total Expenses',
                  value: '£${totalExpenses.toStringAsFixed(2)}',
                  color: Colors.red,
                  icon: Icons.money_off_rounded,
                  backgroundImage: 'assets/expenses.jpg',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => exp.ExpensePage()),
                    ).then((_) => _loadData());
                  },
                ),
                _buildInteractiveStatCard(
                  title: 'Total Savings',
                  value: '£${totalSavings.toStringAsFixed(2)}',
                  color: Colors.blue,
                  icon: Icons.savings_rounded,
                  backgroundImage: 'assets/savings.jpg',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SavingsDebtPage()),
                    ).then((_) => _loadData());
                  },
                ),
                _buildInteractiveStatCard(
                  title: 'Debt Payment',
                  value: '£${totalDebt.toStringAsFixed(2)}',
                  color: Colors.purple,
                  icon: Icons.credit_card_rounded,
                  backgroundImage: 'assets/debt.jpg',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SavingsDebtPage()),
                    ).then((_) => _loadData());
                  },
                ),
                _buildInteractiveStatCard(
                  title: 'Total Budget',
                  value: '£${totalBudget.toStringAsFixed(2)}',
                  color: Colors.orange,
                  icon: Icons.account_balance_wallet_rounded,
                  backgroundImage: 'assets/budget.jpg',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => BudgetPage()),
                    ).then((_) => _loadData());
                  },
                ),
                _buildInteractiveStatCard(
                  title: 'Balance Left',
                  value: '£${balanceLeft.toStringAsFixed(2)}',
                  color: balanceLeft >= 0 ? Colors.green : Colors.red,
                  icon: Icons.balance_rounded,
                  backgroundImage: 'assets/balance.jpg',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ReportsPage()),
                    ).then((_) => _loadData());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required String backgroundImage,
    required VoidCallback onTap,
  }) {
    return InteractiveStatCard(
      title: title,
      value: value,
      color: color,
      icon: icon,
      backgroundImage: backgroundImage,
      onTap: onTap,
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.blue.shade900,
      highlightColor: Colors.blue.shade700,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header Shimmer
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 200,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 150,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Financial Summary Card Shimmer
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 16),
            
            // Alerts Section Shimmer
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 16),
            
            // Stats Grid Header Shimmer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 150,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 100,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Stats Grid Shimmer
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(
                6,
                (index) => Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 800;
    final screenHeight = MediaQuery.of(context).size.height;

    Widget mainContent = _isLoading
        ? _buildLoadingShimmer()
        : RefreshIndicator(
            key: _refreshIndicatorKey,
            color: Colors.white,
            backgroundColor: Colors.blue.shade700,
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: AnimationLimiter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Header
                    AnimationConfiguration.staggeredList(
                      position: 0,
                      child: SlideAnimation(
                        horizontalOffset: -50.0,
                        child: FadeInAnimation(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Row(
                              children: [
                                Hero(
                                  tag: 'profile_avatar',
                                  child: Material(
                                    elevation: 4,
                                    shape: const CircleBorder(),
                                    clipBehavior: Clip.hardEdge,
                                    child: InkWell(
                                      onTap: () {
                                        // Show profile options
                                        HapticFeedback.mediumImpact();
                                        // Add profile view functionality here
                                      },
                                      child: const CircleAvatar(
                                        backgroundImage: AssetImage('assets/Olly.jpg'),
                                        radius: 30,
                                        backgroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _username.isNotEmpty ? 'Welcome back, $_username!' : 'Welcome back!',
                                        style: GoogleFonts.poppins(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        'Let\'s manage your finances today',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Financial Summary Card
                    _buildFinancialSummaryCard(),
                    
                    // Alerts Section
                    _buildAlertsSection(),
                    
                    // Stats Grid Header
                    AnimationConfiguration.staggeredList(
                      position: 2,
                      delay: const Duration(milliseconds: 150),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Financial Overview',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => ReportsPage()),
                                    ).then((_) => _loadData());
                                  },
                                  icon: const Icon(Icons.analytics_rounded, size: 18, color: Colors.white),
                                  label: Text(
                                    'View Reports',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Stats Grid
                    _buildStatsGrid(isWideScreen),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () {
            HapticFeedback.mediumImpact();
            setState(() {
              _isSidebarOpen = true;
            });
          },
        ),
        title: Row(
          children: [
            Image.asset('assets/Olly.jpg', height: 30),
            const SizedBox(width: 10),
            Text(
              'Olly Finance',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Data',
            onPressed: () {
              HapticFeedback.mediumImpact();
              _loadData();
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () {
              HapticFeedback.mediumImpact();
              _logout();
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1E3A8A), // Dark blue
                  Color(0xFF3B82F6), // Medium blue
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: screenHeight),
              child: SafeArea(child: mainContent),
            ),
          ),
          
          // Welcome Animation Overlay
          if (_showWelcomeAnimation)
            AnimatedOpacity(
              opacity: _showWelcomeAnimation ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Simple animation instead of Lottie
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: const CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.check,
                            size: 60,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Welcome Back!',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _username.isNotEmpty ? 'Good to see you, $_username' : 'Good to see you again',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Sidebar Overlay
          if (_isSidebarOpen) _buildSidebarOverlay(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Show quick actions menu
          HapticFeedback.mediumImpact();
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => _buildQuickActionsSheet(),
          );
        },
        backgroundColor: Colors.white,
        child: Icon(Icons.add, color: Colors.blue.shade800),
      ),
    );
  }
  
  Widget _buildQuickActionsSheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Quick Actions',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          AnimationLimiter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 400),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: widget,
                  ),
                ),
                children: [
                  _buildQuickActionButton(
                    icon: Icons.attach_money_rounded,
                    label: 'Add Income',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => inc.IncomePage()),
                      ).then((_) => _loadData());
                    },
                  ),
                  _buildQuickActionButton(
                    icon: Icons.money_off_rounded,
                    label: 'Add Expense',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => exp.ExpensePage()),
                      ).then((_) => _loadData());
                    },
                  ),
                  _buildQuickActionButton(
                    icon: Icons.savings_rounded,
                    label: 'Add Goal',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SavingsDebtPage()),
                      ).then((_) => _loadData());
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InteractiveStatCard extends StatefulWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final String backgroundImage;
  final VoidCallback onTap;

  const InteractiveStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    required this.backgroundImage,
    required this.onTap,
  });

  @override
  _InteractiveStatCardState createState() => _InteractiveStatCardState();
}

class _InteractiveStatCardState extends State<InteractiveStatCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _animationController.forward();
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        _animationController.reverse();
      },
      onTapCancel: () {
        _animationController.reverse();
      },
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() {
          _isHovered = true;
        }),
        onExit: (_) => setState(() {
          _isHovered = false;
        }),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(_isHovered ? 0.3 : 0.1),
                      blurRadius: _isHovered ? 15 : 10,
                      spreadRadius: _isHovered ? 2 : 0,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Background image with overlay
                      Positioned.fill(
                        child: Image.asset(
                          widget.backgroundImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback if image doesn't load
                            return Container(
                              color: widget.color.withOpacity(0.05),
                            );
                          },
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.9),
                                Colors.white.withOpacity(0.7),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon and Title
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: widget.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    widget.icon,
                                    size: 20,
                                    color: widget.color,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const Spacer(),
                            
                            // Value
                            Text(
                              widget.value,
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: widget.color,
                              ),
                            ),
                            
                            // View Details Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'View Details',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black54,
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 12,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class SidebarActionItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const SidebarActionItem({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  _SidebarActionItemState createState() => _SidebarActionItemState();
}

class _SidebarActionItemState extends State<SidebarActionItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() {
        _isHovered = true;
      }),
      onExit: (_) => setState(() {
        _isHovered = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.isActive || _isHovered
              ? Colors.white.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            widget.onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.isActive ? Colors.white : Colors.white.withOpacity(0.7),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isActive ? Colors.white : Colors.white.withOpacity(0.7),
                ),
              ),
              if (widget.isActive) ...[
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
