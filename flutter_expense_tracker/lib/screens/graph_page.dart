import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart'; // ✅ Only import your service

class GraphPage extends StatefulWidget {
  const GraphPage({Key? key}) : super(key: key);

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  List<Map<String, dynamic>> _graphData = [];
  List<String> _aiRecommendations = [];
  String _selectedFilter = "Monthly";

  @override
  void initState() {
    super.initState();
    _loadGraphData();
  }

  Future<void> _loadGraphData() async {
    try {
      final data = await ApiService().fetchGraphData();
      setState(() => _graphData = data);
      _loadAIRecommendations(); // ✅ Load AI after graph data
    } catch (e) {
      debugPrint('Error loading graph data: $e');
    }
  }

  Future<void> _loadAIRecommendations() async {
    try {
      // Prepare spending data to send to backend
      final totalAmount =
          _graphData.fold<double>(0, (sum, e) => sum + (e['amount'] ?? 0));
      final byCategory = <String, double>{};
      for (var e in _graphData) {
        final cat = e['category'] ?? 'Other';
        final amt = (e['amount'] ?? 0).toDouble();
        byCategory[cat] = (byCategory[cat] ?? 0) + amt;
      }
      final month =
          _graphData.isNotEmpty ? _graphData.last['date'].substring(0, 7) : '';

      final spending = {
        "month": month,
        "total_amount": totalAmount,
        "by_category": byCategory,
      };

      final data = await ApiService().fetchAIRecommendations(spending);
      setState(() => _aiRecommendations = data);
    } catch (e) {
      debugPrint('Error loading AI recommendations: $e');
      _aiRecommendations = [
        "Try reducing your daily coffee expenses.",
        "Consider setting a budget for groceries.",
        "Track recurring subscriptions to avoid overspending."
      ];
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 3,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.show_chart_rounded, color: Colors.blueAccent, size: 22),
            SizedBox(width: 8),
            Text(
              "Spending Trends",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _graphData.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 🌟 Stats Overview Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatCard(
                          title: "Total Spent",
                          value: "Rs. ${_totalSpending.toStringAsFixed(0)}",
                          color: Colors.blueAccent,
                          icon: Icons.account_balance_wallet_rounded,
                        ),
                        _StatCard(
                          title: "Average",
                          value: "Rs. ${_averageSpending.toStringAsFixed(1)}",
                          color: Colors.teal,
                          icon: Icons.trending_up_rounded,
                        ),
                        _StatCard(
                          title: "Max",
                          value: "Rs. ${_maxSpending.toStringAsFixed(0)}",
                          color: Colors.deepOrange,
                          icon: Icons.bar_chart_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 📈 Graph Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Spending Over Time",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedFilter,
                                    dropdownColor: Colors.white,
                                    icon: const Icon(Icons.keyboard_arrow_down,
                                        color: Colors.blueAccent),
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 13,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: "Weekly",
                                          child: Text("Weekly")),
                                      DropdownMenuItem(
                                          value: "Monthly",
                                          child: Text("Monthly")),
                                      DropdownMenuItem(
                                          value: "Yearly",
                                          child: Text("Yearly")),
                                    ],
                                    onChanged: (val) =>
                                        setState(() => _selectedFilter = val!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Chart
                          AspectRatio(
                            aspectRatio: 1.5,
                            child: LineChart(
                              LineChartData(
                                minY: 0,
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
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      interval: _maxSpending / 5,
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
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    isCurved: true,
                                    barWidth: 3,
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blueAccent.shade400,
                                        Colors.indigo.shade700,
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blueAccent.withOpacity(0.25),
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

                    const SizedBox(height: 24),

                    // ✅ AI Recommendations Section
                    _buildAIRecommendations(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAIRecommendations() {
    if (_aiRecommendations.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "AI Recommendations",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.indigoAccent,
            ),
          ),
          const SizedBox(height: 12),
          ..._aiRecommendations.map((rec) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: Colors.indigoAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rec,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

// ✅ Stat Card Widget
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11.5,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
