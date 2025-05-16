import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

// Import the ApiServiceWrapper
import 'package:frontend/services/api_service_wrapper.dart';

class IncomePage extends StatefulWidget {
  const IncomePage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _IncomePageState createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage> with SingleTickerProviderStateMixin {
  // Controllers for the form fields.
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController(); // For free‑text source
  final TextEditingController _searchController = TextEditingController(); // For searching income by source

  // Parent state variables for editing.
  String _selectedFrequency = '';
  String _selectedCategory = '';

  // For editing an existing income entry.
  String? _editingIncomeId;

  // Options for frequency.
  final List<String> _frequencies = [
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

  // Options for category.
  final List<String> _categories = [
    'Salary',
    'Freelance',
    'Passive Income',
    'Friends and Family',
    'Other',
  ];

  List<Map<String, dynamic>> _incomeList = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasError = false;
  String _errorMessage = '';

  // This switch controls whether to show inactive income on the All Income tab.
  bool _showInactive = true;

  // Secure storage for auth token.
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Tab controller for Upcoming vs All Income.
  late TabController _tabController;
  
  // For animations
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  
  // For summary stats
  double _totalMonthlyIncome = 0.0;
  double _totalYearlyIncome = 0.0;
  int _activeIncomeCount = 0;
  
  // For sorting
  String _sortBy = 'date';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    // Set defaults.
    _selectedFrequency = _frequencies[0]; // Default to "Just once"
    _selectedCategory = _categories[0];   // Default to "Salary"
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      _fetchIncome();
    });
    _fetchIncome();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _sourceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Remove this method if not used elsewhere
  // Future<String?> _getAuthToken() async {
  //   return await _secureStorage.read(key: 'authToken');
  // }

  /// Returns a formatted date string.
  String _formatDate(String date) {
    try {
      final parsedDate = DateTime.parse(date).toLocal();
      return DateFormat('yyyy-MM-dd').format(parsedDate);
    } catch (e) {
      return date;
    }
  }

  /// Helper function: add a number of months to a date.
  DateTime addMonths(DateTime date, int months) {
    int newYear = date.year + ((date.month + months - 1) ~/ 12);
    int newMonth = ((date.month + months - 1) % 12) + 1;
    int newDay = date.day;
    int daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
    if (newDay > daysInNewMonth) {
      newDay = daysInNewMonth;
    }
    return DateTime(newYear, newMonth, newDay);
  }

