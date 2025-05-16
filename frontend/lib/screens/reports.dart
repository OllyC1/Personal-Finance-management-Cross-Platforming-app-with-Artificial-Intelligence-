import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../services/api_service_wrapper.dart';
import 'package:flutter/foundation.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> with TickerProviderStateMixin {
  final ApiServiceWrapper _apiService = ApiServiceWrapper();

  // Raw data lists from the backend.
  List<Map<String, dynamic>> incomeList = [];
  List<Map<String, dynamic>> expenseList = [];
  List<Map<String, dynamic>> goalList = [];
  List<Map<String, dynamic>> savingsExpenseList = []; // New list for savings expenses
  List<Map<String, dynamic>> debtExpenseList = []; // New list for debt expenses

  // Aggregated totals.
  double totalIncome = 0.0;
  double totalExpenses = 0.0;
  double totalSavings = 0.0;
  double totalDebt = 0.0;
  double netCashflow = 0.0;
  double savingsRate = 0.0;

  // Dropdown selections.
  String _selectedMonth = 'All Time';
  List<String> _months = ['All Time'];

  String _selectedReportCategory = 'All';
  final List<String> _reportCategories = ['All', 'Income', 'Expense', 'Savings', 'Debt'];

  String chartType = 'Pie Chart';
  final List<String> _chartTypes = ['Pie Chart', 'Bar Chart', 'Line Chart'];

  // For comparison feature
  bool _showComparison = false;
  String _comparisonMonth = '';
  Map<String, double> _previousPeriodData = {};

  // Advice (insights) list.
  List<Map<String, dynamic>> insights = [];

  bool isLoading = false;
  bool isRefreshing = false;
  bool hasError = false;
  String errorMessage = '';

  // Animation controllers
  late AnimationController _summaryCardAnimationController;
  late AnimationController _filterCardAnimationController;
  late AnimationController _chartAnimationController;
  late AnimationController _insightsAnimationController;
  
  // Animations
  late Animation<double> _summaryCardAnimation;
  late Animation<double> _filterCardAnimation;
  late Animation<double> _chartAnimation;
  late Animation<double> _insightsAnimation;

  @override
  void initState() {
    super.initState();
    _generateMonthsList();
    _setupAnimations();
    _fetchAllData();
  }

  void _setupAnimations() {
    // Summary card animation
    _summaryCardAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _summaryCardAnimation = CurvedAnimation(
      parent: _summaryCardAnimationController,
      curve: Curves.easeOutQuad,
    );

    // Filter card animation
    _filterCardAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _filterCardAnimation = CurvedAnimation(
      parent: _filterCardAnimationController,
      curve: Curves.easeOutQuad,
    );

    // Chart animation
    _chartAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _chartAnimation = CurvedAnimation(
      parent: _chartAnimationController,
      curve: Curves.easeOutQuad,
    );

    // Insights animation
    _insightsAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _insightsAnimation = CurvedAnimation(
      parent: _insightsAnimationController,
      curve: Curves.easeOutQuad,
    );

    // Start animations sequentially
    _summaryCardAnimationController.forward().then((_) {
      _filterCardAnimationController.forward().then((_) {
        _chartAnimationController.forward().then((_) {
          _insightsAnimationController.forward();
        });
      });
    });
  }

  @override
  void dispose() {
    _summaryCardAnimationController.dispose();
    _filterCardAnimationController.dispose();
    _chartAnimationController.dispose();
    _insightsAnimationController.dispose();
    super.dispose();
  }

  // Generate a list of months for the dropdown
  void _generateMonthsList() {
    List<String> months = ['All Time'];
    
    // Get current date
    DateTime now = DateTime.now();
    
    // Add the current month and the previous 11 months
    for (int i = 0; i < 12; i++) {
      DateTime month = DateTime(now.year, now.month - i, 1);
      String formattedMonth = DateFormat('yyyy-MM').format(month);
      months.add(formattedMonth);
    }
    
    setState(() {
      _months = months;
      _selectedMonth = months[0]; // Default to 'All Time'
      if (months.length > 1) {
        _comparisonMonth = months[1]; // Default comparison to current month
      }
    });
  }

  // Retrieve the auth token.
  Future<String?> _getAuthToken() async {
    return await _apiService.getAuthToken();
  }

  /// Fetch income, expenses, and goals concurrently.
  Future<void> _fetchAllData() async {
    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
      incomeList = [];
      expenseList = [];
      goalList = [];
      savingsExpenseList = []; // Clear savings expenses
      debtExpenseList = []; // Clear debt expenses
      totalIncome = 0.0;
      totalExpenses = 0.0;
      totalSavings = 0.0;
      totalDebt = 0.0;
      netCashflow = 0.0;
      savingsRate = 0.0;
      insights = [];
    });
    
    final token = await _getAuthToken();
    if (token == null) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'User not authenticated';
      });
      _showErrorSnackBar('Error: User not authenticated.');
      return;
    }
    
    try {
      await Future.wait([
        _fetchIncome(token),
        _fetchExpenses(token),
        _fetchGoals(token),
        _fetchSavingsExpenses(token), // New method to fetch savings expenses
        _fetchDebtExpenses(token), // New method to fetch debt expenses
      ]);
      
      // If comparison is enabled, fetch previous period data
      if (_showComparison && _comparisonMonth != '') {
        await _fetchComparisonData(token);
      }
      
      _computeAggregates();
      _computeInsights();
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Error fetching data: $e';
      });
      _showErrorSnackBar('Error fetching data: $e');
    } finally {
      setState(() { 
        isLoading = false; 
      });
    }
  }

  Future<void> _fetchIncome(String token) async {
    try {
      final data = await _apiService.getIncome(month: _selectedMonth == 'All Time' ? null : _selectedMonth);
      setState(() { 
        incomeList = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      _showErrorSnackBar('Error fetching income: $e');
    }
  }

  Future<void> _fetchExpenses(String token) async {
    try {
      final data = await _apiService.getExpenses(month: _selectedMonth == 'All Time' ? null : _selectedMonth);
      setState(() { 
        expenseList = data
            .where((e) => 
                (e['category'] as String).toLowerCase() != 'savings' && 
                (e['category'] as String).toLowerCase() != 'debt')
            .map((e) => e as Map<String, dynamic>)
            .toList(); 
        expenseList = List<Map<String, dynamic>>.from(expenseList);
      });
    } catch (e) {
      _showErrorSnackBar('Error fetching expenses: $e');
    }
  }

  // New method to fetch savings expenses
  Future<void> _fetchSavingsExpenses(String token) async {
    try {
      final data = await _apiService.getExpenses(month: _selectedMonth == 'All Time' ? null : _selectedMonth);
      setState(() { 
        savingsExpenseList = data
            .where((e) => (e['category'] as String).toLowerCase() == 'savings')
            .map((e) => e as Map<String, dynamic>)
            .toList();
        savingsExpenseList = List<Map<String, dynamic>>.from(savingsExpenseList);
      });
    } catch (e) {
      debugPrint('Error fetching savings expenses: $e');
    }
  }

  // New method to fetch debt expenses
  Future<void> _fetchDebtExpenses(String token) async {
    try {
      final data = await _apiService.getExpenses(month: _selectedMonth == 'All Time' ? null : _selectedMonth);
      setState(() { 
        debtExpenseList = data
            .where((e) => (e['category'] as String).toLowerCase() == 'debt')
            .map((e) => e as Map<String, dynamic>)
            .toList();
        debtExpenseList = List<Map<String, dynamic>>.from(debtExpenseList);
      });
    } catch (e) {
      debugPrint('Error fetching debt expenses: $e');
    }
  }

  Future<void> _fetchGoals(String token) async {
    try {
      final data = await _apiService.getGoals();
      setState(() { 
        goalList = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      _showErrorSnackBar('Error fetching goals: $e');
    }
  }

  // Fetch data for comparison period
  Future<void> _fetchComparisonData(String token) async {
    if (_comparisonMonth == '' || _comparisonMonth == 'All Time') return;
    
    try {
      // Save current selection
      String currentMonth = _selectedMonth;
      
      // Temporarily set selected month to comparison month
      _selectedMonth = _comparisonMonth;
      
      // Fetch income for comparison period
      final incomeData = await _apiService.getIncome(month: _comparisonMonth);
      
      // Fetch expenses for comparison period
      final expenseData = await _apiService.getExpenses(month: _comparisonMonth);
      
      // Restore current selection
      _selectedMonth = currentMonth;
      
      // Process income data
      double prevIncome = 0.0;
      for (var income in incomeData) {
        prevIncome += (income['amount'] as num).toDouble();
      }
      
      // Process expense data
      double prevExpense = 0.0;
      double prevSavings = 0.0;
      double prevDebt = 0.0;
      
      for (var expense in expenseData) {
        String category = (expense['category'] as String).toLowerCase();
        double amount = (expense['amount'] as num).toDouble();
        
        if (category == 'savings') {
          prevSavings += amount;
        } else if (category == 'debt') {
          prevDebt += amount;
        } else {
          prevExpense += amount;
        }
      }
      
      // Calculate previous period metrics
      double prevNetCashflow = prevIncome - prevExpense;
      double prevSavingsRate = prevIncome > 0 ? (prevSavings / prevIncome) * 100 : 0;
      
      setState(() {
        _previousPeriodData = {
          'income': prevIncome,
          'expenses': prevExpense,
          'savings': prevSavings,
          'debt': prevDebt,
          'netCashflow': prevNetCashflow,
          'savingsRate': prevSavingsRate,
        };
      });
    } catch (e) {
      debugPrint('Error fetching comparison data: $e');
    }
  }

  // Compute aggregated totals.
  void _computeAggregates() {
    double incomeSum = 0.0;
    for (var income in incomeList) {
      incomeSum += (income['amount'] as num).toDouble();
    }
    
    double expenseSum = 0.0;
    for (var expense in expenseList) {
      expenseSum += (expense['amount'] as num).toDouble();
    }
    
    // Calculate savings from both goals and direct savings expenses
    double savingsSum = 0.0;
    for (var goal in goalList) {
      if ((goal['type'] as String).toLowerCase() == 'savings') {
        savingsSum += (goal['progress'] as num).toDouble();
      }
    }
    
    // Add direct savings expenses
    for (var savings in savingsExpenseList) {
      savingsSum += (savings['amount'] as num).toDouble();
    }
    
    // Calculate debt from both goals and direct debt expenses
    double debtSum = 0.0;
    for (var goal in goalList) {
      if ((goal['type'] as String).toLowerCase() == 'debt') {
        debtSum += (goal['progress'] as num).toDouble();
      }
    }
    
    // Add direct debt expenses
    for (var debt in debtExpenseList) {
      debtSum += (debt['amount'] as num).toDouble();
    }
    
    // Calculate net cashflow and savings rate
    double netCashflowValue = incomeSum - expenseSum;
    double savingsRateValue = incomeSum > 0 ? (savingsSum / incomeSum) * 100 : 0;
    
    setState(() {
      totalIncome = incomeSum;
      totalExpenses = expenseSum;
      totalSavings = savingsSum;
      totalDebt = debtSum;
      netCashflow = netCashflowValue;
      savingsRate = savingsRateValue;
    });
  }

  // Compute insights (advice) based on overall data.
  void _computeInsights() {
    List<Map<String, dynamic>> newInsights = [];
    
    if (_selectedReportCategory == 'All') {
      // Income vs Expenses
      if (totalIncome > 0 && totalExpenses > 0) {
        if (totalExpenses > totalIncome) {
          newInsights.add({
            'type': 'warning',
            'icon': Icons.warning_amber_rounded,
            'title': 'Spending Exceeds Income',
            'message': 'Your expenses (£${totalExpenses.toStringAsFixed(2)}) are higher than your income (£${totalIncome.toStringAsFixed(2)}). Consider reducing expenses or finding additional income sources.',
          });
        } else if (totalExpenses > 0.9 * totalIncome) {
          newInsights.add({
            'type': 'warning',
            'icon': Icons.warning_amber_rounded,
            'title': 'High Expense Ratio',
            'message': 'You\'re spending ${((totalExpenses / totalIncome) * 100).toStringAsFixed(1)}% of your income. Try to keep this below 90% for financial stability.',
          });
        } else {
          newInsights.add({
            'type': 'success',
            'icon': Icons.check_circle,
            'title': 'Positive Cash Flow',
            'message': 'You have a positive cash flow of £${netCashflow.toStringAsFixed(2)}. Great job managing your finances!',
          });
        }
      }
      
      // Savings Rate
      if (totalIncome > 0) {
        if (savingsRate < 10) {
          newInsights.add({
            'type': 'warning',
            'icon': Icons.savings_outlined,
            'title': 'Low Savings Rate',
            'message': 'Your savings rate is ${savingsRate.toStringAsFixed(1)}%. Financial experts recommend saving at least 15-20% of your income.',
          });
        } else if (savingsRate >= 20) {
          newInsights.add({
            'type': 'success',
            'icon': Icons.savings,
            'title': 'Excellent Savings Rate',
            'message': 'Your savings rate is ${savingsRate.toStringAsFixed(1)}%. You\'re on track for long-term financial security!',
          });
        }
      }
      
      // Debt Management
      if (totalDebt > 0) {
        if (totalDebt > 0.5 * totalIncome) {
          newInsights.add({
            'type': 'warning',
            'icon': Icons.account_balance,
            'title': 'High Debt Level',
            'message': 'Your debt payments represent a significant portion of your income. Consider focusing on debt reduction strategies.',
          });
        }
      }
      
      // Comparison insights (if enabled)
      if (_showComparison && _previousPeriodData.isNotEmpty) {
        // Income trend
        double prevIncome = _previousPeriodData['income'] ?? 0;
        if (totalIncome > prevIncome && prevIncome > 0) {
          double incomeGrowth = ((totalIncome - prevIncome) / prevIncome) * 100;
          newInsights.add({
            'type': 'success',
            'icon': Icons.trending_up,
            'title': 'Income Growth',
            'message': 'Your income has increased by ${incomeGrowth.toStringAsFixed(1)}% compared to the previous period.',
          });
        } else if (totalIncome < prevIncome && totalIncome > 0) {
          double incomeDecline = ((prevIncome - totalIncome) / prevIncome) * 100;
          newInsights.add({
            'type': 'warning',
            'icon': Icons.trending_down,
            'title': 'Income Decline',
            'message': 'Your income has decreased by ${incomeDecline.toStringAsFixed(1)}% compared to the previous period.',
          });
        }
        
        // Savings rate trend
        double prevSavingsRate = _previousPeriodData['savingsRate'] ?? 0;
        if (savingsRate > prevSavingsRate && prevSavingsRate > 0) {
          double savingsRateGrowth = savingsRate - prevSavingsRate;
          newInsights.add({
            'type': 'success',
            'icon': Icons.savings,
            'title': 'Improved Savings Rate',
            'message': 'Your savings rate has increased by ${savingsRateGrowth.toStringAsFixed(1)} percentage points compared to the previous period.',
          });
        }
      }
    }
    
    setState(() {
      insights = newInsights;
    });
  }

  // Helper: Group data by a key and sum the values.
  List<Map<String, dynamic>> _groupData(List<Map<String, dynamic>> data, String groupKey, String valueKey) {
    Map<String, double> grouped = {};
    for (var item in data) {
      String keyVal = item[groupKey] ?? 'Unknown';
      double value = (item[valueKey] as num).toDouble();
      grouped[keyVal] = (grouped[keyVal] ?? 0) + value;
    }
    return grouped.entries.map((e) => {'name': e.key, 'amount': e.value}).toList();
  }

  // Prepare chart data based on the selected report category.
  List<Map<String, dynamic>> getChartData() {
    if (_selectedReportCategory == 'All') {
      return [
        {'name': 'Income', 'amount': totalIncome, 'type': 'Income'},
        {'name': 'Expenses', 'amount': totalExpenses, 'type': 'Expense'},
        {'name': 'Savings', 'amount': totalSavings, 'type': 'Savings'},
        {'name': 'Debt', 'amount': totalDebt, 'type': 'Debt'},
      ];
    } else if (_selectedReportCategory == 'Income') {
      return _groupData(incomeList, 'category', 'amount');
    } else if (_selectedReportCategory == 'Expense') {
      return _groupData(expenseList, 'category', 'amount');
    } else if (_selectedReportCategory == 'Savings') {
      // Combine savings from goals and direct savings expenses
      List<Map<String, dynamic>> combinedSavings = [];
      
      // Add savings from goals
      List<Map<String, dynamic>> savingsGoals = goalList
          .where((g) => (g['type'] as String).toLowerCase() == 'savings')
          .toList();
      
      if (savingsGoals.isNotEmpty) {
        combinedSavings.addAll(_groupData(savingsGoals, 'name', 'progress'));
      }
      
      // Add direct savings expenses
      if (savingsExpenseList.isNotEmpty) {
        List<Map<String, dynamic>> savingsExpenses = _groupData(savingsExpenseList, 'payee', 'amount');
        for (var savings in savingsExpenses) {
          // Check if this payee already exists in combinedSavings
          int existingIndex = combinedSavings.indexWhere((item) => item['name'] == savings['name']);
          if (existingIndex >= 0) {
            // Add to existing entry
            combinedSavings[existingIndex]['amount'] = 
                (combinedSavings[existingIndex]['amount'] as double) + (savings['amount'] as double);
          } else {
            // Add as new entry
            combinedSavings.add(savings);
          }
        }
      }
      
      return combinedSavings;
    } else if (_selectedReportCategory == 'Debt') {
      // Combine debt from goals and direct debt expenses
      List<Map<String, dynamic>> combinedDebt = [];
      
      // Add debt from goals
      List<Map<String, dynamic>> debtGoals = goalList
          .where((g) => (g['type'] as String).toLowerCase() == 'debt')
          .toList();
      
      if (debtGoals.isNotEmpty) {
        combinedDebt.addAll(_groupData(debtGoals, 'name', 'progress'));
      }
      
      // Add direct debt expenses
      if (debtExpenseList.isNotEmpty) {
        List<Map<String, dynamic>> debtExpenses = _groupData(debtExpenseList, 'payee', 'amount');
        for (var debt in debtExpenses) {
          // Check if this payee already exists in combinedDebt
          int existingIndex = combinedDebt.indexWhere((item) => item['name'] == debt['name']);
          if (existingIndex >= 0) {
            // Add to existing entry
            combinedDebt[existingIndex]['amount'] = 
                (combinedDebt[existingIndex]['amount'] as double) + (debt['amount'] as double);
          } else {
            // Add as new entry
            combinedDebt.add(debt);
          }
        }
      }
      
      return combinedDebt;
    }
    return [];
  }

  // Return a color based on the label.
  Color _getColorForType(String label) {
    switch (label.toLowerCase()) {
      case 'income':
        return Colors.green.shade500;
      case 'expense':
        return Colors.orange.shade500;
      case 'savings':
        return Colors.blue.shade500;
      case 'debt':
        return Colors.red.shade500;
      default:
        // Generate a color based on the label string to ensure consistency
        final int hashCode = label.toLowerCase().hashCode;
        return Color((hashCode & 0xFFFFFF) | 0xFF000000);
    }
  }

  // Build the chart widget based on the selected chart type.
  Widget _buildChart() {
    List<Map<String, dynamic>> chartData = getChartData();
    if (chartData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text(
              'No data available for the selected filters',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    
    switch (chartType) {
      case 'Bar Chart':
        return BarChart(
          BarChartData(
            barGroups: chartData.asMap().entries.map((entry) {
              int index = entry.key;
              var data = entry.value;
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: (data['amount'] as double),
                    color: _getColorForType(_selectedReportCategory == 'All'
                        ? data['type']
                        : _selectedReportCategory),
                    width: 20,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ],
                showingTooltipIndicators: [0],
              );
            }).toList(),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    int index = value.toInt();
                    if (index < 0 || index >= chartData.length) return SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        chartData[index]['name'].toString().length > 8
                            ? '${chartData[index]['name'].toString().substring(0, 8)}...'
                            : chartData[index]['name'].toString(),
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        '£${value.toInt()}',
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1000,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.white.withOpacity(0.2),
                  strokeWidth: 1,
                );
              },
            ),
            borderData: FlBorderData(show: false),
            backgroundColor: Colors.transparent,
          ),
        );
      case 'Line Chart':
        return LineChart(
          LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: chartData.asMap().entries.map((entry) {
                  return FlSpot(entry.key.toDouble(), (entry.value['amount'] as double));
                }).toList(),
                isCurved: true,
                color: _getColorForType(_selectedReportCategory),
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 6,
                      color: Colors.white,
                      strokeWidth: 2,
                      strokeColor: barData.color ?? Colors.blue,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: _getColorForType(_selectedReportCategory).withOpacity(0.3),
                ),
              ),
            ],
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    int index = value.toInt();
                    if (index < 0 || index >= chartData.length) return SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        chartData[index]['name'].toString().length > 8
                            ? '${chartData[index]['name'].toString().substring(0, 8)}...'
                            : chartData[index]['name'].toString(),
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        '£${value.toInt()}',
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1000,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.white.withOpacity(0.2),
                  strokeWidth: 1,
                );
              },
            ),
            borderData: FlBorderData(show: false),
            backgroundColor: Colors.transparent,
          ),
        );
      default: // Pie Chart
        return PieChart(
          PieChartData(
            sections: chartData.map((data) {
              final amount = (data['amount'] as double);
              final color = _getColorForType(_selectedReportCategory == 'All'
                  ? data['type']
                  : _selectedReportCategory);
              return PieChartSectionData(
                value: amount,
                title: amount > 0 ? '£${amount.toStringAsFixed(0)}' : '',
                color: color,
                radius: 100,
                titleStyle: GoogleFonts.poppins(
                  fontSize: 14, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.white
                ),
              );
            }).toList(),
            centerSpaceRadius: 40,
            sectionsSpace: 2,
          ),
        );
    }
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
  
  
  // Replace the _buildSummaryCard method with this improved version
