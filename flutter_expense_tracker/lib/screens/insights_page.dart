import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class InsightsPage extends StatelessWidget {
  final Map<String, double> categoryTotals;

  InsightsPage({super.key, required this.categoryTotals});

  final List<Color> colors = [
    Colors.indigoAccent,
    Colors.teal,
    Colors.deepPurple,
    Colors.orangeAccent,
    Colors.pinkAccent,
    Colors.green,
    Colors.cyan,
    Colors.amber,
    Colors.redAccent,
  ];

  @override
  Widget build(BuildContext context) {
    final total = categoryTotals.values.fold(0.0, (sum, val) => sum + val);
    final entries = categoryTotals.entries.toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 3,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.insights_rounded, color: Colors.indigoAccent, size: 22),
            SizedBox(width: 8),
            Text(
              "Spending Insights",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: total == 0
          ? const Center(
              child: Text(
                "No expense data available yet",
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatCard(total),
                  const SizedBox(height: 24),
                  _buildPieChart(entries, total),
                  const SizedBox(height: 24),
                  _buildCategorySummary(entries, total),
                ],
              ),
            ),
    );
  }

  // 1️⃣ Total Spent Card
  Widget _buildStatCard(double total) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.blueAccent.withOpacity(0.08),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.blueAccent.withOpacity(0.15),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side — title and value
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.blueAccent,
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Total Spent",
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "Rs. ${total.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          // Right side — circular accent icon
          Container(
            height: 55,
            width: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.blueAccent.withOpacity(0.15),
                  Colors.white.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.blueAccent.withOpacity(0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Colors.blueAccent,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  // 2️⃣ Pie Chart Card
  Widget _buildPieChart(List<MapEntry<String, double>> entries, double total) {
    return _buildCard(
      title: "Spending Breakdown",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 60,
                borderData: FlBorderData(show: false),
                sections: entries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final amount = entry.value.value;
                  final percentage = (amount / total) * 100;

                  return PieChartSectionData(
                    color: colors[index % colors.length],
                    value: amount,
                    title: "${percentage.toStringAsFixed(1)}%",
                    radius: 90,
                    titleStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entries.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value.key;
              return _legendChip(category, colors[index % colors.length]);
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 3️⃣ Category Summary Card
  Widget _buildCategorySummary(
      List<MapEntry<String, double>> entries, double total) {
    return _buildCard(
      title: "Category Insights",
      child: Column(
        children: entries.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value.key;
          final amount = entry.value.value;
          final percentage = (amount / total) * 100;

          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: colors[index % colors.length],
                      child: const Icon(Icons.category,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      "Rs. ${amount.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigoAccent,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey.shade200,
                    color: colors[index % colors.length],
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // 🔹 Generic Card Builder
  Widget _buildCard({required Widget child, String? title}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          if (title != null) const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // 🔸 Legend Chip
  Widget _legendChip(String label, Color color) {
    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 6),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
