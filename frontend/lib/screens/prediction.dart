import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/api_service_wrapper.dart';

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  PredictionPageState createState() => PredictionPageState();
}

class PredictionPageState extends State<PredictionPage> with TickerProviderStateMixin {
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  final ApiServiceWrapper _apiService = ApiServiceWrapper();

  // Prediction data from backend.
  Map<String, double> predictions = {}; // keys: expense, income, savings, debt
  Map<String, double> expenseCategoryPredictions = {};

  // Dropdown selections for chart
  String _selectedPredictionCategory = 'All';
  final List<String> _predictionCategories = ['All', 'Expense', 'Income', 'Savings', 'Debt'];

  String chartType = 'Pie Chart';
  final List<String> _chartTypes = ['Pie Chart', 'Bar Chart', 'Line Chart', 'Histogram'];

  // Insights list
  List<Map<String, dynamic>> insights = [];
  
  bool isLoading = true;
  bool isRefreshing = false;
  bool hasError = false;
  String errorMessage = '';

  // Chat state
  List<Map<String, String>> chatMessages = []; // each: {'sender': 'User'/'AI', 'message': '...'}
  final TextEditingController _chatController = TextEditingController();
  bool isChatLoading = false;
  final ScrollController _chatScrollController = ScrollController();

  // Animation controllers
  late AnimationController _summaryCardAnimationController;
  late AnimationController _filterCardAnimationController;
  late AnimationController _chartAnimationController;
  late AnimationController _insightsAnimationController;
  late AnimationController _chatAnimationController;
  
  // Animations
  late Animation<double> _summaryCardAnimation;
  late Animation<double> _filterCardAnimation;
  late Animation<double> _chartAnimation;
  late Animation<double> _insightsAnimation;
  late Animation<double> _chatAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _fetchPrediction();
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

    // Chat animation
    _chatAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _chatAnimation = CurvedAnimation(
      parent: _chatAnimationController,
      curve: Curves.easeOutQuad,
    );