Widget _buildSummaryCard() {
  return FadeTransition(
    opacity: _summaryCardAnimation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, 0.2),
        end: Offset.zero,
      ).animate(_summaryCardAnimation),
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A237E), // Darker blue
              Color(0xFF3949AB), // Medium blue
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: Offset(0, 5),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and filter in separate container
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Financial Summary',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedReportCategory,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Financial data grid
            Padding(
              padding: EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive layout based on available width
                  bool isNarrow = constraints.maxWidth < 600;
                  
                  if (isNarrow) {
                    // Stack items vertically on narrow screens
                    return Column(
                      children: [
                        _buildSummaryRow(
                          first: _buildSummaryItem(
                            title: 'Income',
                            value: '£${totalIncome.toStringAsFixed(2)}',
                            icon: Icons.arrow_upward,
                            color: Colors.green,
                            comparisonValue: _showComparison ? _previousPeriodData['income'] : null,
                          ),
                          second: _buildSummaryItem(
                            title: 'Expenses',
                            value: '£${totalExpenses.toStringAsFixed(2)}',
                            icon: Icons.arrow_downward,
                            color: Colors.orange,
                            comparisonValue: _showComparison ? _previousPeriodData['expenses'] : null,
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildSummaryRow(
                          first: _buildSummaryItem(
                            title: 'Savings',
                            value: '£${totalSavings.toStringAsFixed(2)}',
                            icon: Icons.savings,
                            color: Colors.blue,
                            comparisonValue: _showComparison ? _previousPeriodData['savings'] : null,
                          ),
                          second: _buildSummaryItem(
                            title: 'Debt',
                            value: '£${totalDebt.toStringAsFixed(2)}',
                            icon: Icons.account_balance,
                            color: Colors.red,
                            comparisonValue: _showComparison ? _previousPeriodData['debt'] : null,
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildSummaryRow(
                          first: _buildSummaryItem(
                            title: 'Net Cashflow',
                            value: '£${netCashflow.toStringAsFixed(2)}',
                            icon: Icons.trending_up,
                            color: netCashflow >= 0 ? Colors.green : Colors.red,
                            comparisonValue: _showComparison ? _previousPeriodData['netCashflow'] : null,
                          ),
                          second: _buildSummaryItem(
                            title: 'Savings Rate',
                            value: '${savingsRate.toStringAsFixed(1)}%',
                            icon: Icons.pie_chart,
                            color: savingsRate >= 15 ? Colors.green : Colors.orange,
                            comparisonValue: _showComparison ? _previousPeriodData['savingsRate'] : null,
                            isPercentage: true,
                          ),
                        ),
                      ],
                    );
                  } else {
                    // Use a grid layout for wider screens
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryItem(
                                title: 'Income',
                                value: '£${totalIncome.toStringAsFixed(2)}',
                                icon: Icons.arrow_upward,
                                color: Colors.green,
                                comparisonValue: _showComparison ? _previousPeriodData['income'] : null,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildSummaryItem(
                                title: 'Expenses',
                                value: '£${totalExpenses.toStringAsFixed(2)}',
                                icon: Icons.arrow_downward,
                                color: Colors.orange,
                                comparisonValue: _showComparison ? _previousPeriodData['expenses'] : null,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildSummaryItem(
                                title: 'Savings',
                                value: '£${totalSavings.toStringAsFixed(2)}',
                                icon: Icons.savings,
                                color: Colors.blue,
                                comparisonValue: _showComparison ? _previousPeriodData['savings'] : null,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryItem(
                                title: 'Debt',
                                value: '£${totalDebt.toStringAsFixed(2)}',
                                icon: Icons.account_balance,
                                color: Colors.red,
                                comparisonValue: _showComparison ? _previousPeriodData['debt'] : null,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildSummaryItem(
                                title: 'Net Cashflow',
                                value: '£${netCashflow.toStringAsFixed(2)}',
                                icon: Icons.trending_up,
                                color: netCashflow >= 0 ? Colors.green : Colors.red,
                                comparisonValue: _showComparison ? _previousPeriodData['netCashflow'] : null,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildSummaryItem(
                                title: 'Savings Rate',
                                value: '${savingsRate.toStringAsFixed(1)}%',
                                icon: Icons.pie_chart,
                                color: savingsRate >= 15 ? Colors.green : Colors.orange,
                                comparisonValue: _showComparison ? _previousPeriodData['savingsRate'] : null,
                                isPercentage: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showCategoryFilterMenu(BuildContext context) {
  final RenderBox button = context.findRenderObject() as RenderBox;
  final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
    ),
    Offset.zero & overlay.size,
  );

  showMenu<String>(
    context: context,
    position: position,
    items: _reportCategories.map((String category) {
      return PopupMenuItem<String>(
        value: category,
        child: Text(category),
      );
    }).toList(),
  ).then((String? value) {
    if (value != null) {
      setState(() {
        _selectedReportCategory = value;
      });
      _computeInsights();
    }
  });
}

// Also update the _buildSummaryItem method to make it more compact
Widget _buildSummaryItem({
  required String title,
  required String value,
  required IconData icon,
  required Color color,
  double? comparisonValue,
  bool isPercentage = false,
}) {
  // Calculate comparison indicator if comparison value is provided
  Widget? comparisonIndicator;
  if (comparisonValue != null) {
    double currentValue = double.tryParse(value.replaceAll('£', '').replaceAll('%', '')) ?? 0;
    double difference = currentValue - comparisonValue;
    double percentChange = comparisonValue != 0 ? (difference / comparisonValue) * 100 : 0;
    
    // Determine if the change is positive or negative (and if that's good or bad)
    bool isPositiveGood = title != 'Expenses' && title != 'Debt';
    bool isPositiveChange = difference > 0;
    bool isGoodChange = isPositiveGood == isPositiveChange;
    
    if (difference.abs() > 0.01) { // Only show if there's a meaningful difference
      comparisonIndicator = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositiveChange ? Icons.arrow_upward : Icons.arrow_downward,
            color: isGoodChange ? Colors.green.shade300 : Colors.red.shade300,
            size: 10,
          ),
          SizedBox(width: 2),
          Text(
            isPercentage 
              ? '${difference.abs().toStringAsFixed(1)}%' 
              : '${percentChange.abs().toStringAsFixed(1)}%',
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: isGoodChange ? Colors.green.shade300 : Colors.red.shade300,
            ),
          ),
        ],
      );
    }
  }

  return Container(
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 12, color: color),
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.9),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (comparisonIndicator != null) comparisonIndicator,
          ],
        ),
      ],
    ),
  );
}

