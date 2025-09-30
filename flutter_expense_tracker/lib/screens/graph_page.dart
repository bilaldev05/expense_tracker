import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class GraphPage extends StatefulWidget {
  const GraphPage({Key? key}) : super(key: key);

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  List<Map<String, dynamic>> _graphData = [];
  String _selectedFilter = "Monthly";

  @override
  void initState() {
    super.initState();
    _loadGraphData();
  }

  Future<void> _loadGraphData() async {
    try {
      final data = await ApiService().fetchGraphData();
      setState(() {
        _graphData = data;
      });
    } catch (e) {
      debugPrint('Error loading graph data: $e');
    }
  }

  List<FlSpot> _getSpots() {
    return _graphData.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final amount = (entry.value['amount'] ?? 0).toDouble();
      return FlSpot(index, amount);
    }).toList();
  }

  List<String> _getDateLabels() {
    return _graphData.map((e) {
      try {
        final parsedDate = DateTime.parse(e['date']);
        return DateFormat.Md().format(parsedDate);
      } catch (_) {
        return e['date'].toString();
      }
    }).toList();
  }

  double get _totalSpending =>
      _graphData.fold(0.0, (sum, e) => sum + (e['amount'] ?? 0));

  double get _averageSpending =>
      _graphData.isEmpty ? 0 : _totalSpending / _graphData.length;

  double get _maxSpending => _graphData.fold(
      0.0,
      (max, e) => e['amount'] != null && e['amount'] > max
          ? e['amount'].toDouble()
          : max);

  @override
  Widget build(BuildContext context) {
    final spots = _getSpots();
    final labels = _getDateLabels();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Spending Trends",
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 3,
      ),
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _graphData.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Summary Stats Row ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatCard(
                        title: "Total",
                        value: "\$${_totalSpending.toStringAsFixed(0)}",
                        color: Colors.blue,
                        icon: Icons.savings_outlined,
                      ),
                      _StatCard(
                        title: "Average",
                        value: "\$${_averageSpending.toStringAsFixed(1)}",
                        color: Colors.green,
                        icon: Icons.trending_up,
                      ),
                      _StatCard(
                        title: "Max",
                        value: "\$${_maxSpending.toStringAsFixed(0)}",
                        color: Colors.red,
                        icon: Icons.bar_chart_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- Chart Section with Header ---
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Header Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Spending Over Time',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              DropdownButton<String>(
                                value: _selectedFilter,
                                underline: const SizedBox(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: "Weekly", child: Text("Weekly")),
                                  DropdownMenuItem(
                                      value: "Monthly", child: Text("Monthly")),
                                  DropdownMenuItem(
                                      value: "Yearly", child: Text("Yearly")),
                                ],
                                onChanged: (val) {
                                  setState(() => _selectedFilter = val!);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Chart
                          AspectRatio(
                            aspectRatio: 1.5,
                            child: LineChart(
                              LineChartData(
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: _maxSpending / 5,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, _) => Text(
                                        value.toStringAsFixed(0),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 1,
                                      getTitlesWidget: (value, _) {
                                        int index = value.toInt();
                                        if (index >= 0 &&
                                            index < labels.length) {
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              labels[index],
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ),
                                  topTitles: AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: _maxSpending / 5,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: Colors.grey.withOpacity(0.15),
                                    strokeWidth: 1,
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    isCurved: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.shade400,
                                        Colors.blue.shade700,
                                      ],
                                    ),
                                    barWidth: 3,
                                    belowBarData: BarAreaData(
                                      show: true,
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.withOpacity(0.3),
                                          Colors.transparent,
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                    dotData: FlDotData(show: false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
