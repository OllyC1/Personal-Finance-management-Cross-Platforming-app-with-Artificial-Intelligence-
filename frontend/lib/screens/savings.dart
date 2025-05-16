import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:frontend/services/api_service_wrapper.dart';

class SavingsDebtPage extends StatefulWidget {
  const SavingsDebtPage({super.key, this.initialTabIndex = 0});
  final int initialTabIndex;

  @override
  _SavingsDebtPageState createState() => _SavingsDebtPageState();
}

class _SavingsDebtPageState extends State<SavingsDebtPage> with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _progressController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  final ApiServiceWrapper _apiService = ApiServiceWrapper();

  // Goals fetched from backend with computed details.
  List<Map<String, dynamic>> _goalDetails = [];
  List<Map<String, dynamic>> _linkedExpenses = []; // Added to store linked expenses
  String? _editingGoalId;
  bool isSaving = true; // Toggle between Savings and Debt
  
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasError = false;
  String _errorMessage = '';
  
  // For summary stats
  double _totalGoalAmount = 0.0;
  double _totalProgress = 0.0;
  double _totalRemaining = 0.0;
  int _goalCount = 0;
  
  // For sorting
  String _sortBy = 'name';
  bool _sortAscending = true;
  
  // Tab controller for switching between Savings and Debt
  late TabController _tabController;
  
  // Animation controllers
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      setState(() {
        isSaving = _tabController.index == 0;
        _fetchGoalDetails();
      });
    });
    
    // Initialize FAB animation
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    
    _fabAnimationController.forward();
    
    _fetchGoalDetails();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _durationController.dispose();
    _progressController.dispose();
    _searchController.dispose();
    _tabController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  // Modify the _fetchGoalDetails method to use ApiServiceWrapper
  Future<void> _fetchGoalDetails() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
      _goalDetails = []; // Clear existing data first
    });
    
    try {
      // Use ApiServiceWrapper to fetch goal details
      final response = await _apiService.getGoalDetails();
      
      if (response != null) {
        List<Map<String, dynamic>> fetched = List<Map<String, dynamic>>.from(response)
            // Filter by type (Savings or Debt)
            .where((goal) => goal['type'] == (isSaving ? 'Savings' : 'Debt'))
            .toList();
        
        // Debug: Print all goals to see what's coming from the server
        print('Fetched ${fetched.length} goals from server');
        for (var goal in fetched) {
          print('Goal: ${goal['name']}, Progress: ${goal['progress']}, Amount: ${goal['amount']}');
        }
        
        // Sort the goals list
        fetched.sort((a, b) {
          if (_sortBy == 'amount') {
            final double amountA = a['amount']?.toDouble() ?? 0.0;
            final double amountB = b['amount']?.toDouble() ?? 0.0;
            return _sortAscending ? amountA.compareTo(amountB) : amountB.compareTo(amountA);
          } else if (_sortBy == 'progress') {
            final double progressA = a['progress']?.toDouble() ?? 0.0;
            final double progressB = b['progress']?.toDouble() ?? 0.0;
            return _sortAscending ? progressA.compareTo(progressB) : progressB.compareTo(progressA);
          } else if (_sortBy == 'duration') {
            final int durationA = a['duration'] ?? 0;
            final int durationB = b['duration'] ?? 0;
            return _sortAscending ? durationA.compareTo(durationB) : durationB.compareTo(durationA);
          } else {
            // Default sort by name
            final String nameA = a['name'] ?? '';
            final String nameB = b['name'] ?? '';
            return _sortAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
          }
        });
        
        setState(() {
          _goalDetails = fetched;
          _isLoading = false;
        });
        
        _calculateSummaryStats();
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load goals';
        });
        _showErrorSnackBar('Failed to load goals');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error fetching goals: $e';
      });
      _showErrorSnackBar('Error fetching goals: $e');
    }
  }

  // Fetch expenses linked to a specific goal
  Future<void> _fetchLinkedExpenses(String goalId) async {
    setState(() {
      _isRefreshing = true;
      _linkedExpenses = [];
    });
    
    try {
      // Use ApiServiceWrapper to fetch linked expenses
      final response = await _apiService.getExpensesByGoalId(goalId);
      
      if (response != null) {
        List<Map<String, dynamic>> fetched = List<Map<String, dynamic>>.from(response);
        
        setState(() {
          _linkedExpenses = fetched;
          _isRefreshing = false;
        });
      } else {
        setState(() {
          _isRefreshing = false;
        });
        _showErrorSnackBar('Failed to load linked expenses');
      }
    } catch (e) {
      setState(() {
        _isRefreshing = false;
      });
      _showErrorSnackBar('Error fetching linked expenses: $e');
    }
  }
  
  void _calculateSummaryStats() {
    double totalAmount = 0.0;
    double totalProgress = 0.0;
    double totalRemaining = 0.0;
    
    for (var goal in _goalDetails) {
      final double amount = goal['amount']?.toDouble() ?? 0.0;
      final double progress = goal['progress']?.toDouble() ?? 0.0;
      final double remaining = amount - progress;
      
      totalAmount += amount;
      totalProgress += progress;
      totalRemaining += remaining > 0 ? remaining : 0;
    }
    
    setState(() {
      _totalGoalAmount = totalAmount;
      _totalProgress = totalProgress;
      _totalRemaining = totalRemaining;
      _goalCount = _goalDetails.length;
    });
  }

  Future<void> _saveGoal() async {
    setState(() {
      _isRefreshing = true;
    });

    if (_nameController.text.isEmpty || _amountController.text.isEmpty || _durationController.text.isEmpty) {
      setState(() {
        _isRefreshing = false;
      });
      _showErrorSnackBar('Please fill in all required fields.');
      return;
    }

    final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    final duration = int.tryParse(_durationController.text) ?? 1;
    // Parse progress, defaulting to 0 if empty or invalid
    final progress = double.tryParse(_progressController.text) ?? 0.0;

    final goal = {
      'name': _nameController.text.trim(),
      'amount': totalAmount,
      'duration': duration,
      'progress': progress,
      'type': isSaving ? 'Savings' : 'Debt',
    };

    try {
      bool success;
      
      if (_editingGoalId == null) {
        // Create new goal
        success = await _apiService.createGoal(goal);
      } else {
        // Update existing goal
        success = await _apiService.updateGoal(_editingGoalId!, goal);
      }

      if (success) {
        _showSuccessSnackBar(
          _editingGoalId == null 
            ? '${isSaving ? "Savings" : "Debt"} goal added successfully!' 
            : '${isSaving ? "Savings" : "Debt"} goal updated successfully!'
        );
        await _fetchGoalDetails(); // Refresh the goals data
        _clearFields();
        Navigator.of(context).pop(); // Close the dialog
      } else {
        _showErrorSnackBar('Failed to save goal');
      }
    } catch (e) {
      _showErrorSnackBar('Error saving goal: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _deleteGoal(String id) async {
    // Show confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber,
              size: 28,
            ),
            SizedBox(width: 10),
            Text(
              'Confirm Delete',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this ${isSaving ? "savings" : "debt"} goal? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmDelete) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      // Use ApiServiceWrapper to delete goal
      final success = await _apiService.deleteGoal(id);
      
      if (success) {
        _showSuccessSnackBar('${isSaving ? "Savings" : "Debt"} goal deleted successfully!');
        await _fetchGoalDetails();
      } else {
        _showErrorSnackBar('Failed to delete goal');
      }
    } catch (e) {
      _showErrorSnackBar('Error deleting goal: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  void _clearFields() {
    setState(() {
      _nameController.clear();
      _amountController.clear();
      _durationController.clear();
      _progressController.clear();
      _editingGoalId = null;
    });
  }

  void _showGoalDialog({Map<String, dynamic>? goal}) {
    if (goal != null) {
      // If editing an existing goal
      setState(() {
        _nameController.text = goal['name'] ?? '';
        _amountController.text = goal['amount'].toString();
        _durationController.text = goal['duration'].toString();
        _progressController.text = goal['progress'].toString();
        _editingGoalId = goal['_id'];
      });
    } else {
      // If adding a new goal
      _clearFields();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isSaving ? Colors.green : Colors.red).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    goal == null ? Icons.add_circle : Icons.edit,
                    color: isSaving ? Colors.green.shade700 : Colors.red.shade700,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    goal == null 
                      ? 'Add ${isSaving ? "Savings" : "Debt"} Goal' 
                      : 'Edit ${isSaving ? "Savings" : "Debt"} Goal',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      'Goal Name',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: isSaving ? 'Enter savings goal name' : 'Enter debt name',
                        prefixIcon: Icon(isSaving ? Icons.savings : Icons.account_balance),
                        prefixIconColor: isSaving ? Colors.green.shade700 : Colors.red.shade700,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isSaving ? Colors.green.shade700 : Colors.red.shade700, 
                            width: 2
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    SizedBox(height: 20),
                    
                    // Amount
                    Text(
                      isSaving ? 'Savings Goal Amount' : 'Debt Amount',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      decoration: InputDecoration(
                        hintText: 'Enter amount',
                        prefixIcon: Icon(Icons.attach_money),
                        prefixIconColor: isSaving ? Colors.green.shade700 : Colors.red.shade700,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isSaving ? Colors.green.shade700 : Colors.red.shade700, 
                            width: 2
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    SizedBox(height: 20),
                    
                    // Duration
                    Text(
                      'Duration (months)',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        hintText: 'Enter duration in months',
                        prefixIcon: Icon(Icons.calendar_today),
                        prefixIconColor: isSaving ? Colors.green.shade700 : Colors.red.shade700,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isSaving ? Colors.green.shade700 : Colors.red.shade700, 
                            width: 2
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    SizedBox(height: 20),
                    
                    // Progress
                    Text(
                      isSaving ? 'Amount Saved So Far' : 'Amount Paid So Far',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _progressController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      decoration: InputDecoration(
                        hintText: isSaving ? 'Enter amount saved' : 'Enter amount paid',
                        prefixIcon: Icon(isSaving ? Icons.savings : Icons.payment),
                        prefixIconColor: isSaving ? Colors.green.shade700 : Colors.red.shade700,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isSaving ? Colors.green.shade700 : Colors.red.shade700, 
                            width: 2
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _clearFields();
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _saveGoal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSaving ? Colors.green.shade700 : Colors.red.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  goal == null ? 'Save Goal' : 'Update Goal',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  // Show linked expenses for a specific goal
  void _showLinkedExpenses(String goalId, String goalName) async {
    setState(() {
      _isRefreshing = true;
    });
    
    await _fetchLinkedExpenses(goalId);
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isSaving ? Colors.green : Colors.red).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSaving ? Icons.savings : Icons.account_balance,
                  color: isSaving ? Colors.green.shade700 : Colors.red.shade700,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Linked Expenses',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      goalName,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: _isRefreshing
              ? SizedBox(
                  height: 100,
                  width: double.maxFinite,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isSaving ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ),
                )
              : _linkedExpenses.isEmpty
                  ? Container(
                      padding: EdgeInsets.all(20),
                      width: double.maxFinite,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: (isSaving ? Colors.green : Colors.red).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.receipt_long,
                              size: 40,
                              color: isSaving ? Colors.green.shade300 : Colors.red.shade300,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No Linked Expenses',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'This goal has no linked expenses yet. Add an expense with the category "${isSaving ? "Savings" : "Debt"}" and select this goal.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      width: double.maxFinite,
                      constraints: BoxConstraints(maxHeight: 400),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _linkedExpenses.length,
                        separatorBuilder: (context, index) => Divider(height: 1),
                        itemBuilder: (context, index) {
                          final expense = _linkedExpenses[index];
                          final double amount = expense['amount']?.toDouble() ?? 0.0;
                          final String payee = expense['payee'] ?? 'Unknown';
                          final String dateStr = expense['date'] ?? '';
                          final String formattedDate = dateStr.isNotEmpty
                              ? DateFormat('MMM d, yyyy').format(DateTime.parse(dateStr))
                              : 'Unknown date';
                          
                          return ListTile(
                            leading: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isSaving ? Colors.green : Colors.red).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSaving ? Icons.savings : Icons.payment,
                                color: isSaving ? Colors.green.shade700 : Colors.red.shade700,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              payee,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              formattedDate,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            trailing: Text(
                              '£${amount.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isSaving ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Close',
                style: GoogleFonts.poppins(
                  color: isSaving ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 10),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(10),
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(10),
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(10),
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'GOT IT',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goal) {
    final String name = goal['name'] ?? 'Unnamed Goal';
    final double total = (goal['amount'] as num).toDouble();
    final int duration = (goal['duration'] as num).toInt();
    final double monthlyTarget = total / duration;
    final double progress = (goal['progress'] as num).toDouble();
    final double remaining = total - progress;
    final double percentComplete = total > 0 ? (progress / total) * 100 : 0;
    final String goalId = goal['_id'];
    
    // Determine card color based on type
    Color primaryColor = isSaving ? Colors.green.shade700 : Colors.red.shade700;
    Color secondaryColor = isSaving ? Colors.green.shade100 : Colors.red.shade100;
    
    // Determine icon based on type
    IconData typeIcon = isSaving ? Icons.savings : Icons.account_balance;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: (isSaving ? Colors.green : Colors.red).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: secondaryColor.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(typeIcon, color: primaryColor, size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isSaving 
                          ? 'Saving for $duration months' 
                          : 'Repaying over $duration months',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '£${total.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    Text(
                      isSaving ? 'Goal Amount' : 'Debt Amount',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildGoalStat(
                    label: isSaving ? 'Saved' : 'Paid',
                    amount: progress,
                    color: primaryColor,
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.grey.shade300,
                  ),
                  _buildGoalStat(
                    label: 'Remaining',
                    amount: remaining,
                    color: Colors.blue.shade700,
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.grey.shade300,
                  ),
                  _buildGoalStat(
                    label: 'Monthly Target',
                    amount: monthlyTarget,
                    color: Colors.purple.shade700,
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${percentComplete.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Stack(
                  children: [
                    // Background
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    // Progress
                    Container(
                      height: 10,
                      width: (percentComplete / 100) * (MediaQuery.of(context).size.width - 72),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSaving
                            ? [Colors.green.shade400, Colors.green.shade700]
                            : [Colors.red.shade400, Colors.red.shade700],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            Divider(color: Colors.grey.shade200),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // View linked expenses button
                TextButton.icon(
                  onPressed: () => _showLinkedExpenses(goalId, name),
                  icon: Icon(
                    Icons.receipt_long,
                    size: 18,
                    color: Colors.blue.shade700,
                  ),
                  label: Text(
                    'Expenses',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showGoalDialog(goal: goal),
                  icon: Icon(
                    Icons.edit,
                    size: 18,
                    color: Colors.blue.shade700,
                  ),
                  label: Text(
                    'Edit',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _deleteGoal(goal['_id']),
                  icon: Icon(
                    Icons.delete,
                    size: 18,
                    color: Colors.red.shade600,
                  ),
                  label: Text(
                    'Delete',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.red.shade600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGoalStat({
    required String label,
    required double amount,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '£${amount.toStringAsFixed(2)}',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalList() {
    // Filter _goalDetails by the search query (if provided).
    List<Map<String, dynamic>> displayedList = _goalDetails;
    if (_searchController.text.isNotEmpty) {
      displayedList = _goalDetails.where((goal) {
        String name = goal['name']?.toLowerCase() ?? '';
        return name.contains(_searchController.text.toLowerCase());
      }).toList();
    }

    if (displayedList.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: displayedList.length,
      itemBuilder: (context, index) {
        return _buildGoalCard(displayedList[index]);
      },
    );
  }
  
  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(32),
      margin: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (isSaving ? Colors.green : Colors.red).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSaving ? Icons.savings : Icons.account_balance,
              size: 60,
              color: isSaving ? Colors.green.shade300 : Colors.red.shade300,
            ),
          ),
          SizedBox(height: 24),
          Text(
            isSaving ? 'No Savings Goals Found' : 'No Debt Goals Found',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isSaving ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
          SizedBox(height: 16),
          Text(
            isSaving 
              ? 'Start planning your financial future by creating your first savings goal.' 
              : 'Track your debt repayment by creating your first debt goal.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showGoalDialog(),
            icon: Icon(Icons.add),
            label: Text(
              isSaving ? 'Add Savings Goal' : 'Add Debt Goal',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isSaving ? Colors.green.shade700 : Colors.red.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isSaving 
            ? [Colors.green.shade800, Colors.green.shade600]
            : [Colors.red.shade800, Colors.red.shade600],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isSaving ? Colors.green : Colors.red).withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSaving ? Icons.savings : Icons.account_balance,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      isSaving ? 'Savings Summary' : 'Debt Summary',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_goalCount ${isSaving ? "Goals" : "Debts"}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    title: isSaving ? 'Total Goals' : 'Total Debt',
                    value: '£${_totalGoalAmount.toStringAsFixed(2)}',
                    icon: isSaving ? Icons.savings : Icons.account_balance,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryItem(
                    title: isSaving ? 'Total Saved' : 'Total Paid',
                    value: '£${_totalProgress.toStringAsFixed(2)}',
                    icon: isSaving ? Icons.monetization_on : Icons.payment,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryItem(
                    title: 'Remaining',
                    value: '£${_totalRemaining.toStringAsFixed(2)}',
                    icon: Icons.trending_up,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryItem({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white.withOpacity(0.8)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSortingOptions() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Text(
            'Sort by:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSortButton('Name', 'name'),
                  _buildSortButton('Amount', 'amount'),
                  _buildSortButton('Progress', 'progress'),
                  _buildSortButton('Duration', 'duration'),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () {
                setState(() {
                  _sortAscending = !_sortAscending;
                  _fetchGoalDetails();
                });
              },
              tooltip: _sortAscending ? 'Ascending' : 'Descending',
              padding: EdgeInsets.all(8),
              constraints: BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSortButton(String label, String value) {
    final bool isSelected = _sortBy == value;
    
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _sortBy = value;
            _fetchGoalDetails();
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            border: Border.all(
              color: Colors.white,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected 
                ? (isSaving ? Colors.green.shade700 : Colors.red.shade700) 
                : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// Shows a dialog with information about the Savings & Debt page.
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isSaving ? Colors.green : Colors.red).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline, 
                  color: isSaving ? Colors.green.shade700 : Colors.red.shade700,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'About Savings & Debt',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This page allows you to manage your savings and debt goals:',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 16),
                _buildInfoItem(
                  icon: Icons.savings,
                  color: Colors.green,
                  text: 'Create savings goals with target amounts and timeframes',
                ),
                _buildInfoItem(
                  icon: Icons.account_balance,
                  color: Colors.red,
                  text: 'Track debt repayment with monthly targets',
                ),
                _buildInfoItem(
                  icon: Icons.calendar_today,
                  color: Colors.blue,
                  text: 'Set durations to calculate monthly targets',
                ),
                _buildInfoItem(
                  icon: Icons.trending_up,
                  color: Colors.purple,
                  text: 'Monitor your progress with visual indicators',
                ),
                _buildInfoItem(
                  icon: Icons.swap_horiz,
                  color: Colors.orange,
                  text: 'Switch between Savings and Debt modes using the tabs',
                ),
                _buildInfoItem(
                  icon: Icons.receipt_long,
                  color: Colors.teal,
                  text: 'View expenses linked to each goal',
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.shade100,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'For any further questions, please refer to our documentation or contact support.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Close',
                style: GoogleFonts.poppins(
                  color: isSaving ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildInfoItem({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

// Add a refresh button to the AppBar in the build method
@override
Widget build(BuildContext context) {
  return Scaffold(
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      title: Text(
        'Savings & Debt',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      actions: [
        // Add a refresh button
        IconButton(
          icon: Icon(Icons.refresh, color: Colors.white),
          onPressed: _fetchGoalDetails,
          tooltip: 'Refresh data',
        ),
        IconButton(
          icon: Icon(Icons.info_outline, color: Colors.white),
          onPressed: _showInfoDialog,
          tooltip: 'About this page',
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.normal,
          fontSize: 14,
        ),
        tabs: [
          Tab(
            icon: Icon(Icons.savings),
            text: 'Savings',
          ),
          Tab(
            icon: Icon(Icons.account_balance),
            text: 'Debt',
          ),
        ],
      ),
    ),
    body: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSaving
            ? [
                Color(0xFF1B5E20), // Dark green
                Color(0xFF4CAF50), // Medium green
              ]
            : [
                Color(0xFFB71C1C), // Dark red
                Color(0xFFF44336), // Medium red
              ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          // Main content
          _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Loading your ${isSaving ? "savings" : "debt"} goals...',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Savings Tab
                    RefreshIndicator(
                      color: Colors.white,
                      backgroundColor: Colors.green.shade700,
                      onRefresh: _fetchGoalDetails,
                      child: SingleChildScrollView(
                        physics: AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Padding for AppBar
                            SizedBox(height: 120),
                            
                            // Summary card
                            _buildSummaryCard(),
                            
                            // Sorting options
                            _buildSortingOptions(),
                            
                            // Search field
                            Container(
                              margin: EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search by goal name',
                                  prefixIcon: Icon(Icons.search, color: Colors.white),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                                  hintStyle: GoogleFonts.poppins(color: Colors.white70),
                                ),
                                style: GoogleFonts.poppins(color: Colors.white),
                                onChanged: (value) {
                                  setState(() {
                                    // When the search query changes, update the UI.
                                  });
                                },
                              ),
                            ),
                            
                            // Goal list
                            _buildGoalList(),
                          ],
                        ),
                      ),
                    ),
                    
                    // Debt Tab
                    RefreshIndicator(
                      color: Colors.white,
                      backgroundColor: Colors.red.shade700,
                      onRefresh: _fetchGoalDetails,
                      child: SingleChildScrollView(
                        physics: AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Padding for AppBar
                            SizedBox(height: 120),
                            
                            // Summary card
                            _buildSummaryCard(),
                            
                            // Sorting options
                            _buildSortingOptions(),
                            
                            // Search field
                            Container(
                              margin: EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search by debt name',
                                  prefixIcon: Icon(Icons.search, color: Colors.white),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                                  hintStyle: GoogleFonts.poppins(color: Colors.white70),
                                ),
                                style: GoogleFonts.poppins(color: Colors.white),
                                onChanged: (value) {
                                  setState(() {
                                    // When the search query changes, update the UI.
                                  });
                                },
                              ),
                            ),
                            
                            // Goal list
                            _buildGoalList(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
          
          // Loading overlay
          if (_isRefreshing)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    ),
    floatingActionButton: ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          _showGoalDialog();
        },
        icon: Icon(Icons.add),
        label: Text(
          isSaving ? 'Add Savings Goal' : 'Add Debt Goal',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: isSaving ? Colors.green.shade800 : Colors.red.shade800,
        elevation: 4,
      ),
    ),
  );
}
}