// Helper widget for narrow screens
Widget _buildSummaryRow({required Widget first, required Widget second}) {
  return Row(
    children: [
      Expanded(child: first),
      SizedBox(width: 16),
      Expanded(child: second),
    ],
  );
}

Widget _buildFilterCard() {
  return FadeTransition(
    opacity: _filterCardAnimation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, 0.2),
        end: Offset.zero,
      ).animate(_filterCardAnimation),
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.filter_list,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Filter Options',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive layout based on available width
                  bool isNarrow = constraints.maxWidth < 600;
                  
                  if (isNarrow) {
                    // Stack items vertically on narrow screens
                    return Column(
                      children: [
                        _buildFilterRow(
                          first: _buildFilterItem(
                            label: 'Month',
                            child: _buildMonthDropdown(),
                          ),
                          second: _buildFilterItem(
                            label: 'Category',
                            child: _buildReportCategoryDropdown(),
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildFilterRow(
                          first: _buildFilterItem(
                            label: 'Chart Type',
                            child: _chartTypeDropdown(),
                          ),
                          second: _buildFilterItem(
                            label: 'Compare',
                            child: _buildComparisonToggle(),
                          ),
                        ),
                        if (_showComparison) ...[
                          SizedBox(height: 16),
                          _buildFilterItem(
                            label: 'Compare With',
                            child: _buildComparisonMonthDropdown(),
                          ),
                        ],
                      ],
                    );
                  } else {
                    // Use a grid layout for wider screens
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildFilterItem(
                                label: 'Month',
                                child: _buildMonthDropdown(),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: _buildFilterItem(
                                label: 'Category',
                                child: _buildReportCategoryDropdown(),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: _buildFilterItem(
                                label: 'Chart Type',
                                child: _chartTypeDropdown(),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: _buildFilterItem(
                                label: 'Compare',
                                child: _buildComparisonToggle(),
                              ),
                            ),
                          ],
                        ),
                        if (_showComparison) ...[
                          SizedBox(height: 16),
                          _buildFilterItem(
                            label: 'Compare With',
                            child: _buildComparisonMonthDropdown(),
                          ),
                        ],
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Helper widget for narrow screens
Widget _buildFilterRow({required Widget first, required Widget second}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: first),
      SizedBox(width: 16),
      Expanded(child: second),
    ],
  );
}

