import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart'; // adjust path if needed

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

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    setState(() => _loading = true);
    try {
      final data = await apiService.getMonthlySummary(_selectedMonth);
      setState(() => _summary = data);
    } catch (e) {
      debugPrint("Error loading summary: $e");
      setState(() => _summary = "Failed to load insights");
    }
    setState(() => _loading = false);
  }

  Future<void> _pickMonth(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month),
      firstDate: DateTime(now.year - 2, 1),
      lastDate: DateTime(now.year + 1, 12),
      selectableDayPredicate: (date) => date.day == 1, // month-level selection
      helpText: 'Select Month',
    );

    if (picked != null) {
      final newMonth =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}";
      setState(() => _selectedMonth = newMonth);
      await _fetchSummary();
    }
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.analytics, color: Colors.blueAccent, size: 22),
            SizedBox(width: 8),
            Text(
              "Summary",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black12.withOpacity(0.08),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Month Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    monthName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3F51B5),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_month,
                        color: Colors.indigoAccent),
                    onPressed: () => _pickMonth(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_summary == null)
                const Expanded(
                  child: Center(child: Text("No summary available")),
                )
              else
                Expanded(
                  child: _buildSummaryList(_summary!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryList(String summary) {
    final points = summary
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return ListView.separated(
      itemCount: points.length,
      separatorBuilder: (_, __) => Divider(
        color: Colors.grey.shade200,
        height: 20,
        thickness: 1,
      ),
      itemBuilder: (context, index) {
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 400 + (index * 100)),
          tween: Tween<double>(begin: 0, end: 1),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 20),
                child: child,
              ),
            );
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigoAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: Colors.indigoAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  points[index],
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Colors.black87,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
