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
      selectableDayPredicate: (date) => date.day == 1,
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
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.analytics_rounded, color: Colors.indigoAccent, size: 22),
            SizedBox(width: 8),
            Text(
              "Summary",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.black87,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blueAccent.withOpacity(0.08),
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.1),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Month Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    monthName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF3F51B5),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_month_outlined,
                        color: Colors.indigoAccent),
                    onPressed: () => _pickMonth(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 1,
                color: Colors.grey.withOpacity(0.15),
              ),
              const SizedBox(height: 20),

              // 🔹 Content Area
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.indigoAccent,
                          strokeWidth: 3,
                        ),
                      )
                    : _summary == null
                        ? const Center(
                            child: Text(
                              "No summary available",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.black54,
                              ),
                            ),
                          )
                        : _buildSummaryList(_summary!),
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
        color: Colors.grey.shade300.withOpacity(0.4),
        height: 22,
        thickness: 0.8,
      ),
      itemBuilder: (context, index) {
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 400 + (index * 80)),
          tween: Tween<double>(begin: 0, end: 1),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 15),
                child: child,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Bubble
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.indigoAccent.withOpacity(0.9),
                        Colors.blueAccent.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigoAccent.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    points[index],
                    style: const TextStyle(
                      fontSize: 15.5,
                      height: 1.6,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