Widget _buildFilterItem({
  required String label,
  required Widget child,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white.withOpacity(0.9),
        ),
      ),
      SizedBox(height: 8),
      child,
    ],
  );
}

Widget _buildChartContainer() {
  return FadeTransition(
    opacity: _chartAnimation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, 0.2),
        end: Offset.zero,
      ).animate(_chartAnimation),
      child: Container(
        height: 350,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Loading your financial data...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : _buildChart(),
      ),
    ),
  );
}

Widget _buildLegend() {
  List<Map<String, dynamic>> legendItems = [];
  List<Map<String, dynamic>> chartData = getChartData();
  
  if (chartData.isEmpty) return SizedBox();
  
  if (_selectedReportCategory == 'All') {
    legendItems = [
      {'label': 'Income', 'color': _getColorForType('Income')},
      {'label': 'Expenses', 'color': _getColorForType('Expense')},
      {'label': 'Savings', 'color': _getColorForType('Savings')},
      {'label': 'Debt', 'color': _getColorForType('Debt')},
    ];
  } else {
    // For other categories, create legend items from chart data
    for (var item in chartData) {
      if ((item['amount'] as double) > 0) {
        legendItems.add({
          'label': item['name'],
          'color': _getColorForType(item['name']),
        });
      }
    }
    
    // Limit legend items to prevent overflow
    if (legendItems.length > 6) {
      legendItems = legendItems.sublist(0, 6);
      legendItems.add({'label': 'Others', 'color': Colors.grey});
    }
  }
  
  return Container(
    margin: EdgeInsets.symmetric(vertical: 16),
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1,
      ),
    ),
    child: Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: legendItems.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16, 
              height: 16, 
              decoration: BoxDecoration(
                color: item['color'],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            SizedBox(width: 8),
            Text(
              item['label'], 
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        );
      }).toList(),
    ),
  );
}

