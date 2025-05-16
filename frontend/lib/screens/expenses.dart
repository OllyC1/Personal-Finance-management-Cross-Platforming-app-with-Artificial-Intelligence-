import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

// Import the ApiServiceWrapper
import 'package:frontend/services/api_service_wrapper.dart';

class ExpensePage extends StatefulWidget {
  const ExpensePage({super.key});

  @override
  _ExpensePageState createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> with SingleTickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _payeeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = '';
  String _selectedFrequency = '';
  String? _editingExpenseId;
  DateTime? _selectedDueDate;
  String? _selectedGoalId; // Added to track the selected goal

  final List<String> _expenseCategories = [
    'Auto & Transport',
    'Bills & Utilities',
    'Business Services',
    'Cash & ATM',
    'Check',
    'Clothing',
    'Credit Card Payment',
    'Eating Out',
    'Education',
    'Electronics & Software',
    'Entertainment',
    'Fees',
    'Gifts and Donation',
    'Groceries',
    'Health & Medical',
    'Home',
    'Savings',
    'Debt',
    'Insurance',
    'Investments',
    'Kids',
    'Mortgage & Rent',
    'Personal Care',
    'Pets',
    'Shopping',
    'Sports & Fitness',
    'Taxes',
    'Transfer',
    'Travel',
    'Other'
  ];

  final List<String> _expenseFrequencies = [
    'Just once',
    'Every day',
    'Every week',
    'Every month',
    'Every year',
    'Every weekday',
    'Weekends',
    'Every other week',
    'Twice a month',
    'Every 3 months',
  ];

  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _goals = []; // Added to store available goals
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _showInactive = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isLoadingGoals = false; // Added to track goal loading state

  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  late TabController _tabController;
  
  // For refresh indicator
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  
  // For summary stats
  double _totalMonthlyExpense = 0.0;
  double _totalYearlyExpense = 0.0;
  int _activeExpenseCount = 0;
  
