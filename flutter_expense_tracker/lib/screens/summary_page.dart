import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  final ApiService apiService = ApiService();

  String _selectedMonth =
      "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";

  String? _summary;
  bool _loading = true;
  double _totalAmount = 0.0;
  Map<String, double> _categoryData = {};

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    setState(() => _loading = true);
    try {
      final Map<String, dynamic> data =
          await apiService.getMonthlySummary(_selectedMonth);

      final totalValue = data["total_amount"];
      if (totalValue is num) {
        _totalAmount = totalValue.toDouble();
      } else if (totalValue is String) {
        _totalAmount = double.tryParse(totalValue) ?? 0.0;
      } else {
        _totalAmount = 0.0;
      }

      if (data["by_category"] != null && data["by_category"] is Map) {
        final categoryMap = data["by_category"] as Map;
        _categoryData = categoryMap.map(
          (key, value) => MapEntry(
            key.toString(),
            (value is num)
                ? value.toDouble()
                : double.tryParse(value.toString()) ?? 0.0,
          ),
        );
      } else {
        _categoryData = {};
      }

      String rawSummary = data["summaryText"]?.toString() ?? "";
      rawSummary = rawSummary
          .replaceAll(RegExp(r'AI\s*Summary[:\-]*', caseSensitive: false), '')
          .replaceAll(
              RegExp(r'Total\s*Spending[:\-]*', caseSensitive: false), '')
          .trim();

      _summary = rawSummary.isNotEmpty
          ? rawSummary
          : "No AI insights available for this month.";
    } catch (e) {
      _summary = "Failed to load insights.";
      _categoryData = {};
      _totalAmount = 0.0;
    }

    setState(() => _loading = false);
  }

  Future<void> _pickMonth(BuildContext context) async {
    final now = DateTime.now();
    int selectedYear = int.parse(_selectedMonth.split('-')[0]);
    int selectedMonth = int.parse(_selectedMonth.split('-')[1]);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        int tempMonth = selectedMonth;
        int tempYear = selectedYear;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: 280,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    "Select Month",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigoAccent),
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DropdownButton<int>(
                          value: tempMonth,
                          items: List.generate(12, (index) {
                            final monthName = DateFormat.MMMM()
                                .format(DateTime(0, index + 1));
                            return DropdownMenuItem(
                              value: index + 1,
                              child: Text(monthName),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() => tempMonth = value);
                            }
                          },
                        ),
                        const SizedBox(width: 30),
                        DropdownButton<int>(
                          value: tempYear,
                          items: List.generate(5, (i) {
                            int year = now.year - 2 + i;
                            return DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() => tempYear = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final newMonth =
                          "$tempYear-${tempMonth.toString().padLeft(2, '0')}";
                      setState(() => _selectedMonth = newMonth);
                      await _fetchSummary();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigoAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Text("Confirm",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(
      DateTime(
        int.parse(_selectedMonth.split('-')[0]),
        int.parse(_selectedMonth.split('-')[1]),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1.5,
        centerTitle: true,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined,
                color: Colors.indigoAccent, size: 22),
            SizedBox(width: 8),
            Text(
              "Monthly Summary",
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Colors.black87),
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.indigoAccent,
                  strokeWidth: 3,
                ),
              )
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    _monthSelectorCard(monthName),
                    const SizedBox(height: 18),
                    _totalSpendingCard(),
                    const SizedBox(height: 24),
                    _aiSummarySection(),
                    const SizedBox(height: 28),
                    if (_categoryData.isNotEmpty) _buildPieChartSection(),
                  ],
                ),
              ),
      ),
    );
  }

  // --- Month Selector Card ---
  Widget _monthSelectorCard(String monthName) => Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.indigoAccent.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              monthName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3F51B5),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.calendar_month_outlined,
                  color: Colors.indigoAccent, size: 26),
              onPressed: () => _pickMonth(context),
            ),
          ],
        ),
      );

  // --- Total Spending Card ---
  Widget _totalSpendingCard() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.indigoAccent.withOpacity(0.12),
              Colors.indigo.shade50,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.indigoAccent.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigoAccent.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.indigoAccent, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Total Spending",
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.black87),
                ),
                const SizedBox(height: 6),
                Text(
                  "Rs. ${_totalAmount.toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.indigo),
                ),
              ],
            ),
          ],
        ),
      );

  // --- AI Summary Section ---
  Widget _aiSummarySection() {
    final lines =
        _summary?.split('\n').where((l) => l.trim().isNotEmpty).toList() ?? [];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.indigoAccent.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "AI Insights",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.indigoAccent,
            ),
          ),
          const SizedBox(height: 14),
          if (lines.isEmpty)
            const Text("No AI insights available for this month.",
                style: TextStyle(color: Colors.black54)),
          ...lines.map((line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.indigoAccent, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        line,
                        style: const TextStyle(
                            fontSize: 15.5,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // --- Pie Chart Section ---
  Widget _buildPieChartSection() {
    final total = _categoryData.values.fold(0.0, (a, b) => a + b);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigoAccent.withOpacity(0.05),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.indigoAccent.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "Spending by Category",
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.indigoAccent),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 230,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 50,
                borderData: FlBorderData(show: false),
                sections: _categoryData.entries.map((e) {
                  final color = Colors
                      .primaries[e.key.hashCode % Colors.primaries.length];
                  final percentage = total == 0 ? 0 : (e.value / total) * 100;
                  return PieChartSectionData(
                    value: e.value,
                    title: "${percentage.toStringAsFixed(1)}%",
                    radius: 70,
                    titleStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    color: color,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // --- Category Breakdown ---
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _categoryData.entries.map((e) {
              final color =
                  Colors.primaries[e.key.hashCode % Colors.primaries.length];
              final percentage = total == 0 ? 0 : (e.value / total) * 100;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.black87),
                      ),
                    ),
                    Text(
                      "Rs. ${e.value.toStringAsFixed(0)}  (${percentage.toStringAsFixed(1)}%)",
                      style: const TextStyle(
                          color: Colors.indigoAccent,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