Widget _buildInsightsSection() {
  if (insights.isEmpty) return SizedBox();
  
  return FadeTransition(
    opacity: _insightsAnimation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, 0.2),
        end: Offset.zero,
      ).animate(_insightsAnimation),
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: Offset(0, 5),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lightbulb,
                      color: Colors.amber,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Financial Insights',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ...insights.asMap().entries.map((entry) {
                int index = entry.key;
                var insight = entry.value;
                
                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 500 + (index * 100)),
                  curve: Curves.easeOutQuad,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: _buildInsightCard(insight),
                );
              }),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildInsightCard(Map<String, dynamic> insight) {
  Color cardColor;
  Color iconColor;
  
  if (insight['type'] == 'warning') {
    cardColor = Colors.orange.shade50;
    iconColor = Colors.orange.shade700;
  } else if (insight['type'] == 'success') {
    cardColor = Colors.green.shade50;
    iconColor = Colors.green.shade700;
  } else {
    cardColor = Colors.blue.shade50;
    iconColor = Colors.blue.shade700;
  }
  
  return Container(
    margin: EdgeInsets.only(bottom: 16),
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(insight['icon'], color: iconColor, size: 20),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                insight['title'],
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
              SizedBox(height: 4),
              Text(
                insight['message'],
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void _exportReportAsCSV() {
  try {
    setState(() {
      isRefreshing = true;
    });
    
    // Create CSV content
    String csvContent = 'Category,Amount\n';
    
    List<Map<String, dynamic>> data = getChartData();
    for (var item in data) {
      csvContent += '${item['name']},${item['amount']}\n';
    }
    
    // Show a success message with the CSV content
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'Report generated successfully',
              style: GoogleFonts.poppins(),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(10),
        duration: Duration(seconds: 2),
      ),
    );
    
    // Show the CSV content in a dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.data_array, color: Colors.blue.shade700),
            SizedBox(width: 10),
            Text(
              'Report Data',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Here is your report data:',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  csvContent,
                  style: GoogleFonts.robotoMono(fontSize: 12),
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can copy this data and paste it into a spreadsheet application.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvContent));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Data copied to clipboard'),
                  backgroundColor: Colors.blue.shade600,
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.all(10),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Copy to Clipboard', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    
    setState(() {
      isRefreshing = false;
    });
  } catch (e) {
    setState(() {
      isRefreshing = false;
    });
    
    _showErrorSnackBar('Error generating report: $e');
  }
}