  /// Computes the next deposit date based on deposit date and frequency.
  DateTime? _getNextDeposit(DateTime depositDate, String? frequency) {
    if (frequency == null || frequency.isEmpty) return null;
    final today = DateTime.now();
    DateTime next = depositDate;
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
      while (!next.isAfter(today) ||
          (next.weekday != DateTime.saturday && next.weekday != DateTime.sunday)) {
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

  /// Calculate summary statistics from income data
  void _calculateSummaryStats() {
    final now = DateTime.now();
    final currentMonth = DateFormat('yyyy-MM').format(now);
    final currentYear = DateFormat('yyyy').format(now);
    
    double monthlyTotal = 0.0;
    double yearlyTotal = 0.0;
    int activeCount = 0;
    
    for (var income in _incomeList) {
      if (income['active'] == true) {
        activeCount++;
        
        final double amount = income['amount']?.toDouble() ?? 0.0;
        final String dateStr = income['date'] ?? '';
        final String frequency = income['frequency'] ?? '';
        
        try {
          final DateTime date = DateTime.parse(dateStr);
          final String incomeMonth = DateFormat('yyyy-MM').format(date);
          final String incomeYear = DateFormat('yyyy').format(date);
          
          // Calculate monthly income
          if (incomeMonth == currentMonth) {
            monthlyTotal += amount;
          }
          
          // Calculate yearly income
          if (incomeYear == currentYear) {
            yearlyTotal += amount;
            
            // For recurring income, estimate the yearly total
            if (frequency == 'Every month') {
              // If it's a monthly income, add it for remaining months
              final int currentMonthNum = now.month;
              final int incomeMonthNum = date.month;
              
              if (incomeMonthNum <= currentMonthNum) {
                // Already counted this month, so add for remaining months
                yearlyTotal += amount * (12 - currentMonthNum);
              }
            } else if (frequency == 'Every week') {
              // Estimate weekly income for the year
              final int weeksInYear = 52;
              final int currentWeek = (now.difference(DateTime(now.year, 1, 1)).inDays / 7).floor();
              yearlyTotal += amount * (weeksInYear - currentWeek);
            }
          }
        } catch (e) {
          // Skip this income if date parsing fails
        }
      }
    }
    
    setState(() {
      _totalMonthlyIncome = monthlyTotal;
      _totalYearlyIncome = yearlyTotal;
      _activeIncomeCount = activeCount;
    });
  }

  /// Fetch income entries.
  /// - For Upcoming Income (tab 0): show entries with deposit date > today.
  /// - For All Income (tab 1): show all entries; if _showInactive is false, filter out inactive ones.
  Future<void> _fetchIncome() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    
    try {
      final apiService = ApiServiceWrapper();
      List<dynamic> response = await apiService.getIncome();
      
      List<Map<String, dynamic>> fetched = List<Map<String, dynamic>>.from(response);
          
      // Sort the income list
      fetched.sort((a, b) {
        if (_sortBy == 'amount') {
          final double amountA = a['amount']?.toDouble() ?? 0.0;
          final double amountB = b['amount']?.toDouble() ?? 0.0;
          return _sortAscending ? amountA.compareTo(amountB) : amountB.compareTo(amountA);
        } else if (_sortBy == 'source') {
          final String sourceA = a['source'] ?? '';
          final String sourceB = b['source'] ?? '';
          return _sortAscending ? sourceA.compareTo(sourceB) : sourceB.compareTo(sourceA);
        } else if (_sortBy == 'category') {
          final String categoryA = a['category'] ?? '';
          final String categoryB = b['category'] ?? '';
          return _sortAscending ? categoryA.compareTo(categoryB) : categoryB.compareTo(categoryA);
        } else {
          // Default sort by date
          final String dateA = a['date'] ?? '';
          final String dateB = b['date'] ?? '';
          return _sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
        }
      });
          
      if (_tabController.index == 0) {
        // Upcoming Income: filter by deposit date in the future.
        fetched = fetched.where((income) {
          DateTime depositDate = DateTime.tryParse(income['date']) ?? DateTime.now();
          return depositDate.isAfter(DateTime.now());
        }).toList();
      } else if (_tabController.index == 1 && !_showInactive) {
        // All Income: filter out inactive incomes if the switch is off.
        fetched = fetched.where((income) => income['active'] == true).toList();
      }
      
      setState(() {
        _incomeList = fetched;
        _isLoading = false;
      });
      
      // Calculate summary statistics
      _calculateSummaryStats();
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error fetching income: $e';
      });
      _showErrorSnackBar('Error fetching income: $e');
    }
  }

  /// Save (add/update) an income entry using the provided frequency and category.
  Future<void> _saveIncome({required String frequency, required String category}) async {
    setState(() {
      _isRefreshing = true;
    });
    
    if (_amountController.text.isEmpty ||
        _sourceController.text.isEmpty ||
        _dateController.text.isEmpty) {
      setState(() {
        _isRefreshing = false;
      });
      _showErrorSnackBar('Please fill in all required fields.');
      return;
    }

    final incomeData = {
      'amount': double.tryParse(_amountController.text) ?? 0.0,
      'source': _sourceController.text.trim(),
      'frequency': frequency,
      'category': category,
      'description': _descriptionController.text.trim(),
      'date': _dateController.text.trim(),
      'active': true,
    };

    try {
      final apiService = ApiServiceWrapper();
      
      if (_editingIncomeId == null) {
        await apiService.addIncome(incomeData);
        _showSuccessSnackBar('Income added successfully!');
      } else {
        await apiService.updateIncome(_editingIncomeId!, incomeData);
        _showSuccessSnackBar('Income updated successfully!');
      }
      
      await _fetchIncome();
      _clearFields();
      Navigator.of(context).pop(); // Close the dialog.
    } catch (e) {
      _showErrorSnackBar('Error saving income: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  /// Delete an income entry.
  Future<void> _deleteIncome(String id) async {
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
          'Are you sure you want to delete this income entry? This action cannot be undone.',
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
      await apiService.deleteIncome(id);
      _showSuccessSnackBar('Income deleted successfully!');
      await _fetchIncome();
    } catch (e) {
      _showErrorSnackBar('Error deleting income: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  /// Toggle the active/inactive status of an income entry.
  Future<void> _toggleActiveIncome(String id, bool newStatus) async {
    setState(() {
      _isRefreshing = true;
    });
    
    final updateData = {'active': newStatus};
    try {
      final apiService = ApiServiceWrapper();
      await apiService.updateIncome(id, updateData);
      await _fetchIncome();
      _showSuccessSnackBar(
        newStatus 
          ? 'Income activated successfully.' 
          : 'Income deactivated successfully.'
      );
    } catch (e) {
      _showErrorSnackBar('Error updating status: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  /// Skip the next payment by updating the deposit date to the next occurrence.
  Future<void> _skipNextPayment(String id, Map<String, dynamic> income) async {
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      DateTime currentDeposit = DateTime.parse(income['date']);
      String? frequency = income['frequency'];
      if (frequency == null || frequency.isEmpty) {
        setState(() {
          _isRefreshing = false;
        });
        _showErrorSnackBar('Frequency not set.');
        return;
      }
      
      DateTime? nextDeposit = _getNextDeposit(currentDeposit, frequency);
      if (nextDeposit == null) {
        setState(() {
          _isRefreshing = false;
        });
        _showErrorSnackBar('No upcoming deposit found.');
        return;
      }
      
      final updateData = {'date': DateFormat('yyyy-MM-dd').format(nextDeposit)};
      final apiService = ApiServiceWrapper();
      await apiService.updateIncome(id, updateData);
      
      await _fetchIncome();
      _showSuccessSnackBar('Next payment skipped successfully.');
    } catch (e) {
      _showErrorSnackBar('Error skipping payment: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  /// Clears all input fields, resetting dropdowns to default values.
  void _clearFields() {
    setState(() {
      _amountController.clear();
      _sourceController.clear();
      _descriptionController.clear();
      _dateController.clear();
      _selectedFrequency = _frequencies[0];
      _selectedCategory = _categories[0];
      _editingIncomeId = null;
    });
  }

  /// Shows the Income History dialog.
  void _showHistory(Map<String, dynamic> income) {
    List<dynamic> history = income['history'] ?? [];
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
                'Income History',
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
                        'This income entry has no recorded history yet.',
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
                        entryText = 'Skipped deposit on ${DateFormat('yyyy-MM-dd').format(date)}';
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

  /// Shows the Add/Edit Income dialog using a StatefulBuilder for local state.
  void _showIncomeDialog() {
    // Initialize local variables from parent's state.
    String localFrequency = _selectedFrequency;
    String localCategory = _selectedCategory;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          // Check if running on Android
          final bool isAndroid = Theme.of(context).platform == TargetPlatform.android;
          
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  _editingIncomeId == null ? Icons.add_circle : Icons.edit,
                  color: Colors.blue.shade700,
                ),
                SizedBox(width: 10),
                Text(
                  _editingIncomeId == null ? 'Add Income' : 'Edit Income',
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
                    
                    // Source
                    Text(
                      'Source',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _sourceController,
                      decoration: InputDecoration(
                        hintText: 'Enter source name',
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
                                items: _frequencies.map((freq) {
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
                            items: _frequencies.map((freq) {
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
                                items: _categories.map((cat) {
                                  return DropdownMenuItem(
                                    value: cat,
                                    child: Text(cat, style: GoogleFonts.poppins(color: Colors.black)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setStateDialog(() {
                                      localCategory = value;
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
                            items: _categories.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(cat, style: GoogleFonts.poppins()),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setStateDialog(() {
                                localCategory = value!;
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
                    
                    // Deposit Date
                    Text(
                      'Deposit Date',
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
                          initialDate: DateTime.now(),
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
                          _dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
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
                    _selectedFrequency = localFrequency;
                    _selectedCategory = localCategory;
                  });
                  _saveIncome(frequency: localFrequency, category: localCategory);
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
                  _editingIncomeId == null ? 'Save Income' : 'Update Income',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          );
        });
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

  /// Builds an ExpansionTile for a single income entry.
  Widget _buildIncomeTile(Map<String, dynamic> income) {
    final double amount = income['amount']?.toDouble() ?? 0.0;
    final String source = income['source'] ?? 'Unknown';
    final String frequency = (income['frequency'] != null && income['frequency'].toString().isNotEmpty)
        ? income['frequency']
        : _selectedFrequency;
    final String category = (income['category'] != null && income['category'].toString().isNotEmpty)
        ? income['category']
        : _selectedCategory;
    final String dateStr = income['date'] ?? '';
    final DateTime depositDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    final bool isActive = income['active'] ?? true;
    final String description = income['description'] ?? '';

    final DateTime? nextDeposit = _getNextDeposit(depositDate, frequency);
    
    // Determine card color based on category
    Color categoryColor;
    IconData categoryIcon;
    
    switch (category.toLowerCase()) {
      case 'salary':
        categoryColor = Colors.blue;
        categoryIcon = Icons.work;
        break;
      case 'freelance':
        categoryColor = Colors.purple;
        categoryIcon = Icons.computer;
        break;
      case 'passive income':
        categoryColor = Colors.green;
        categoryIcon = Icons.auto_graph;
        break;
      case 'friends and family':
        categoryColor = Colors.orange;
        categoryIcon = Icons.people;
        break;
      default:
        categoryColor = Colors.teal;
        categoryIcon = Icons.category;
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
                        source,
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
                        color: isActive ? Colors.green.shade700 : Colors.grey,
                      ),
                    ),
                    Text(
                      _formatDate(dateStr),
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
                          'Next Deposit: ',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          nextDeposit != null 
                            ? DateFormat('yyyy-MM-dd').format(nextDeposit) 
                            : 'N/A',
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
                              _editingIncomeId = income['_id'];
                              _amountController.text = amount.toString();
                              _sourceController.text = source;
                              _selectedFrequency = (income['frequency'] != null &&
                                      _frequencies.contains(income['frequency']))
                                  ? income['frequency']
                                  : _frequencies[0];
                              _selectedCategory = (income['category'] != null &&
                                      _categories.contains(income['category']))
                                  ? income['category']
                                  : _categories[0];
                              _descriptionController.text = description;
                              _dateController.text = _formatDate(dateStr);
                            });
                            _showIncomeDialog();
                          },
                        ),
                        
                        ActionButton(
                          label: isActive ? 'Deactivate' : 'Activate',
                          icon: isActive ? Icons.visibility_off : Icons.visibility,
                          color: Colors.orange,
                          onPressed: () {
                            _toggleActiveIncome(income['_id'], !isActive);
                          },
                        ),
                        
                        ActionButton(
                          label: 'Skip Next',
                          icon: Icons.skip_next,
                          color: Colors.purple,
                          onPressed: () {
                            _skipNextPayment(income['_id'], income);
                          },
                        ),
                        
                        ActionButton(
                          label: 'Delete',
                          icon: Icons.delete,
                          color: Colors.red,
                          onPressed: () {
                            _deleteIncome(income['_id']);
                          },
                        ),
                        
                        ActionButton(
                          label: 'History',
                          icon: Icons.history,
                          color: Colors.teal,
                          onPressed: () {
                            _showHistory(income);
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

  /// Builds the list of income entries (with search filtering by source).
  Widget _buildIncomeList() {
    // Filter _incomeList by the search query (if provided).
    List<Map<String, dynamic>> displayedList = _incomeList;
    if (_searchController.text.isNotEmpty) {
      displayedList = _incomeList.where((income) {
        String src = income['source']?.toLowerCase() ?? '';
        return src.contains(_searchController.text.toLowerCase());
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
        return _buildIncomeTile(displayedList[index]);
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
            _tabController.index == 0 ? Icons.calendar_today : Icons.attach_money,
            size: 64,
            color: Colors.blue.shade200,
          ),
          SizedBox(height: 24),
          Text(
            _tabController.index == 0 
              ? 'No Upcoming Income' 
              : 'No Income Records Found',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          SizedBox(height: 16),
          Text(
            _tabController.index == 0
              ? 'You don\'t have any upcoming income scheduled.'
              : 'Start tracking your income by adding your first entry.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showIncomeDialog,
            icon: Icon(Icons.add),
            label: Text(
              'Add Income',
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
    // Get screen width to calculate appropriate sizes
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      width: screenWidth - 40, // Account for the padding on both sides
      clipBehavior: Clip.antiAlias, // Ensure nothing overflows
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
        padding: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with fixed height
            SizedBox(
              height: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Income Summary',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_activeIncomeCount Active',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            // Summary items in a row with fixed width constraints
            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem(
                        title: 'This Month',
                        value: '£${_totalMonthlyIncome.toStringAsFixed(2)}',
                        icon: Icons.calendar_month,
                        maxWidth: (constraints.maxWidth - 16) / 2,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildSummaryItem(
                        title: 'Projected Yearly',
                        value: '£${_totalYearlyIncome.toStringAsFixed(2)}',
                        icon: Icons.auto_graph,
                        maxWidth: (constraints.maxWidth - 16) / 2,
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
    required double maxWidth,
  }) {
    return Container(
      width: maxWidth,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.white.withOpacity(0.7)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          // Use FittedBox to prevent overflow
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 18,
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
                  _buildSortButton('Date', 'date'),
                  _buildSortButton('Amount', 'amount'),
                  _buildSortButton('Source', 'source'),
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
                _fetchIncome();
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
            _fetchIncome();
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

  /// Shows a dialog with information about the Income page.
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
                'About Income Page',
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
                  'This page allows you to manage your income entries:',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 16),
                _buildInfoItem(
                  icon: Icons.add_circle,
                  color: Colors.green,
                  text: 'Add new income by tapping the + button',
                ),
                _buildInfoItem(
                  icon: Icons.search,
                  color: Colors.blue,
                  text: 'Use the search bar to filter entries by source',
                ),
                _buildInfoItem(
                  icon: Icons.edit,
                  color: Colors.orange,
                  text: 'Edit, delete, or change status of any entry',
                ),
                _buildInfoItem(
                  icon: Icons.skip_next,
                  color: Colors.purple,
                  text: 'Skip the next payment for recurring income',
                ),
                _buildInfoItem(
                  icon: Icons.visibility_off,
                  color: Colors.grey,
                  text: 'Inactive entries are shown in the All Income tab',
                ),
                _buildInfoItem(
                  icon: Icons.history,
                  color: Colors.teal,
                  text: 'View history of changes for each income entry',
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
    
    return DefaultTabController(
      length: 2,
      initialIndex: _tabController.index,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            'Manage Income',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.info_outline, color: Colors.white),
              onPressed: _showInfoDialog,
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
              Tab(text: 'Upcoming Income'),
              Tab(text: 'All Income'),
            ],
          ),
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
          child: SafeArea(
            child: Column(
              children: [
                // Summary card - now placed below the tab bar
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _buildSummaryCard(),
                ),
                
                // Main scrollable content
                Expanded(
                  child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                            SizedBox(height: 20),
                            Text(
                              'Loading your income data...',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        key: _refreshIndicatorKey,
                        color: Colors.white,
                        backgroundColor: Colors.blue.shade700,
                        onRefresh: _fetchIncome,
                        child: SingleChildScrollView(
                          physics: AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Show inactive switch for All Income tab
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
                                        "Show Inactive Income",
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
                                            _fetchIncome();
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
                              
                              // Search field
                              Container(
                                margin: EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search by source',
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
                              
                              // Income list
                              _buildIncomeList(),
                            ],
                          ),
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
          onPressed: _showIncomeDialog,
          icon: Icon(Icons.add),
          label: Text(
            'Add Income',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue.shade800,
        ),
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