    // Start animations sequentially
    _summaryCardAnimationController.forward().then((_) {
      _filterCardAnimationController.forward().then((_) {
        _chartAnimationController.forward().then((_) {
          _insightsAnimationController.forward().then((_) {
            _chatAnimationController.forward();
          });
        });
      });
    });
  }
  
  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    _summaryCardAnimationController.dispose();
    _filterCardAnimationController.dispose();
    _chartAnimationController.dispose();
    _insightsAnimationController.dispose();
    _chatAnimationController.dispose();
    super.dispose();
  }

  
  /// Helper method to safely convert any numeric value to double
  double _safeToDouble(dynamic value) {
    if (value == null) {
      return 0.0;
    } else if (value is double) {
      return value;
    } else if (value is int) {
      return value.toDouble();
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

// Replace the entire _fetchPrediction method with this updated version
  Future<void> _fetchPrediction() async {
    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
      predictions = {};
      expenseCategoryPredictions = {};
      insights = [];
    });
    
    try {
      // Call the prediction endpoint using ApiServiceWrapper
      final response = await _apiService.getPrediction();
      
      if (response != null) {
        // Expecting: { message: 'Prediction successful', predictions: { expense: ..., income: ..., savings: ..., debt: ... }, expenseCategoryPredictions: { ... } }
        if (response['message'] != 'Prediction successful') {
          setState(() {
            isLoading = false;
            hasError = true;
            errorMessage = response['message'];
          });
          _showErrorSnackBar(response['message']);
          return;
        }
        
        // Safely convert prediction values to doubles
        Map<String, double> safelyConvertedPredictions = {};
        if (response['predictions'] != null) {
          final predictionData = response['predictions'] as Map<String, dynamic>;
          predictionData.forEach((key, value) {
            safelyConvertedPredictions[key] = _safeToDouble(value);
          });
        }
        
        // Safely convert expense category predictions to doubles
        Map<String, double> safelyConvertedCategoryPredictions = {};
        if (response['expenseCategoryPredictions'] != null) {
          final categoryData = response['expenseCategoryPredictions'] as Map<String, dynamic>;
          categoryData.forEach((key, value) {
            safelyConvertedCategoryPredictions[key] = _safeToDouble(value);
          });
        }
        
        setState(() {
          predictions = safelyConvertedPredictions;
          expenseCategoryPredictions = safelyConvertedCategoryPredictions;
        });
        
        _computeInsights();
      } else {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = 'Failed to fetch prediction data';
        });
        _showErrorSnackBar('Failed to fetch prediction data');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Error fetching prediction: $e';
      });
      _showErrorSnackBar('Error fetching prediction: $e');
    } finally {
      setState(() { 
        isLoading = false; 
      });
    }
  }

  /// Compute insights based on predictions
  void _computeInsights() {
    List<Map<String, dynamic>> newInsights = [];
    
    // Check expense predictions
    if (predictions.containsKey('expense')) {
      double predictedExpense = predictions['expense']!;
      
      if (predictedExpense > 1000) {
        newInsights.add({
          'type': 'warning',
          'icon': Icons.warning_amber_rounded,
          'title': 'High Expense Prediction',
          'message': 'Your predicted expenses for next month are £${predictedExpense.toStringAsFixed(2)}, which is quite high. Consider reviewing your budget.',
        });
      }
      
      // Check if expenses are predicted to exceed income
      if (predictions.containsKey('income') && predictedExpense > predictions['income']!) {
        newInsights.add({
          'type': 'warning',
          'icon': Icons.trending_down,
          'title': 'Negative Cash Flow Predicted',
          'message': 'Your predicted expenses exceed your predicted income for next month. Consider adjusting your spending plan.',
        });
      }
    }
    
    // Check savings predictions
    if (predictions.containsKey('savings') && predictions.containsKey('income')) {
      double predictedSavings = predictions['savings']!;
      double predictedIncome = predictions['income']!;
      
      double savingsRate = predictedIncome > 0 ? (predictedSavings / predictedIncome) * 100 : 0;
      
      if (savingsRate < 10) {
        newInsights.add({
          'type': 'info',
          'icon': Icons.savings_outlined,
          'title': 'Low Savings Prediction',
          'message': 'Your predicted savings rate is ${savingsRate.toStringAsFixed(1)}%. Financial experts recommend saving at least 15-20% of your income.',
        });
      } else if (savingsRate >= 20) {
        newInsights.add({
          'type': 'success',
          'icon': Icons.savings,
          'title': 'Excellent Savings Prediction',
          'message': 'Your predicted savings rate is ${savingsRate.toStringAsFixed(1)}%. You\'re on track for long-term financial security!',
        });
      }
    }
    
    // Check expense categories
    if (expenseCategoryPredictions.isNotEmpty) {
      // Find the highest expense category
      String highestCategory = '';
      double highestAmount = 0;
      
      expenseCategoryPredictions.forEach((category, amount) {
        if (amount > highestAmount) {
          highestAmount = amount;
          highestCategory = category;
        }
      });
      
      if (highestCategory.isNotEmpty) {
        newInsights.add({
          'type': 'info',
          'icon': Icons.category,
          'title': 'Highest Expense Category',
          'message': 'Your highest predicted expense category is "$highestCategory" at £${highestAmount.toStringAsFixed(2)}.',
        });
      }
    }
    
    setState(() {
      insights = newInsights;
    });
  }

  /// Prepare chart data based on the selected prediction category.
  List<Map<String, dynamic>> getChartData() {
    if (_selectedPredictionCategory == 'All') {
      // Show all predictions.
      return [
        {'name': 'Expense', 'amount': predictions['expense'] ?? 0, 'type': 'Expense'},
        {'name': 'Income', 'amount': predictions['income'] ?? 0, 'type': 'Income'},
        {'name': 'Savings', 'amount': predictions['savings'] ?? 0, 'type': 'Savings'},
        {'name': 'Debt', 'amount': predictions['debt'] ?? 0, 'type': 'Debt'},
      ];
    } else if (_selectedPredictionCategory == 'Expense') {
      // Use the expense category breakdown.
      return expenseCategoryPredictions.entries.map((entry) {
        return {'name': entry.key, 'amount': entry.value, 'type': 'Expense'};
      }).toList();
    } else {
      // For Income, Savings, or Debt, we only have one predicted value.
      return [
        {
          'name': _selectedPredictionCategory,
          'amount': predictions[_selectedPredictionCategory.toLowerCase()] ?? 0,
          'type': _selectedPredictionCategory
        }
      ];
    }
  }

  // Return a color for each type.
  Color _getColorForType(String label) {
    switch (label.toLowerCase()) {
      case 'expense':
        return Colors.orange.shade500;
      case 'income':
        return Colors.green.shade500;
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
              'No prediction data available',
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
                    color: _getColorForType(_selectedPredictionCategory == 'All'
                        ? data['type']
                        : _selectedPredictionCategory),
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
                        chartData[index]['name'].toString().length > 10
                            ? '${chartData[index]['name'].toString().substring(0, 10)}...'
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
                color: _getColorForType(_selectedPredictionCategory),
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
                  color: _getColorForType(_selectedPredictionCategory).withOpacity(0.3),
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
                        chartData[index]['name'].toString().length > 10
                            ? '${chartData[index]['name'].toString().substring(0, 10)}...'
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
      case 'Histogram':
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
                    color: _getColorForType(_selectedPredictionCategory == 'All'
                        ? data['type']
                        : _selectedPredictionCategory),
                    width: 30,
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
                        chartData[index]['name'].toString().length > 10
                            ? '${chartData[index]['name'].toString().substring(0, 10)}...'
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
              final color = _getColorForType(_selectedPredictionCategory == 'All'
                  ? data['type']
                  : _selectedPredictionCategory);
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
                badgeWidget: amount > 0 ? _Badge(
                  data['name'].toString(),
                  size: 40,
                  borderColor: color,
                ) : null,
                badgePositionPercentageOffset: 1.1,
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
  
  Widget _buildPredictionSummaryCard() {
    // Get next month name for display
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1);
    final nextMonthName = DateFormat('MMMM yyyy').format(nextMonth);
    
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
                Colors.purple.shade900,
                Colors.purple.shade700,
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
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_graph,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          ' $nextMonthName',
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
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.auto_graph, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'AI Forecast',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Responsive layout based on available width
                    bool isNarrow = constraints.maxWidth < 600;
                    
                    if (isNarrow) {
                      // Stack items vertically on narrow screens
                      return Column(
                        children: [
                          _buildSummaryRow(
                            first: _buildPredictionItem(
                              title: 'Income',
                              value: '£${(predictions['income'] ?? 0).toStringAsFixed(2)}',
                              icon: Icons.arrow_upward,
                              color: Colors.green,
                            ),
                            second: _buildPredictionItem(
                              title: 'Expenses',
                              value: (predictions['expense'] ?? 0) >= 0 
                                ? '£${(predictions['expense'] ?? 0).toStringAsFixed(2)}' 
                                : '-£${(predictions['expense'] ?? 0).abs().toStringAsFixed(2)}',
                              icon: Icons.arrow_downward,
                              color: Colors.orange,
                            ),
                          ),
                          SizedBox(height: 16),
                          _buildSummaryRow(
                            first: _buildPredictionItem(
                              title: 'Savings',
                              value: '£${(predictions['savings'] ?? 0).toStringAsFixed(2)}',
                              icon: Icons.savings,
                              color: Colors.blue,
                            ),
                            second: _buildPredictionItem(
                              title: 'Debt',
                              value: '£${(predictions['debt'] ?? 0).toStringAsFixed(2)}',
                              icon: Icons.account_balance,
                              color: Colors.red,
                            ),
                          ),
                          if (predictions.containsKey('income') && predictions.containsKey('expense')) ...[
                            SizedBox(height: 16),
                            _buildSummaryRow(
                              first: _buildPredictionItem(
                                title: 'Net Cashflow',
                                value: '£${((predictions['income'] ?? 0) - (predictions['expense'] ?? 0)).toStringAsFixed(2)}',
                                icon: Icons.trending_up,
                                color: (predictions['income'] ?? 0) >= (predictions['expense'] ?? 0) ? Colors.green : Colors.red,
                              ),
                              second: _buildPredictionItem(
                                title: 'Savings Rate',
                                value: '${(predictions['income'] ?? 0) > 0 ? (((predictions['savings'] ?? 0) / (predictions['income'] ?? 1)) * 100).toStringAsFixed(1) : '0.0'}%',
                                icon: Icons.pie_chart,
                                color: (predictions['income'] ?? 0) > 0 && ((predictions['savings'] ?? 0) / (predictions['income'] ?? 1)) >= 0.15 ? Colors.green : Colors.orange,
                              ),
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
                                child: _buildPredictionItem(
                                  title: 'Income',
                                  value: '£${(predictions['income'] ?? 0).toStringAsFixed(2)}',
                                  icon: Icons.arrow_upward,
                                  color: Colors.green,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _buildPredictionItem(
                                  title: 'Expenses',
                                  value: (predictions['expense'] ?? 0) >= 0 
                                    ? '£${(predictions['expense'] ?? 0).toStringAsFixed(2)}' 
                                    : '-£${(predictions['expense'] ?? 0).abs().toStringAsFixed(2)}',
                                  icon: Icons.arrow_downward,
                                  color: Colors.orange,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _buildPredictionItem(
                                  title: 'Savings',
                                  value: '£${(predictions['savings'] ?? 0).toStringAsFixed(2)}',
                                  icon: Icons.savings,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPredictionItem(
                                  title: 'Debt',
                                  value: '£${(predictions['debt'] ?? 0).toStringAsFixed(2)}',
                                  icon: Icons.account_balance,
                                  color: Colors.red,
                                ),
                              ),
                              if (predictions.containsKey('income') && predictions.containsKey('expense')) ...[
                                SizedBox(width: 16),
                                Expanded(
                                  child: _buildPredictionItem(
                                    title: 'Net Cashflow',
                                    value: '£${((predictions['income'] ?? 0) - (predictions['expense'] ?? 0)).toStringAsFixed(2)}',
                                    icon: Icons.trending_up,
                                    color: (predictions['income'] ?? 0) >= (predictions['expense'] ?? 0) ? Colors.green : Colors.red,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: _buildPredictionItem(
                                    title: 'Savings Rate',
                                    value: '${(predictions['income'] ?? 0) > 0 ? (((predictions['savings'] ?? 0) / (predictions['income'] ?? 1)) * 100).toStringAsFixed(1) : '0.0'}%',
                                    icon: Icons.pie_chart,
                                    color: (predictions['income'] ?? 0) > 0 && ((predictions['savings'] ?? 0) / (predictions['income'] ?? 1)) >= 0.15 ? Colors.green : Colors.orange,
                                  ),
                                ),
                              ] else ...[
                                SizedBox(width: 16),
                                Expanded(child: SizedBox()),
                                SizedBox(width: 16),
                                Expanded(child: SizedBox()),
                              ],
                            ],
                          ),
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
  Widget _buildSummaryRow({required Widget first, required Widget second}) {
    return Row(
      children: [
        Expanded(child: first),
        SizedBox(width: 16),
        Expanded(child: second),
      ],
    );
  }
  
  Widget _buildPredictionItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
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
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
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
                      'Chart Options',
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
                              label: 'Category',
                              child: _buildPredictionCategoryDropdown(),
                            ),
                            second: _buildFilterItem(
                              label: 'Chart Type',
                              child: _chartTypeDropdown(),
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Use a grid layout for wider screens
                      return Row(
                        children: [
                          Expanded(
                            child: _buildFilterItem(
                              label: 'Category',
                              child: _buildPredictionCategoryDropdown(),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildFilterItem(
                              label: 'Chart Type',
                              child: _chartTypeDropdown(),
                            ),
                          ),
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

  // Dropdown for chart type.
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
          dropdownColor: Colors.purple.shade800,
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

  // Dropdown for prediction category.
  Widget _buildPredictionCategoryDropdown() {
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
          value: _selectedPredictionCategory,
          dropdownColor: Colors.purple.shade800,
          icon: Icon(Icons.arrow_drop_down, color: Colors.white),
          isExpanded: true,
          items: _predictionCategories.map((cat) {
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
            setState(() { _selectedPredictionCategory = value!; });
          },
        ),
      ),
    );
  }

  // Build a legend for the chart.
  Widget _buildLegend() {
    List<Map<String, dynamic>> legendItems = [];
    List<Map<String, dynamic>> chartData = getChartData();
    
    if (chartData.isEmpty) return SizedBox();
    
    if (_selectedPredictionCategory == 'All') {
      legendItems = [
        {'label': 'Income', 'color': _getColorForType('Income')},
        {'label': 'Expenses', 'color': _getColorForType('Expense')},
        {'label': 'Savings', 'color': _getColorForType('Savings')},
        {'label': 'Debt', 'color': _getColorForType('Debt')},
      ];
    } else if (_selectedPredictionCategory == 'Expense' && expenseCategoryPredictions.isNotEmpty) {
      // For expense categories, create legend items from chart data
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
    } else {
      legendItems = [
        {'label': _selectedPredictionCategory, 'color': _getColorForType(_selectedPredictionCategory)},
      ];
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
                      'Prediction Insights',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade800,
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

  // Chat: send a message to the AI endpoint.
  Future<void> _sendChatMessage(String userMessage) async {
    if (userMessage.trim().isEmpty) return;
    
    setState(() {
      chatMessages.add({'sender': 'User', 'message': userMessage});
      isChatLoading = true;
      _chatController.clear();
    });
    
    // Scroll to bottom of chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    
    try {
      // Use ApiServiceWrapper to send chat message
      final response = await _apiService.sendChatMessage(userMessage);
      
      if (response != null) {
        setState(() {
          chatMessages.add({'sender': 'AI', 'message': response['reply']});
        });
        
        // Scroll to bottom of chat after AI response
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_chatScrollController.hasClients) {
            _chatScrollController.animateTo(
              _chatScrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        _showErrorSnackBar('Chat error: Failed to get response');
      }
    } catch (e) {
      _showErrorSnackBar('Error sending chat: $e');
    } finally {
      setState(() { isChatLoading = false; });
    }
  }

  // Build the chat widget.
  Widget _buildChatSection() {
    return FadeTransition(
      opacity: _chatAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, 0.2),
          end: Offset.zero,
        ).animate(_chatAnimation),
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
                        color: Colors.purple.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chat,
                        color: Colors.purple.shade700,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Financial Assistant',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: chatMessages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Ask me anything about your finances!',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Example: "How can I improve my savings?"',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _chatScrollController,
                          padding: EdgeInsets.all(16),
                          itemCount: chatMessages.length,
                          itemBuilder: (context, index) {
                            final msg = chatMessages[index];
                            final isUser = msg['sender'] == 'User';
                            return Align(
                              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                                ),
                                margin: EdgeInsets.only(
                                  top: 8,
                                  bottom: 8,
                                  left: isUser ? 50 : 0,
                                  right: isUser ? 0 : 50,
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isUser ? Colors.purple.shade100 : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isUser ? Colors.purple.shade200 : Colors.grey.shade300,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 5,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isUser ? Icons.person : Icons.smart_toy,
                                          size: 16,
                                          color: isUser ? Colors.purple.shade700 : Colors.blue.shade700,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          isUser ? 'You' : 'Financial AI',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isUser ? Colors.purple.shade700 : Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      msg['message']!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        style: GoogleFonts.poppins(color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Ask about your financial predictions...',
                          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          suffixIcon: isChatLoading
                              ? Container(
                                  margin: EdgeInsets.all(8),
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade700),
                                  ),
                                )
                              : IconButton(
                                  icon: Icon(Icons.send_rounded, color: Colors.purple.shade700),
                                  onPressed: () => _sendChatMessage(_chatController.text),
                                ),
                        ),
                        onSubmitted: _sendChatMessage,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Info dialog.
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.purple.shade700),
              SizedBox(width: 10),
              Text(
                'About Predictions',
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
                  'This page provides AI-powered predictions for your finances next month:',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 16),
                _buildInfoItem(
                  icon: Icons.auto_graph,
                  color: Colors.purple,
                  text: 'View predictions for income, expenses, savings, and debt',
                ),
                _buildInfoItem(
                  icon: Icons.category,
                  color: Colors.blue,
                  text: 'See detailed expense category predictions',
                ),
                _buildInfoItem(
                  icon: Icons.bar_chart,
                  color: Colors.orange,
                  text: 'Choose different chart types to visualize predictions',
                ),
                _buildInfoItem(
                  icon: Icons.lightbulb,
                  color: Colors.amber,
                  text: 'Get personalized insights based on your financial data',
                ),
                _buildInfoItem(
                  icon: Icons.chat,
                  color: Colors.green,
                  text: 'Chat with our AI assistant for financial advice',
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tips_and_updates, color: Colors.purple.shade700, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Note: Predictions are based on your historical financial data and may not be 100% accurate. Always use your judgment when making financial decisions.',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.purple.shade800,
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
                foregroundColor: Colors.purple.shade700,
              ),
              child: Text(
                'Got It',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
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
                      'Loading your prediction data...',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
            'Prediction',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        actions: [
          // Add refresh button
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchPrediction,
            tooltip: 'Refresh Predictions',
          ),
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showInfoDialog,
            tooltip: 'About Predictions',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF4A148C), // Dark purple
              Color(0xFF7B1FA2), // Medium purple
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
              backgroundColor: Colors.purple.shade700,
              onRefresh: _fetchPrediction,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Padding for AppBar
                    SizedBox(height: 60),
                    
                    // Prediction summary card
                    _buildPredictionSummaryCard(),
                    
                    // Filter card
                    _buildFilterCard(),
                    
                    // Chart container
                    _buildChartContainer(),
                    
                    // Legend
                    _buildLegend(),
                    
                    // Insights section
                    _buildInsightsSection(),
                    
                    // Chat section
                    _buildChatSection(),
                    
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade700),
                            strokeWidth: 3,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Updating predictions...',
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

// Custom badge widget for pie chart labels
class _Badge extends StatelessWidget {
  final String text;
  final double size;
  final Color borderColor;

  const _Badge(
    this.text, {
    required this.size,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      height: size,
      width: size,
      alignment: Alignment.center,
      child: Text(
        text.length > 3 ? text.substring(0, 3) : text,
        style: GoogleFonts.poppins(
          color: borderColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