void _showInfoDialog() {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700),
            SizedBox(width: 10),
            Text(
              'Reports & Insights',
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
                'This page provides visual reports and insights based on your financial data:',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 16),
              _buildInfoItem(
                icon: Icons.calendar_today,
                color: Colors.blue,
                text: 'Use the "Month" dropdown to filter data by month',
              ),
              _buildInfoItem(
                icon: Icons.category,
                color: Colors.green,
                text: 'Use the "Category" dropdown to view data for Income, Expense, Savings, or Debt',
              ),
              _buildInfoItem(
                icon: Icons.bar_chart,
                color: Colors.orange,
                text: 'Choose a chart type (Pie, Bar, Line) to visualize your data',
              ),
              _buildInfoItem(
                icon: Icons.compare_arrows,
                color: Colors.purple,
                text: 'Enable comparison to see how your finances have changed between periods',
              ),
              _buildInfoItem(
                icon: Icons.lightbulb,
                color: Colors.amber,
                text: 'When viewing all data, insights are provided based on your overall financial health',
              ),
              _buildInfoItem(
                icon: Icons.refresh,
                color: Colors.indigo,
                text: 'Pull down to refresh the data at any time',
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates, color: Colors.blue.shade700, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'For any further questions, please refer to our documentation or contact support.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
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
              foregroundColor: Colors.grey.shade700,
            ),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Got It', style: GoogleFonts.poppins()),
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