  // For sorting
  String _sortBy = 'dueDate';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _expenseCategories[0];
    _selectedFrequency = _expenseFrequencies[0];
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      _fetchExpenses();
    });
    _fetchExpenses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _payeeController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Replace the _getAuthToken method with this
  Future<String?> _getAuthToken() async {
    return await _secureStorage.read(key: 'authToken');
  }

  String _formatDate(String? date) {
    if (date == null) return 'No date';
    try {
      final parsed = DateTime.parse(date).toLocal();
      return DateFormat('yyyy-MM-dd').format(parsed);
    } catch (e) {
      return date;
    }
  }

  DateTime addMonths(DateTime date, int months) {
    int newYear = date.year + ((date.month + months - 1) ~/ 12);
    int newMonth = ((date.month + months - 1) % 12) + 1;
    int newDay = date.day;
    int daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
    if (newDay > daysInNewMonth) newDay = daysInNewMonth;
    return DateTime(newYear, newMonth, newDay);
  }

  // Calculate next due date based on the given frequency.
  DateTime? _getNextDueDate(DateTime dueDate, String frequency) {
    final today = DateTime.now();
    DateTime next = dueDate;
    if (frequency == 'Just once') {
      return next.isAfter(today) ? next : null;
    } else if (frequency == 'Every day') {
      while (!next.isAfter(today)) {
        next = next.add(Duration(days: 1));
      }
      return next;
    } else if (frequency == 'Every week') {
      while (!next.isAfter(today)) {
        next = next.add(Duration(days: 7));
      }
      return next;
    } else if (frequency == 'Every month') {
      next = addMonths(next, 1);
      while (!next.isAfter(today)) {
        next = addMonths(next, 1);
      }
      return next;
    } else if (frequency == 'Every year') {
      while (!next.isAfter(today)) {
        next = DateTime(next.year + 1, next.month, next.day);
      }
      return next;
    } else if (frequency == 'Every weekday') {
      while (!next.isAfter(today) || next.weekday > 5) {
        next = next.add(Duration(days: 1));
      }
      return next;
    } else if (frequency == 'Weekends') {
      while (!next.isAfter(today) || (next.weekday != DateTime.saturday && next.weekday != DateTime.sunday)) {
        next = next.add(Duration(days: 1));
      }
      return next;
    } else if (frequency == 'Every other week') {
      while (!next.isAfter(today)) {
        next = next.add(Duration(days: 14));
      }
      return next;
    } else if (frequency == 'Twice a month') {
      while (!next.isAfter(today)) {
        next = next.add(Duration(days: 15));
      }
      return next;
    } else if (frequency == 'Every 3 months') {
      next = addMonths(next, 3);
      while (!next.isAfter(today)) {
        next = addMonths(next, 3);
      }
      return next;
    }
    return null;
  }

  /// Calculate summary statistics from expense data
  void _calculateSummaryStats() {
    final now = DateTime.now();
    final currentMonth = DateFormat('yyyy-MM').format(now);
    final currentYear = DateFormat('yyyy').format(now);
    
    double monthlyTotal = 0.0;
    double yearlyTotal = 0.0;
    int activeCount = 0;
    
    for (var expense in _expenses) {
      if (expense['active'] == true) {
        activeCount++;
        
        final double amount = expense['amount']?.toDouble() ?? 0.0;
        final String dateStr = expense['dueDate'] ?? '';
        final String frequency = expense['frequency'] ?? '';
        
        try {
          final DateTime date = DateTime.parse(dateStr);
          final String expenseMonth = DateFormat('yyyy-MM').format(date);
          final String expenseYear = DateFormat('yyyy').format(date);
          
          // Calculate monthly expense
          if (expenseMonth == currentMonth) {
            monthlyTotal += amount;
          }
          
          // Calculate yearly expense
          if (expenseYear == currentYear) {
            yearlyTotal += amount;
            
            // For recurring expenses, estimate the yearly total
            if (frequency == 'Every month') {
              // If it's a monthly expense, add it for remaining months
              final int currentMonthNum = now.month;
              final int expenseMonthNum = date.month;
              
              if (expenseMonthNum <= currentMonthNum) {
                // Already counted this month, so add for remaining months
                yearlyTotal += amount * (12 - currentMonthNum);
              }
            } else if (frequency == 'Every week') {
              // Estimate weekly expense for the year
              final int weeksInYear = 52;
              final int currentWeek = (now.difference(DateTime(now.year, 1, 1)).inDays / 7).floor();
              yearlyTotal += amount * (weeksInYear - currentWeek);
            }
          }
        } catch (e) {
          // Skip this expense if date parsing fails
        }
      }
    }
    
    setState(() {
      _totalMonthlyExpense = monthlyTotal;
      _totalYearlyExpense = yearlyTotal;
      _activeExpenseCount = activeCount;
    });
  }

  // Fetch goals for the selected category (Savings or Debt)
   Future<List<Map<String, dynamic>>> _fetchGoals(String category) async {
    if (_isLoadingGoals) return _goals; // Prevent multiple simultaneous requests
    
    setState(() {
      _isLoadingGoals = true;
      _goals = []; // Clear goals first to avoid stale data
    });
    
    try {
      final apiService = ApiServiceWrapper();
      List<dynamic> response = await apiService.getGoals();
      
      List<Map<String, dynamic>> allGoals = List<Map<String, dynamic>>.from(response);
      
      // Debug: Print all goals to see what's coming from the server
      print('All goals from server: ${allGoals.length}');
      for (var goal in allGoals) {
        print('Goal: ${goal['name']}, Type: ${goal['type']}');
      }
      
      // Filter goals by type (Savings or Debt)
      List<Map<String, dynamic>> filteredGoals = allGoals
          .where((goal) => goal['type'] == category)
          .toList();
      
      print('Filtered goals for $category: ${filteredGoals.length}');
      
      setState(() {
        _goals = filteredGoals;
        _isLoadingGoals = false;
      });
      
      return filteredGoals;
    } catch (e) {
      print('Error fetching goals: $e');
      _showErrorSnackBar('Error fetching goals: $e');
      setState(() {
        _isLoadingGoals = false;
      });
      return [];
    }
  }

  // Replace the _fetchExpenses method with this
  Future<void> _fetchExpenses() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    
    try {
      final apiService = ApiServiceWrapper();
      List<dynamic> response = await apiService.getExpenses();
      
      List<Map<String, dynamic>> fetched = List<Map<String, dynamic>>.from(response);
      
      // Sort the expenses list
      fetched.sort((a, b) {
        if (_sortBy == 'amount') {
          final double amountA = a['amount']?.toDouble() ?? 0.0;
          final double amountB = b['amount']?.toDouble() ?? 0.0;
          return _sortAscending ? amountA.compareTo(amountB) : amountB.compareTo(amountA);
        } else if (_sortBy == 'payee') {
          final String payeeA = a['payee'] ?? '';
          final String payeeB = b['payee'] ?? '';
          return _sortAscending ? payeeA.compareTo(payeeB) : payeeB.compareTo(payeeA);
        } else if (_sortBy == 'category') {
          final String categoryA = a['category'] ?? '';
          final String categoryB = b['category'] ?? '';
          return _sortAscending ? categoryA.compareTo(categoryB) : categoryB.compareTo(categoryA);
        } else {
          // Default sort by dueDate
          final String dateA = a['dueDate'] ?? '';
          final String dateB = b['dueDate'] ?? '';
          return _sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
        }
      });
      
      if (_tabController.index == 0) {
        // Upcoming Bills: filter expenses whose due date is in the future.
        fetched = fetched.where((expense) {
          DateTime due = DateTime.tryParse(expense['dueDate'] ?? '') ?? DateTime.now();
          return due.isAfter(DateTime.now());
        }).toList();
      } else if (_tabController.index == 1 && !_showInactive) {
        fetched = fetched.where((expense) => expense['active'] == true).toList();
      }
      
      setState(() {
        _expenses = fetched;
        _isLoading = false;
      });
      
      // Calculate summary statistics
      _calculateSummaryStats();
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error fetching expenses: $e';
      });
      _showErrorSnackBar('Error fetching expenses: $e');
    }
  }

  // Replace the _saveExpense method with this
  Future<void> _saveExpense() async {
    setState(() {
      _isRefreshing = true;
    });
    
    if (_amountController.text.isEmpty ||
        _payeeController.text.isEmpty ||
        _selectedCategory.isEmpty ||
        _selectedDueDate == null ||
        _selectedFrequency.isEmpty) {
      setState(() {
        _isRefreshing = false;
      });
      _showErrorSnackBar('Please fill in all required fields.');
      return;
    }

    // Extract the expense amount before creating the expense data
    final double expenseAmount = double.tryParse(_amountController.text) ?? 0.0;
    
    final expenseData = {
      'amount': expenseAmount,
      'payee': _payeeController.text.trim(),
      'category': _selectedCategory,
      'frequency': _selectedFrequency,
      'description': _descriptionController.text.trim(),
      'dueDate': _selectedDueDate?.toIso8601String(),
      'date': DateTime.now().toIso8601String(),
      'active': true,
      'goalId': _selectedGoalId, // Add the goalId to the expense data
    };
    
    try {
      final apiService = ApiServiceWrapper();
      
      if (_editingExpenseId == null) {
        await apiService.addExpense(expenseData);
        _showSuccessSnackBar('Expense added successfully!');
      } else {
        await apiService.updateExpense(_editingExpenseId!, expenseData);
        _showSuccessSnackBar('Expense updated successfully!');
      }
      
      await _fetchExpenses();
      
      // If this expense is linked to a goal, refresh the goals data
      if (_selectedCategory == 'Savings' || _selectedCategory == 'Debt') {
        await _fetchGoals(_selectedCategory);
      }
      
      _clearFields();
      Navigator.of(context).pop();
      
      // If this was a savings or debt expense, notify the user they can view updated progress
      if (_selectedGoalId != null && (_selectedCategory == 'Savings' || _selectedCategory == 'Debt')) {
        _showInfoSnackBar('Goal progress has been updated. Go to the $_selectedCategory page to see your progress.');
      }
    } catch (e) {
      _showErrorSnackBar('Error saving expense: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // Replace the _deleteExpense method with this
  Future<void> _deleteExpense(String id) async {
    // Show confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Delete',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete this expense? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.white),
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
      final apiService = ApiServiceWrapper();
      await apiService.deleteExpense(id);
      _showSuccessSnackBar('Expense deleted successfully!');
      await _fetchExpenses();
    } catch (e) {
      _showErrorSnackBar('Error deleting expense: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // Replace the _toggleActiveExpense method with this
  Future<void> _toggleActiveExpense(String id, bool newStatus) async {
    setState(() {
      _isRefreshing = true;
    });
    
    final updateData = {'active': newStatus};
    try {
      final apiService = ApiServiceWrapper();
      await apiService.updateExpense(id, updateData);
      await _fetchExpenses();
      _showSuccessSnackBar(
        newStatus 
          ? 'Expense activated successfully.' 
          : 'Expense deactivated successfully.'
      );
    } catch (e) {
      _showErrorSnackBar('Error updating status: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // Replace the _skipNextPayment method with this
  Future<void> _skipNextPayment(String id, Map<String, dynamic> expense) async {
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      DateTime currentDueDate = DateTime.parse(expense['dueDate']);
      String? frequency = expense['frequency'];
      if (frequency == null || frequency.isEmpty) {
        setState(() {
          _isRefreshing = false;
        });
        _showErrorSnackBar('Frequency not set.');
        return;
      }
      
      DateTime? nextDueDate = _getNextDueDate(currentDueDate, frequency);
      if (nextDueDate == null) {
        setState(() {
          _isRefreshing = false;
        });
        _showErrorSnackBar('No upcoming due date found.');
        return;
      }
      
      final updateData = {'dueDate': DateFormat('yyyy-MM-dd').format(nextDueDate)};
      final apiService = ApiServiceWrapper();
      await apiService.updateExpense(id, updateData);
      
      await _fetchExpenses();
      _showSuccessSnackBar('Next payment skipped successfully.');
    } catch (e) {
      _showErrorSnackBar('Error skipping payment: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  void _clearFields() {
    setState(() {
      _amountController.clear();
      _payeeController.clear();
      _descriptionController.clear();
      _dateController.clear();
      _selectedDueDate = null;
      _selectedCategory = _expenseCategories[0];
      _selectedFrequency = _expenseFrequencies[0];
      _editingExpenseId = null;
      _selectedGoalId = null; // Reset the selected goal ID
    });
  }

  /// Shows the Expense History dialog.
  void _showHistory(Map<String, dynamic> expense) {
    List<dynamic> history = expense['history'] ?? [];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.history, color: Colors.blue.shade700),
              SizedBox(width: 10),
              Text(
                'Expense History',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: history.isEmpty
              ? Container(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 48,
                        color: Colors.blue.shade200,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No history available',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'This expense entry has no recorded history yet.',
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
                  constraints: BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: history.length,
                    separatorBuilder: (context, index) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      var entry = history[index];
                      String entryText = '';
                      IconData iconData = Icons.info_outline;
                      Color iconColor = Colors.grey;
                      
                      if (entry.containsKey('skippedDate')) {
                        DateTime date = DateTime.tryParse(entry['skippedDate'].toString()) ?? DateTime.now();
                        entryText = 'Skipped payment on ${DateFormat('yyyy-MM-dd').format(date)}';
                        iconData = Icons.skip_next;
                        iconColor = Colors.orange;
                      } else if (entry.containsKey('updatedAmount')) {
                        entryText = 'Amount updated to £${entry['updatedAmount']}';
                        iconData = Icons.edit;
                        iconColor = Colors.blue;
                      } else if (entry.containsKey('statusChange')) {
                        entryText = 'Status changed to ${entry['statusChange'] ? 'Active' : 'Inactive'}';
                        iconData = entry['statusChange'] ? Icons.check_circle : Icons.cancel;
                        iconColor = entry['statusChange'] ? Colors.green : Colors.red;
                      } else {
                        entryText = entry.toString();
                      }
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: iconColor.withOpacity(0.1),
                          child: Icon(iconData, color: iconColor, size: 20),
                        ),
                        title: Text(
                          entryText,
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        subtitle: entry.containsKey('timestamp')
                            ? Text(
                                DateFormat('yyyy-MM-dd HH:mm').format(
                                  DateTime.parse(entry['timestamp']),
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.poppins(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
// Replace the _showExpenseDialog method with this improved version
void _showExpenseDialog() {
  // Initialize local variables from parent's state.
  String localCategory = _selectedCategory;
  String localFrequency = _selectedFrequency;
  String? localGoalId = _selectedGoalId;
  TextEditingController localPayeeController = TextEditingController(text: _payeeController.text);
  List<Map<String, dynamic>> dialogGoals = [];
  bool isLoadingDialogGoals = false;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(builder: (context, setStateDialog) {
        // Function to fetch goals within the dialog
        Future<void> fetchGoalsForDialog(String category) async {
          if (isLoadingDialogGoals) return;
          
          setStateDialog(() {
            isLoadingDialogGoals = true;
          });
          
          try {
            final apiService = ApiServiceWrapper();
            List<dynamic> response = await apiService.getGoals();
            
            List<Map<String, dynamic>> allGoals = List<Map<String, dynamic>>.from(response);
            
            // Debug: Print all goals from server
            print('All goals from server: ${allGoals.length}');
            for (var goal in allGoals) {
              print('Goal: ${goal['name']}, Type: ${goal['type']}');
            }
            
            // Filter goals by type (Savings or Debt)
            List<Map<String, dynamic>> filteredGoals = allGoals
                .where((goal) => goal['type'] == category)
                .toList();
            
            print('Filtered goals for $category: ${filteredGoals.length}');
            
            setStateDialog(() {
              dialogGoals = filteredGoals;
              isLoadingDialogGoals = false;
            });
          } catch (e) {
            print('Error fetching goals for dialog: $e');
            setStateDialog(() {
              isLoadingDialogGoals = false;
            });
          }
        }

        // Determine if we need to show the goal selector
        bool showGoalSelector = localCategory == 'Savings' || localCategory == 'Debt';

        // Fetch goals when dialog opens or category changes to Savings or Debt
        if (showGoalSelector && dialogGoals.isEmpty && !isLoadingDialogGoals) {
          print('Fetching goals for $localCategory');
          // Use Future.microtask to avoid calling setState during build
          Future.microtask(() => fetchGoalsForDialog(localCategory));
        }

        // Check if running on Android
        final bool isAndroid = Theme.of(context).platform == TargetPlatform.android;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                _editingExpenseId == null ? Icons.add_circle : Icons.edit,
                color: Colors.blue.shade700,
              ),
              SizedBox(width: 10),
              Text(
                _editingExpenseId == null ? 'Add Expense' : 'Edit Expense',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount
                  Text(
                    'Amount',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Enter amount',
                      prefixIcon: Icon(Icons.attach_money),
                      prefixIconColor: Colors.green,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                      ),
                    ),
                    style: GoogleFonts.poppins(),
                  ),
                  SizedBox(height: 16),
                  
                  // Payee
                  Text(
                    'Payee',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: localPayeeController,
                    decoration: InputDecoration(
                      hintText: 'Enter payee name',
                      prefixIcon: Icon(Icons.business),
                      prefixIconColor: Colors.blue.shade700,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                      ),
                    ),
                    style: GoogleFonts.poppins(),
                  ),
                  SizedBox(height: 16),
                  
                  // Category
                  Text(
                    'Category',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isAndroid 
                      ? DropdownButtonHideUnderline(
                          child: ButtonTheme(
                            alignedDropdown: true,
                            child: DropdownButton<String>(
                              value: localCategory,
                              isExpanded: true,
                              icon: Icon(Icons.arrow_drop_down, color: Colors.orange),
                              items: _expenseCategories.map((cat) {
                                return DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat, style: GoogleFonts.poppins(color: Colors.black)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setStateDialog(() {
                                    localCategory = value;
                                    // Reset goal selection when category changes
                                    localGoalId = null;
                                    
                                    // Fetch goals if category is Savings or Debt
                                    if (value == 'Savings' || value == 'Debt') {
                                      fetchGoalsForDialog(value);
                                    }
                                  });
                                }
                              },
                              hint: Text('Select category', style: GoogleFonts.poppins(color: Colors.black54)),
                              style: GoogleFonts.poppins(color: Colors.black),
                              dropdownColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        )
                      : DropdownButtonFormField<String>(
                          value: localCategory,
                          items: _expenseCategories.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(cat, style: GoogleFonts.poppins()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setStateDialog(() {
                              localCategory = value!;
                              // Reset goal selection when category changes
                              localGoalId = null;
                              
                              // Fetch goals if category is Savings or Debt
                              if (value == 'Savings' || value == 'Debt') {
                                fetchGoalsForDialog(value);
                              }
                            });
                          },
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.category),
                            prefixIconColor: Colors.orange,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                            ),
                          ),
                          dropdownColor: Colors.white,
                          icon: Icon(Icons.arrow_drop_down, color: Colors.orange),
                          style: GoogleFonts.poppins(),
                        ),
                  ),
                  SizedBox(height: 16),

                  // Goal Selector (only shown for Savings or Debt categories)
                  if (showGoalSelector) ...[
                    Text(
                      localCategory == 'Savings' ? 'Select Savings Goal' : 'Select Debt',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 8),
                    GoalSelectorWidget(
                      goals: dialogGoals.isEmpty ? _goals : dialogGoals,
                      selectedGoalId: localGoalId,
                      onGoalSelected: (goalId) {
                        setStateDialog(() {
                          localGoalId = goalId;
                        });
                      },
                      goalType: localCategory,
                      onAddGoal: () {
                        Navigator.of(context).pop();
                        // Navigate to the Savings/Debt page
                        _navigateToSavingsPage();
                      },
                    ),
                    SizedBox(height: 16),
                  ],
                  
                  // Frequency
                  Text(
                    'Frequency',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isAndroid
                      ? DropdownButtonHideUnderline(
                          child: ButtonTheme(
                            alignedDropdown: true,
                            child: DropdownButton<String>(
                              value: localFrequency,
                              isExpanded: true,
                              icon: Icon(Icons.arrow_drop_down, color: Colors.purple),
                              items: _expenseFrequencies.map((freq) {
                                return DropdownMenuItem(
                                  value: freq,
                                  child: Text(freq, style: GoogleFonts.poppins(color: Colors.black)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setStateDialog(() {
                                    localFrequency = value;
                                  });
                                }
                              },
                              hint: Text('Select frequency', style: GoogleFonts.poppins(color: Colors.black54)),
                              style: GoogleFonts.poppins(color: Colors.black),
                              dropdownColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        )
                      : DropdownButtonFormField<String>(
                          value: localFrequency,
                          items: _expenseFrequencies.map((freq) {
                            return DropdownMenuItem(
                              value: freq,
                              child: Text(freq, style: GoogleFonts.poppins()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setStateDialog(() {
                              localFrequency = value!;
                            });
                          },
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.repeat),
                            prefixIconColor: Colors.purple,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                            ),
                          ),
                          dropdownColor: Colors.white,
                          icon: Icon(Icons.arrow_drop_down, color: Colors.purple),
                          style: GoogleFonts.poppins(),
                        ),
                  ),
                  SizedBox(height: 16),
                  
                  // Due Date
                  Text(
                    'Due Date',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'Select date',
                      prefixIcon: Icon(Icons.calendar_today),
                      prefixIconColor: Colors.red,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                      ),
                    ),
                    style: GoogleFonts.poppins(),
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDueDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Colors.blue.shade700,
                                onPrimary: Colors.white,
                                onSurface: Colors.black,
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blue.shade700,
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (pickedDate != null) {
                        setStateDialog(() {
                          _selectedDueDate = pickedDate;
                          _dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                        });
                      }
                    },
                  ),
                  SizedBox(height: 16),
                  
                  // Description
                  Text(
                    'Description (Optional)',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter description',
                      prefixIcon: Icon(Icons.description),
                      prefixIconColor: Colors.teal,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                      ),
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
              onPressed: () {
                setState(() {
                  _selectedCategory = localCategory;
                  _selectedFrequency = localFrequency;
                  _selectedGoalId = localGoalId;
                  _payeeController.text = localPayeeController.text;
                });
                _saveExpense();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                _editingExpenseId == null ? 'Save Expense' : 'Update Expense',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        );
      });
    },
  );
}

  // Navigate to the Savings/Debt page with automatic refresh
  void _navigateToSavingsPage() async {
    // This is a placeholder implementation since we don't have the full SavingsDebtPage implementation
    // You'll need to adjust this based on your actual SavingsDebtPage implementation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation to Savings/Debt page is not implemented yet'),
        backgroundColor: Colors.orange,
      ),
    );
    
    // Uncomment this when you have the SavingsDebtPage implemented
    /*
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SavingsDebtPage(
          initialTabIndex: _selectedCategory == 'Debt' ? 1 : 0, // Set initial tab based on category
        ),
      ),
    );
    
    // Refresh expenses when returning from the Savings page
    if (result == true) {
      _fetchExpenses();
    }
    */
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(10),
        duration: Duration(seconds: 4),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(10),
        duration: Duration(seconds: 3),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(10),
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            _navigateToSavingsPage();
          },
        ),
      ),
    );
  }

  /// Builds an ExpansionTile for a single expense entry.
  Widget _buildExpenseTile(Map<String, dynamic> expense) {
    final String payee = expense['payee'] ?? 'Unknown';
    final double amount = expense['amount']?.toDouble() ?? 0.0;
    final String category = expense['category'] ?? 'Unknown';
    final String frequency = expense['frequency'] ?? 'Just once';
    final String description = expense['description'] ?? 'No description';
    final String dueDateStr = expense['dueDate'] ?? '';
    final DateTime dueDate = DateTime.tryParse(dueDateStr) ?? DateTime.now();
    final bool isActive = expense['active'] ?? true;
    final String formattedDueDate = DateFormat('EEEE, MMM d, yyyy').format(dueDate);
    final DateTime? nextDue = _getNextDueDate(dueDate, frequency);
    final String nextDueText = nextDue != null ? DateFormat('yyyy-MM-dd').format(nextDue) : 'N/A';
    final String? goalId = expense['goalId'];

    // Determine card color based on category
    Color categoryColor;
    IconData categoryIcon;
    
    switch (category.toLowerCase()) {
      case 'auto & transport':
        categoryColor = Colors.blue;
        categoryIcon = Icons.directions_car;
        break;
      case 'bills & utilities':
        categoryColor = Colors.red;
        categoryIcon = Icons.receipt_long;
        break;
      case 'eating out':
        categoryColor = Colors.orange;
        categoryIcon = Icons.restaurant;
        break;
      case 'groceries':
        categoryColor = Colors.green;
        categoryIcon = Icons.shopping_cart;
        break;
      case 'health & medical':
        categoryColor = Colors.purple;
        categoryIcon = Icons.medical_services;
        break;
      case 'mortgage & rent':
        categoryColor = Colors.indigo;
        categoryIcon = Icons.home;
        break;
      case 'savings':
        categoryColor = Colors.green.shade700;
        categoryIcon = Icons.savings;
        break;
      case 'debt':
        categoryColor = Colors.red.shade700;
        categoryIcon = Icons.account_balance;
        break;  
      default:
        categoryColor = Colors.teal;
        categoryIcon = Icons.category;
    }

    // Find goal name if this expense is linked to a goal
    String? goalName;
    if (goalId != null && (category == 'Savings' || category == 'Debt')) {
      final goal = _goals.firstWhere(
        (g) => g['_id'] == goalId, 
        orElse: () => {'name': 'Unknown Goal'}
      );
      goalName = goal['name'];
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                isActive ? Colors.white : Colors.grey.shade200,
              ],
            ),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: categoryColor.withOpacity(0.1),
              child: Icon(categoryIcon, color: categoryColor),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payee,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      Text(
                        category,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isActive ? Colors.black54 : Colors.grey,
                        ),
                      ),
                      // Show goal name if linked to a goal
                      if (goalName != null)
                        Text(
                          'Goal: $goalName',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: categoryColor,
                          ),
                        ),

                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '£${amount.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.red.shade700 : Colors.grey,
                      ),
                    ),
                    Text(
                      'Due: ${_formatDate(dueDateStr)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isActive ? Colors.black54 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            subtitle: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  frequency,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isActive ? Colors.black54 : Colors.grey,
                  ),
                ),
                if (!isActive)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Inactive',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.trim().isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.description, size: 16, color: Colors.grey),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              description,
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                    ],
                    
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Next Payment: ',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          nextDueText,
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Action buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionButton(
                          label: 'Edit',
                          icon: Icons.edit,
                          color: Colors.blue,
                          onPressed: () {
                            setState(() {
                              _editingExpenseId = expense['_id'];
                              _amountController.text = amount.toString();
                              _payeeController.text = payee;
                              _selectedFrequency = (expense['frequency'] != null &&
                                      _expenseFrequencies.contains(expense['frequency']))
                                  ? expense['frequency']
                                  : _expenseFrequencies[0];
                              _selectedCategory = (expense['category'] != null &&
                                      _expenseCategories.contains(expense['category']))
                                  ? expense['category']
                                  : _expenseCategories[0];
                              _descriptionController.text = description;
                              _selectedDueDate = dueDate;
                              _dateController.text = _formatDate(dueDateStr);
                              _selectedGoalId = expense['goalId'];
                              // Fetch goals if category is Savings or Debt
                              if (_selectedCategory == 'Savings' || _selectedCategory == 'Debt') {
                                _fetchGoals(_selectedCategory);
                              }
                            });
                            _showExpenseDialog();
                          },
                        ),
                        
                        ActionButton(
                          label: isActive ? 'Deactivate' : 'Activate',
                          icon: isActive ? Icons.visibility_off : Icons.visibility,
                          color: Colors.orange,
                          onPressed: () {
                            _toggleActiveExpense(expense['_id'], !isActive);
                          },
                        ),
                        
                        ActionButton(
                          label: 'Skip Next',
                          icon: Icons.skip_next,
                          color: Colors.purple,
                          onPressed: () {
                            _skipNextPayment(expense['_id'], expense);
                          },
                        ),
                        
                        ActionButton(
                          label: 'Delete',
                          icon: Icons.delete,
                          color: Colors.red,
                          onPressed: () {
                            _deleteExpense(expense['_id']);
                          },
                        ),
                        
                        ActionButton(
                          label: 'History',
                          icon: Icons.history,
                          color: Colors.teal,
                          onPressed: () {
                            _showHistory(expense);
                          },
                        ),
                        
                        // View Goal button for Savings/Debt expenses
                        if (goalId != null && (category == 'Savings' || category == 'Debt'))
                          ActionButton(
                            label: 'View Goal',
                            icon: category == 'Savings' ? Icons.savings : Icons.account_balance,
                            color: category == 'Savings' ? Colors.green.shade700 : Colors.red.shade700,
                            onPressed: () {
                              _navigateToSavingsPage();
                            },
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
  }

  /// Builds the list of expense entries (with search filtering by payee).
  Widget _buildExpenseList() {
    // Filter _expenses by the search query (if provided).
    List<Map<String, dynamic>> displayedList = _expenses;
    if (_searchController.text.isNotEmpty) {
      displayedList = _expenses.where((expense) {
        String payee = expense['payee']?.toLowerCase() ?? '';
        return payee.contains(_searchController.text.toLowerCase());
      }).toList();
    }

    if (displayedList.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: displayedList.length,
      itemBuilder: (context, index) {
        return _buildExpenseTile(displayedList[index]);
      },
    );
  }
  
  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(32),
      margin: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _tabController.index == 0 ? Icons.calendar_today : Icons.money_off,
            size: 64,
            color: Colors.blue.shade200,
          ),
          SizedBox(height: 24),
          Text(
            _tabController.index == 0 
              ? 'No Upcoming Bills' 
              : 'No Expense Records Found',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          SizedBox(height: 16),
          Text(
            _tabController.index == 0
              ? 'You don\'t have any upcoming bills scheduled.'
              : 'Start tracking your expenses by adding your first entry.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showExpenseDialog,
            icon: Icon(Icons.add),
            label: Text(
              'Add Expense',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
          colors: [
            Colors.blue.shade800,
            Colors.blue.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Expense Summary',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_activeExpenseCount Active Bills',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    title: 'This Month',
                    value: '£${_totalMonthlyExpense.toStringAsFixed(2)}',
                    icon: Icons.calendar_month,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryItem(
                    title: 'Projected Yearly',
                    value: '£${_totalYearlyExpense.toStringAsFixed(2)}',
                    icon: Icons.auto_graph,
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white.withOpacity(0.7)),
              SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            'Sort by:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSortButton('Due Date', 'dueDate'),
                  _buildSortButton('Amount', 'amount'),
                  _buildSortButton('Payee', 'payee'),
                  _buildSortButton('Category', 'category'),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _sortAscending = !_sortAscending;
                _fetchExpenses();
              });
            },
            tooltip: _sortAscending ? 'Ascending' : 'Descending',
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
            _fetchExpenses();
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blue.shade700 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// Shows a dialog with information about the Expenses page.
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              SizedBox(width: 10),
              Text(
                'About Expenses Page',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This page allows you to manage your expense entries:',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 16),
                _buildInfoItem(
                  icon: Icons.add_circle,
                  color: Colors.green,
                  text: 'Add new expenses by tapping the + button',
                ),
                _buildInfoItem(
                  icon: Icons.search,
                  color: Colors.blue,
                  text: 'Use the search bar to filter entries by payee',
                ),
                _buildInfoItem(
                  icon: Icons.edit,
                  color: Colors.orange,
                  text: 'Edit, delete, or change status of any entry',
                ),
                _buildInfoItem(
                  icon: Icons.skip_next,
                  color: Colors.purple,
                  text: 'Skip the next payment for recurring expenses',
                ),
                _buildInfoItem(
                  icon: Icons.visibility_off,
                  color: Colors.grey,
                  text: 'Inactive entries are shown in the All Expenses tab',
                ),
                _buildInfoItem(
                  icon: Icons.history,
                  color: Colors.teal,
                  text: 'View history of changes for each expense entry',
                ),
                _buildInfoItem(
                  icon: Icons.savings,
                  color: Colors.green.shade700,
                  text: 'Link Savings expenses to your savings goals',
                ),
                _buildInfoItem(
                  icon: Icons.account_balance,
                  color: Colors.red.shade700,
                  text: 'Link Debt expenses to your debt repayment goals',
                ),
                SizedBox(height: 16),
                Text(
                  'For any further questions, please refer to our documentation or contact support.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.poppins(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
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
      padding: const EdgeInsets.only(bottom: 12),
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
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1E3A8A), // Dark blue
              Color(0xFF3B82F6), // Medium blue
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(
                      'Manage Expenses',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Spacer(),
                    // Add a refresh button
                    IconButton(
                      icon: Icon(Icons.refresh, color: Colors.white),
                      onPressed: _fetchExpenses,
                      tooltip: 'Refresh data',
                    ),
                    IconButton(
                      icon: Icon(Icons.info_outline, color: Colors.white),
                      onPressed: _showInfoDialog,
                    ),
                  ],
                ),
              ),
              
              // Expense Summary Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Expense Summary',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_activeExpenseCount Active Bills',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Tab Bar
              Container(
                margin: EdgeInsets.only(top: 8),
                child: TabBar(
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
                    Tab(text: 'Upcoming Bills'),
                    Tab(text: 'All Expenses'),
                  ],
                ),
              ),
              
              // Summary Card (below tabs)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem(
                        title: 'This Month',
                        value: '£${_totalMonthlyExpense.toStringAsFixed(2)}',
                        icon: Icons.calendar_month,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildSummaryItem(
                        title: 'Projected Yearly',
                        value: '£${_totalYearlyExpense.toStringAsFixed(2)}',
                        icon: Icons.auto_graph,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Main content (scrollable)
              Expanded(
                child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : RefreshIndicator(
                      key: _refreshIndicatorKey,
                      color: Colors.white,
                      backgroundColor: Colors.blue.shade700,
                      onRefresh: _fetchExpenses,
                      child: SingleChildScrollView(
                        physics: AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Show inactive switch for All Expenses tab
                            if (_tabController.index == 1)
                              Container(
                                margin: EdgeInsets.only(bottom: 16),
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Show Inactive Expenses",
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Switch(
                                      value: _showInactive,
                                      onChanged: (val) {
                                        setState(() {
                                          _showInactive = val;
                                          _fetchExpenses();
                                        });
                                      },
                                      activeColor: Colors.white,
                                      activeTrackColor: Colors.green.withOpacity(0.5),
                                    ),
                                  ],
                                ),
                              ),
                            
                            // Sorting options
                            _buildSortingOptions(),
                            
                            // Search field with reduced bottom margin
                            Container(
                              margin: EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search by payee',
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
                            
                            // Expense list
                            _buildExpenseList(),
                          ],
                        ),
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showExpenseDialog,
        icon: Icon(Icons.add),
        label: Text(
          'Add Expense',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade800,
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
    );
  }
}

