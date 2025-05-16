import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service_wrapper.dart'; // Import the wrapper

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  _BudgetPageState createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedCategory = '';
  bool _rollover = false; // Monthly rollover option
  String? _editingBudgetId;

  // Use ApiServiceWrapper instead of direct HTTP calls
  final ApiServiceWrapper _apiService = ApiServiceWrapper();

  List<Map<String, dynamic>> _budgets = [];
  Map<String, double> _expensesByCategory = {};
  
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasError = false;
  String _errorMessage = '';
  
  // For summary stats
  double _totalBudget = 0.0;
  double _totalSpent = 0.0;
  double _totalRemaining = 0.0;
  
  // For sorting
  String _sortBy = 'category';
  bool _sortAscending = true;

  // Use the same category list as in the expenses page.
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

  @override
  void initState() {
    super.initState();
    _selectedCategory = _expenseCategories[0];
    _fetchBudgets();
    _fetchExpenses();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Helper method to safely convert values to double
  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  // Update the _fetchBudgets method to use ApiServiceWrapper
  Future<void> _fetchBudgets() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    
    try {
      final budgetsData = await _apiService.getBudgets();
      List<Map<String, dynamic>> fetched = [];
      
      // Process each budget item to ensure proper type conversion
      for (var item in budgetsData) {
        Map<String, dynamic> budget = Map<String, dynamic>.from(item);
        // Convert numeric values to double
        budget['budget'] = _safeToDouble(budget['budget']);
        budget['rolloverAmount'] = _safeToDouble(budget['rolloverAmount']);
        budget['spent'] = _safeToDouble(budget['spent']);
        fetched.add(budget);
      }
      
      // Sort the budgets list
      fetched.sort((a, b) {
        if (_sortBy == 'budget') {
          final double budgetA = _safeToDouble(a['budget']);
          final double budgetB = _safeToDouble(b['budget']);
          return _sortAscending ? budgetA.compareTo(budgetB) : budgetB.compareTo(budgetA);
        } else if (_sortBy == 'remaining') {
          final double spentA = _safeToDouble(_expensesByCategory[a['category']]);
          final double spentB = _safeToDouble(_expensesByCategory[b['category']]);
          final double remainingA = _safeToDouble(a['budget']) - spentA;
          final double remainingB = _safeToDouble(b['budget']) - spentB;
          return _sortAscending ? remainingA.compareTo(remainingB) : remainingB.compareTo(remainingA);
        } else if (_sortBy == 'spent') {
          final double spentA = _safeToDouble(_expensesByCategory[a['category']]);
          final double spentB = _safeToDouble(_expensesByCategory[b['category']]);
          return _sortAscending ? spentA.compareTo(spentB) : spentB.compareTo(spentA);
        } else {
          // Default sort by category
          final String categoryA = a['category'] ?? '';
          final String categoryB = b['category'] ?? '';
          return _sortAscending ? categoryA.compareTo(categoryB) : categoryB.compareTo(categoryA);
        }
      });
      
      setState(() {
        _budgets = fetched;
        _isLoading = false;
      });
      
      _calculateSummaryStats();
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error fetching budgets: $e';
      });
      _showSnackBar('Error fetching budgets: $e', isError: true);
    }
  }

  // Update the _fetchExpenses method to use ApiServiceWrapper
  Future<void> _fetchExpenses() async {
    try {
      final expensesData = await _apiService.getExpenses();
      final expensesByCategory = <String, double>{};

      for (var expense in expensesData) {
        // Only count active expenses
        if (expense['active'] == true) {
          final category = expense['category'] ?? 'Uncategorized';
          final amount = _safeToDouble(expense['amount']);
          expensesByCategory[category] = (expensesByCategory[category] ?? 0.0) + amount;
        }
      }

      setState(() {
        _expensesByCategory = expensesByCategory;
      });
      
      _calculateSummaryStats();
      
    } catch (e) {
      _showSnackBar('Error fetching expenses: $e', isError: true);
    }
  }

  // Update the _calculateSummaryStats method to use the _safeToDouble helper
  void _calculateSummaryStats() {
    double totalBudget = 0.0;
    double totalSpent = 0.0;
    double totalRemaining = 0.0;
    
    for (var budget in _budgets) {
      final double budgetAmount = _safeToDouble(budget['budget']);
      final double rolloverAmount = _safeToDouble(budget['rolloverAmount']);
      final String category = budget['category'] ?? '';
      final double spent = _safeToDouble(budget['spent'] ?? _expensesByCategory[category]);
      
      // Include rollover amount in the total budget
      final double totalBudgetWithRollover = budgetAmount + rolloverAmount;
      final double remaining = totalBudgetWithRollover - spent;
      
      totalBudget += totalBudgetWithRollover;
      totalSpent += spent;
      totalRemaining += remaining;
    }
    
    setState(() {
      _totalBudget = totalBudget;
      _totalSpent = totalSpent;
      _totalRemaining = totalRemaining;
    });
  }

  // Update _saveBudget to use ApiServiceWrapper
  Future<void> _saveBudget() async {
    setState(() {
      _isRefreshing = true;
    });
    
    if (_amountController.text.isEmpty || _selectedCategory.isEmpty) {
      setState(() {
        _isRefreshing = false;
      });
      _showSnackBar('Please fill in all required fields.', isError: true);
      return;
    }

    final budgetData = {
      'budget': double.tryParse(_amountController.text) ?? 0.0,
      'category': _selectedCategory,
      'rollover': _rollover,
    };

    try {
      if (_editingBudgetId == null) {
        // Add new budget using ApiServiceWrapper
        await _apiService.addBudget(budgetData);
        _showSnackBar('Budget added successfully!');
      } else {
        // Update existing budget using ApiServiceWrapper
        await _apiService.updateBudget(_editingBudgetId!, budgetData);
        _showSnackBar('Budget updated successfully!');
      }
      
      await _fetchBudgets();
      _clearFields();
      Navigator.of(context).pop(); // Close the dialog
    } catch (e) {
      _showSnackBar('Error saving budget: $e', isError: true);
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // Update _deleteBudget to use ApiServiceWrapper
  Future<void> _deleteBudget(String id) async {
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
          'Are you sure you want to delete this budget? This action cannot be undone.',
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
      // Use ApiServiceWrapper to delete budget
      bool success = await _apiService.deleteBudget(id);
      if (success) {
        _showSnackBar('Budget deleted successfully!');
        await _fetchBudgets();
      } else {
        _showSnackBar('Failed to delete budget', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error deleting budget: $e', isError: true);
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  void _clearFields() {
    setState(() {
      _amountController.clear();
      _selectedCategory = _expenseCategories[0];
      _editingBudgetId = null;
      _rollover = false;
    });
  }

  void _showBudgetDialog({Map<String, dynamic>? budget}) {
   if (budget != null) {
     // If editing an existing budget
     setState(() {
       _amountController.text = budget['budget'].toString();
       _selectedCategory = budget['category'] ?? _expenseCategories[0];
       _editingBudgetId = budget['_id'];
       _rollover = budget['rollover'] ?? false;
     });
   } else {
     // If adding a new budget
     _clearFields();
   }

   showDialog(
     context: context,
     builder: (context) {
       return StatefulBuilder(builder: (context, setStateDialog) {
         return AlertDialog(
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           title: Row(
             children: [
               Icon(
                 budget == null ? Icons.add_circle : Icons.edit,
                 color: Colors.blue.shade700,
               ),
               SizedBox(width: 10),
               Text(
                 budget == null ? 'Add Budget' : 'Edit Budget',
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
                     child: Theme(
                       data: Theme.of(context).copyWith(
                         canvasColor: Colors.white,
                       ),
                       child: DropdownButtonHideUnderline(
                         child: ButtonTheme(
                           alignedDropdown: true,
                           child: DropdownButton<String>(
                             value: _selectedCategory,
                             isExpanded: true,
                             icon: Icon(Icons.arrow_drop_down, color: Colors.orange),
                             items: _expenseCategories.map((cat) {
                               return DropdownMenuItem(
                                 value: cat,
                                 child: Text(
                                   cat, 
                                   style: GoogleFonts.poppins(
                                     color: Colors.black87,
                                     fontSize: 14,
                                   ),
                                 ),
                               );
                             }).toList(),
                             onChanged: (value) {
                               if (value != null) {
                                 setStateDialog(() {
                                   _selectedCategory = value;
                                 });
                               }
                             },
                             hint: Text('Select category', style: GoogleFonts.poppins(color: Colors.black54)),
                             style: GoogleFonts.poppins(color: Colors.black87),
                             dropdownColor: Colors.white,
                             padding: EdgeInsets.symmetric(horizontal: 16),
                           ),
                         ),
                       ),
                     ),
                   ),
                   SizedBox(height: 16),
                   
                   // Amount
                   Text(
                     'Budget Amount',
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
                   
                   // Rollover option
                   Row(
                     children: [
                       Checkbox(
                         value: _rollover,
                         onChanged: (value) {
                           setStateDialog(() {
                             _rollover = value ?? false;
                           });
                         },
                         activeColor: Colors.blue.shade700,
                       ),
                       Expanded(
                         child: Text(
                           'Enable Monthly Rollover',
                           style: GoogleFonts.poppins(
                             fontSize: 14,
                             color: Colors.grey.shade800,
                           ),
                         ),
                       ),
                       IconButton(
                         icon: Icon(Icons.info_outline, size: 18, color: Colors.grey),
                         onPressed: () {
                           showDialog(
                             context: context,
                             builder: (context) => AlertDialog(
                               title: Text('Monthly Rollover', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                               content: Text(
                                 'When enabled, any unspent budget amount will be added to the next month\'s budget.',
                                 style: GoogleFonts.poppins(),
                               ),
                               actions: [
                                 TextButton(
                                   onPressed: () => Navigator.of(context).pop(),
                                   child: Text('Got it', style: GoogleFonts.poppins()),
                                 ),
                               ],
                             ),
                           );
                         },
                       ),
                     ],
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
                 // Update the state with the dialog values
                 setState(() {
                   _rollover = _rollover; // Ensure rollover value is passed from dialog
                 });
                 _saveBudget();
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
                 budget == null ? 'Save Budget' : 'Update Budget',
                 style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
               ),
             ),
           ],
         );
       });
     },
   );
 }

  // Unified snackbar method to replace _showErrorSnackBar and _showSuccessSnackBar
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(10),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  Widget _buildBudgetCard(Map<String, dynamic> budget) {
    final String category = budget['category'] ?? 'Uncategorized';
    final double budgetAmount = _safeToDouble(budget['budget']);
    final double rolloverAmount = _safeToDouble(budget['rolloverAmount']);
    final bool rollover = budget['rollover'] ?? false;
    final double spent = _safeToDouble(budget['spent'] ?? _expensesByCategory[category]);
    
    // Include rollover amount in total budget
    final double totalBudget = budgetAmount + rolloverAmount;
    final double remaining = totalBudget - spent;
    final double percentSpent = totalBudget > 0 ? (spent / totalBudget) * 100 : 0;
    
    // Determine card color based on percentage spent
    Color progressColor;
    if (percentSpent >= 100) {
      progressColor = Colors.red;
    } else if (percentSpent >= 80) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.green;
    }
    
    // Determine category icon
    IconData categoryIcon;
    switch (category.toLowerCase()) {
      case 'auto & transport':
        categoryIcon = Icons.directions_car;
        break;
      case 'bills & utilities':
        categoryIcon = Icons.receipt_long;
        break;
      case 'eating out':
        categoryIcon = Icons.restaurant;
        break;
      case 'groceries':
        categoryIcon = Icons.shopping_cart;
        break;
      case 'health & medical':
        categoryIcon = Icons.medical_services;
        break;
      case 'mortgage & rent':
        categoryIcon = Icons.home;
        break;
      default:
        categoryIcon = Icons.category;
    }

  return Card(
    margin: EdgeInsets.symmetric(vertical: 6),
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                radius: 16,
                child: Icon(categoryIcon, color: Colors.blue.shade700, size: 16),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (rollover)
                      Container(
                        margin: EdgeInsets.only(top: 2),
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          'Monthly Rollover',
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '£${totalBudget.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  Text(
                    'Budget',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBudgetStat(
                label: 'Spent',
                amount: spent,
                color: Colors.red.shade700,
              ),
              _buildBudgetStat(
                label: 'Remaining',
                amount: remaining,
                color: remaining >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              ),
              _buildBudgetStat(
                label: 'Percentage',
                percentage: percentSpent,
                color: progressColor,
              ),
            ],
          ),
          SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentSpent / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 6,
            ),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.edit, color: Colors.blue.shade700, size: 20),
                onPressed: () => _showBudgetDialog(budget: budget),
                tooltip: 'Edit Budget',
                padding: EdgeInsets.all(4),
                constraints: BoxConstraints(),
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red.shade700, size: 20),
                onPressed: () => _deleteBudget(budget['_id']),
                tooltip: 'Delete Budget',
                padding: EdgeInsets.all(4),
                constraints: BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
  
  Widget _buildBudgetStat({
    required String label,
    double? amount,
    double? percentage,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          percentage != null 
            ? '${percentage.toStringAsFixed(1)}%' 
            : '£${amount!.toStringAsFixed(2)}',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetList() {
    // Filter _budgets by the search query (if provided).
    List<Map<String, dynamic>> displayedList = _budgets;
    if (_searchController.text.isNotEmpty) {
      displayedList = _budgets.where((budget) {
        String category = budget['category']?.toLowerCase() ?? '';
        return category.contains(_searchController.text.toLowerCase());
      }).toList();
    }

    if (displayedList.isEmpty) {
      return _buildEmptyState();
    }
  
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: displayedList.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        return _buildBudgetCard(displayedList[index]);
      },
    );
  }
  
  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(32),
      margin: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1), // Changed from 0.9 to 0.1 for transparency
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet,
            size: 64,
            color: Colors.blue.shade200,
          ),
          SizedBox(height: 24),
          Text(
            'No Budgets Found',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Start managing your finances by creating your first budget.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showBudgetDialog(),
            icon: Icon(Icons.add),
            label: Text(
              'Add Budget',
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
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Budget Summary',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_budgets.length} Categories',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem(
                        title: 'Total Budget',
                        value: '£${_totalBudget.toStringAsFixed(2)}',
                        icon: Icons.account_balance_wallet,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildSummaryItem(
                        title: 'Total Spent',
                        value: '£${_totalSpent.toStringAsFixed(2)}',
                        icon: Icons.shopping_cart,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildSummaryItem(
                        title: 'Remaining',
                        value: '£${_totalRemaining.toStringAsFixed(2)}',
                        icon: Icons.savings,
                      ),
                    ),
                  ],
                );
              },
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
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.white.withOpacity(0.7)),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSortingOptions() {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            'Sort by:',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSortButton('Category', 'category'),
                  _buildSortButton('Budget', 'budget'),
                  _buildSortButton('Spent', 'spent'),
                  _buildSortButton('Remaining', 'remaining'),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              color: Colors.white,
              size: 16,
            ),
            onPressed: () {
              setState(() {
                _sortAscending = !_sortAscending;
                _fetchBudgets();
              });
            },
            tooltip: _sortAscending ? 'Ascending' : 'Descending',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSortButton(String label, String value) {
    final bool isSelected = _sortBy == value;
    
    return Padding(
      padding: EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          setState(() {
            _sortBy = value;
            _fetchBudgets();
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            border: Border.all(
              color: Colors.white,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blue.shade700 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// Shows a dialog with information about the Budgets page.
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
                'About Budgets Page',
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
                  'This page allows you to manage your budget for different expense categories:',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 16),
                _buildInfoItem(
                  icon: Icons.add_circle,
                  color: Colors.green,
                  text: 'Add new budgets by tapping the + button',
                ),
                _buildInfoItem(
                  icon: Icons.category,
                  color: Colors.blue,
                  text: 'Set budgets for any expense category',
                ),
                _buildInfoItem(
                  icon: Icons.repeat,
                  color: Colors.orange,
                  text: 'Enable monthly rollover to carry unspent amounts to the next month',
                ),
                _buildInfoItem(
                  icon: Icons.bar_chart,
                  color: Colors.purple,
                  text: 'Track your spending against your budget with visual indicators',
                ),
                _buildInfoItem(
                  icon: Icons.search,
                  color: Colors.teal,
                  text: 'Search for budgets by category name',
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
    final currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Manage Budgets',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () async {
              await _fetchBudgets();
              await _fetchExpenses();
            },
            tooltip: 'Refresh data',
          ),
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
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
        height: double.infinity,
        width: double.infinity,
        child: SafeArea(
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
                            'Loading your budget data...',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: Colors.white,
                      backgroundColor: Colors.blue.shade700,
                      onRefresh: () async {
                        await _fetchBudgets();
                        await _fetchExpenses();
                      },
                      child: SingleChildScrollView(
                        physics: AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Current month header
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Budgets for $currentMonth',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            
                            // Summary card
                            _buildSummaryCard(),
                            
                            // Sorting options
                            _buildSortingOptions(),
                            
                            // Search field - reduced margin
                            Container(
                              margin: EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search by category',
                                  prefixIcon: Icon(Icons.search, color: Colors.white),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
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
                            
                            // Budget list - reduced spacing between items
                            _buildBudgetList(),
                            
                            // Add padding at the bottom for FAB
                            SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
              
              // Loading overlay
              if (_isRefreshing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBudgetDialog(),
        icon: Icon(Icons.add),
        label: Text(
          'Add Budget',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade800,
      ),
    );
  }
}