Widget _chartTypeDropdown() {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1,
      ),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: chartType,
        dropdownColor: Color(0xFF1E3A8A),
        icon: Icon(Icons.arrow_drop_down, color: Colors.white),
        isExpanded: true,
        items: _chartTypes.map((type) {
          return DropdownMenuItem<String>(
            value: type,
            child: Text(
              type, 
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() { chartType = value!; });
        },
      ),
    ),
  );
}

Widget _buildMonthDropdown() {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1,
      ),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedMonth,
        dropdownColor: Color(0xFF1E3A8A),
        icon: Icon(Icons.arrow_drop_down, color: Colors.white),
        isExpanded: true,
        items: _months.map((m) {
          return DropdownMenuItem<String>(
            value: m,
            child: Text(
              m, 
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() { _selectedMonth = value!; });
          _fetchAllData();
        },
      ),
    ),
  );
}

Widget _buildComparisonMonthDropdown() {
  // Filter out the currently selected month
  List<String> availableMonths = _months.where((m) => m != _selectedMonth).toList();
  
  // If the comparison month is the selected month, reset it
  if (_comparisonMonth == _selectedMonth) {
    _comparisonMonth = availableMonths.isNotEmpty ? availableMonths.first : '';
  }
  
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1,
      ),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _comparisonMonth,
        dropdownColor: Color(0xFF1E3A8A),
        icon: Icon(Icons.arrow_drop_down, color: Colors.white),
        isExpanded: true,
        items: availableMonths.map((m) {
          return DropdownMenuItem<String>(
            value: m,
            child: Text(
              m, 
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() { _comparisonMonth = value!; });
          _fetchAllData();
        },
      ),
    ),
  );
}

