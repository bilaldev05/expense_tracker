import 'package:flutter/material.dart';

class SummaryPage extends StatelessWidget {
  final String summary;

  SummaryPage({required this.summary});

  @override
  Widget build(BuildContext context) {
    final List<String> points = summary
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 4,
        centerTitle: true,
        automaticallyImplyLeading: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.analytics, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              "Summary",
              style: TextStyle(
                color: Colors.white,
                letterSpacing: 1.2,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListView.builder(
            itemCount: points.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "• ",
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 18,
                        height: 1.5,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        points[index],
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
