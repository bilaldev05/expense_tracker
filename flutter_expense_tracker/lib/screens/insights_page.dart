import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class InsightsPage extends StatelessWidget {
  final Map<String, double> categoryTotals;

  InsightsPage({required this.categoryTotals});

  final List<Color> colors = [
    Colors.redAccent,
    Colors.amberAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.purpleAccent,
    Colors.orangeAccent,
    Colors.cyanAccent,
    Colors.pinkAccent,
    Colors.indigoAccent,
  ];

  @override
  Widget build(BuildContext context) {
    final total = categoryTotals.values.fold(0.0, (sum, val) => sum + val);
    final entries = categoryTotals.entries.toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.pie_chart, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              "Insights",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: total == 0
            ? const Center(
                child: Text(
                  "No expense data available",
                  style: TextStyle(color: Colors.black54, fontSize: 16),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Category-wise Breakdown",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: entries.asMap().entries.map((entry) {
                          final index = entry.key;
                          final category = entry.value.key;
                          final amount = entry.value.value;
                          final percentage =
                              total == 0 ? 0 : (amount / total) * 100;

                          return PieChartSectionData(
                            color: colors[index % colors.length],
                            value: amount,
                            title:
                                "$category\n${percentage.toStringAsFixed(1)}%",
                            radius: 80,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Summary by Category",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entries.asMap().entries.map((entry) {
                      final index = entry.key;
                      final category = entry.value.key;
                      final amount = entry.value.value;
                      return Chip(
                        backgroundColor: Colors.blue.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        avatar: CircleAvatar(
                          backgroundColor: colors[index % colors.length],
                          radius: 8,
                        ),
                        label: Text(
                          "$category: Rs.${amount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
      ),
    );
  }
}