Widget _buildComparisonToggle() {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Show Comparison',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Switch(
          value: _showComparison,
          onChanged: (value) {
            setState(() { 
              _showComparison = value;
              if (value && _months.length > 1) {
                // Set default comparison month
                _comparisonMonth = _months.where((m) => m != _selectedMonth).first;
              }
            });
            _fetchAllData();
          },
          activeColor: Colors.blue.shade300,
          activeTrackColor: Colors.blue.shade800,
        ),
      ],
    ),
  );
}

Widget _buildReportCategoryDropdown() {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1,
      ),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedReportCategory,
        dropdownColor: Color(0xFF1E3A8A),
        icon: Icon(Icons.arrow_drop_down, color: Colors.white),
        isExpanded: true,
        items: _reportCategories.map((cat) {
          return DropdownMenuItem<String>(
            value: cat,
            child: Text(
              cat, 
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() { _selectedReportCategory = value!; });
          _computeInsights();
        },
      ),
    ),
  );
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      title: Text(
        'Reports',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      actions: [
        // Add export button
        IconButton(
          icon: Icon(Icons.share, color: Colors.white, size: 22),
          onPressed: _exportReportAsCSV,
          tooltip: 'Export Report',
        ),
        // Add refresh button
        IconButton(
          icon: Icon(Icons.refresh, color: Colors.white, size: 22),
          onPressed: _fetchAllData,
          tooltip: 'Refresh Data',
        ),
        IconButton(
          icon: Icon(Icons.info_outline, color: Colors.white, size: 22),
          onPressed: _showInfoDialog,
          tooltip: 'About Reports',
        ),
      ],
    ),
    body: Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0D47A1), // Darker blue
            Color(0xFF1976D2), // Medium blue
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          // Main content
          RefreshIndicator(
            color: Colors.white,
            backgroundColor: Colors.blue.shade700,
            onRefresh: _fetchAllData,
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Padding for AppBar
                  SizedBox(height: 60),
                  
                  // Summary card
                  _buildSummaryCard(),
                  
                  // Filter card
                  _buildFilterCard(),
                  
                  // Chart container
                  _buildChartContainer(),
                  
                  // Legend
                  _buildLegend(),
                  
                  // Insights section
                  _buildInsightsSection(),
                  
                  // Bottom padding for better scrolling experience
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
          
          // Loading overlay
          if (isRefreshing)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                          strokeWidth: 3,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Processing...',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
}