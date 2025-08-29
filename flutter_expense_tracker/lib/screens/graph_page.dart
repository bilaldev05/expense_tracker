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
      print('Error loading graph data: $e');
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
        return DateFormat.Md().format(parsedDate); // e.g., 7/1
      } catch (_) {
        return e['date'].toString();
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final spots = _getSpots();
    final labels = _getDateLabels();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.show_chart, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              "Graph to date",
              style: TextStyle(
                color: Colors.white,
                letterSpacing: 1.2,
                fontSize: 18,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _graphData.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Spending Over Time',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  AspectRatio(
                    aspectRatio: 1.5, // Reduces vertical overlap
                    child: LineChart(
                      LineChartData(
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 100, // Adjust for clarity
                              reservedSize: 40,
                              getTitlesWidget: (value, _) => Text(
                                value.toStringAsFixed(0),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue,
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
                                if (index >= 0 && index < labels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      labels[index],
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(show: true),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: Colors.blue,
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blue.withOpacity(0.2),
                            ),
                            dotData: FlDotData(show: true),
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