class GoalSelectorWidget extends StatelessWidget {
  final List<Map<String, dynamic>> goals;
  final String? selectedGoalId;
  final Function(String?) onGoalSelected;
  final String goalType;
  final VoidCallback onAddGoal;

  const GoalSelectorWidget({
    super.key,
    required this.goals,
    required this.selectedGoalId,
    required this.onGoalSelected,
    required this.goalType,
    required this.onAddGoal,
  });

  @override
  Widget build(BuildContext context) {
    // Determine colors based on goal type
    final Color primaryColor = goalType == 'Savings' ? Colors.green.shade700 : Colors.red.shade700;
    final Color secondaryColor = goalType == 'Savings' ? Colors.green.shade100 : Colors.red.shade100;
    final IconData typeIcon = goalType == 'Savings' ? Icons.savings : Icons.account_balance;

    if (goals.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: secondaryColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryColor.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: primaryColor),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No $goalType goals found',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'You need to create a $goalType goal first to link this expense to it.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: onAddGoal,
                icon: Icon(Icons.add),
                label: Text(
                  'Add $goalType Goal',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Option to not link to any goal
        RadioListTile<String?>(
          title: Text(
            'General $goalType (Not linked to a specific goal)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          value: null,
          groupValue: selectedGoalId,
          onChanged: (value) => onGoalSelected(value),
          activeColor: primaryColor,
          contentPadding: EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selectedGoalId == null 
                ? primaryColor 
                : Colors.grey.shade300,
              width: 1,
            ),
          ),
          tileColor: selectedGoalId == null 
            ? secondaryColor.withOpacity(0.2) 
            : Colors.grey.shade100,
        ),
        SizedBox(height: 8),
        
        // List of available goals
        ...goals.map((goal) {
          final String id = goal['_id'];
          final String name = goal['name'] ?? 'Unnamed Goal';
          final double amount = goal['amount']?.toDouble() ?? 0.0;
          final double progress = goal['progress']?.toDouble() ?? 0.0;
          final double remaining = amount - progress;
          final double percentComplete = amount > 0 ? (progress / amount) * 100 : 0;
          
          return Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: RadioListTile<String?>(
              title: Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '£${amount.toStringAsFixed(2)} total, £${remaining.toStringAsFixed(2)} remaining',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress / amount,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
              value: id,
              groupValue: selectedGoalId,
              onChanged: (value) => onGoalSelected(value),
              activeColor: primaryColor,
              secondary: CircleAvatar(
                backgroundColor: secondaryColor,
                child: Icon(typeIcon, color: primaryColor, size: 20),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: selectedGoalId == id 
                    ? primaryColor 
                    : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              tileColor: selectedGoalId == id 
                ? secondaryColor.withOpacity(0.2) 
                : Colors.grey.shade100,
            ),
          );
        }),
      ],
    );
  }
}