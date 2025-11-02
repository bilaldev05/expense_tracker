import 'dart:convert';

import 'package:http/http.dart' as http;
import '../models/expense.dart';

class ApiService {
  final String baseUrl = "http://localhost:8000";

  Future<Map<String, dynamic>> getInsights() async {
    final response = await http.get(Uri.parse('$baseUrl/insights'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load insights');
    }
  }

  Future<List<Expense>> fetchExpenses() async {
    final response = await http.get(Uri.parse('$baseUrl/expenses'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Expense.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load expenses');
    }
  }

  Future<void> addExpense(Expense expense) async {
    await http.post(
      Uri.parse('$baseUrl/expenses'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(expense.toJson()),
    );
  }

  Future<void> updateExpense(int id, Map<String, dynamic> expense) async {
    final response = await http.put(
      Uri.parse('$baseUrl/expenses/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(expense),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to update expense");
    }
  }

  Future<List<Map<String, dynamic>>> fetchGraphData() async {
    final response = await http.get(Uri.parse('$baseUrl/graph-data'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      // Defensive check for 'graph_data'
      if (data.containsKey('graph_data') && data['graph_data'] != null) {
        final List<dynamic> graphList = data['graph_data'];
        return graphList
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        throw Exception("Missing or null 'graph_data' in response");
      }
    } else {
      throw Exception('Failed to load graph data');
    }
  }

  Future<void> deleteExpense(String id) async {
    if (id.isEmpty) {
      print("❌ Skipped delete: ID is null or empty");
      return;
    }

    final response = await http.delete(Uri.parse('$baseUrl/expenses/$id'));
    if (response.statusCode != 200) {
      print("❌ Failed to delete: ${response.body}");
    } else {
      print("✅ Deleted successfully: $id");
    }
  }

  Future<Map<String, dynamic>> getMonthlySummary(String month) async {
    try {
      final parts = month.split('-');
      final int year = int.parse(parts[0]);
      final int monthNum = int.parse(parts[1]);

      final response = await http.get(
        Uri.parse(
            "http://127.0.0.1:8000/expenses/summary?month=$monthNum&year=$year"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ✅ Extract data safely
        final Map<String, dynamic> categoryData =
            (data['by_category'] ?? {}) as Map<String, dynamic>;

        final double totalAmount = (data['total_amount'] is num)
            ? (data['total_amount']).toDouble()
            : 0.0;

        // ✅ Try to read from backend if available
        String? summaryText = data['summaryText']?.toString();

        // ✅ Try to get expense list (if backend returns it)
        final expenses = (data['expenses'] is List)
            ? List<Map<String, dynamic>>.from(data['expenses'])
            : [];

        // ✅ If backend didn't provide summary, generate AI one
        if (summaryText == null || summaryText.trim().isEmpty) {
          int totalEntries = expenses.isNotEmpty
              ? expenses.length
              : categoryData.isNotEmpty
                  ? categoryData.length
                  : 0;

          double total = 0;
          double highestExpense = 0;
          double lowestExpense = double.infinity;

          // ✅ Calculate totals from expenses if available
          if (expenses.isNotEmpty) {
            for (var e in expenses) {
              double amount = double.tryParse(e['amount'].toString()) ?? 0.0;
              total += amount;
              if (amount > highestExpense) highestExpense = amount;
              if (amount < lowestExpense) lowestExpense = amount;
            }
          }
          // ✅ If no individual expenses, use category data
          else if (categoryData.isNotEmpty) {
            categoryData.forEach((key, value) {
              double amount = (value is num) ? value.toDouble() : 0.0;
              total += amount;
              if (amount > highestExpense) highestExpense = amount;
              if (amount < lowestExpense) lowestExpense = amount;
            });
          } else {
            total = totalAmount;
            highestExpense = totalAmount;
            lowestExpense = totalAmount;
          }

          double averageExpense = totalEntries > 0 ? total / totalEntries : 0.0;

          summaryText = '''
AI Summary for $month:
- Total Entries: $totalEntries
- Total Spending: Rs. ${total.toStringAsFixed(2)}
- Highest Expense: Rs. ${highestExpense.toStringAsFixed(2)}
- Lowest Expense: Rs. ${lowestExpense == double.infinity ? 0 : lowestExpense.toStringAsFixed(2)}
- Average Expense: Rs. ${averageExpense.toStringAsFixed(2)}
''';
        }

        return {
          'total_amount': totalAmount,
          'summaryText': summaryText,
          'by_category': categoryData,
        };
      } else {
        throw Exception('Failed to load summary: ${response.statusCode}');
      }
    } catch (e) {
      return {
        'summaryText': 'Error fetching summary data.',
        'total_amount': 0.0,
        'by_category': {},
      };
    }
  }

  Future<void> setMonthlyBudget(String month, double amount) async {
    final response = await http.post(
      Uri.parse('$baseUrl/budget/$month'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"amount": amount}),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to set budget");
    }
  }

  Future<double> getMonthlyBudget(String month) async {
    final url = Uri.parse('$baseUrl/budget/$month');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["limit"] * 1.0;
    } else {
      throw Exception("Failed to fetch budget");
    }
  }

  Future<List<Expense>> getExpenses() async {
    final response = await http.get(Uri.parse('$baseUrl/expenses'));

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      return body.map((e) => Expense.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load expenses');
    }
  }

  Future<void> setBudget(double amount) async {
    final response = await http.post(
      Uri.parse("$baseUrl/budget"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"amount": amount}),
    );

    if (response.statusCode != 200) {
      print("Failed to set budget. Status code: ${response.statusCode}");
      print("Response body: ${response.body}");
      throw Exception("Failed to set budget");
    }
  }

  Future<double> getBudget() async {
    final response = await http.get(Uri.parse("$baseUrl/budget"));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['amount'] as num).toDouble();
    } else {
      throw Exception("Failed to fetch budget");
    }
  }

  Future<double> getForecast() async {
    final url = Uri.parse('$baseUrl/forecast');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['forecast'] as num).toDouble();
      } else {
        throw Exception('Failed to fetch forecast');
      }
    } catch (e) {
      print('Error fetching forecast: $e');
      return 0.0;
    }
  }

  Future<void> sendChatMessage(String message) async {
    final response = await http.post(
      Uri.parse("http://localhost:8000/chat-expense"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"message": message}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print("✅ Expense added: ${data['data']}");
    } else {
      print("❌ Failed to add expense");
    }
  }

  Future<List<String>> fetchAIRecommendations(
      Map<String, dynamic> spendingData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ai-recommendations'),
      headers: {"Content-Type": "application/json"},
      body: json.encode(spendingData),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => e.toString()).toList();
    } else {
      throw Exception(
          'Failed to load AI recommendations: ${response.statusCode}');
    }
  }
   Future<Map<String, dynamic>> createFamily(String name, double totalBudget, String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/create_family_budget'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "family_name": name,
        "total_budget": totalBudget,
        "user_id": userId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create family');
    }
  }

  // Join Family
   Future<Map<String, dynamic>> joinFamily(String familyId, String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/join_family'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "family_id": familyId,
        "user_id": userId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to join family');
    }
  }

  // Add Expense
   Future<Map<String, dynamic>> addfamilyExpense(String familyId, String userId, String title, double amount) async {
    final response = await http.post(
      Uri.parse('$baseUrl/add_expense'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "family_id": familyId,
        "user_id": userId,
        "title": title,
        "amount": amount,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to add expense');
    }
  }

  // Get Family Dashboard
   Future<Map<String, dynamic>> getFamilyDashboard(String familyId) async {
    final response = await http.get(Uri.parse('$baseUrl/get_family_dashboard?family_id=$familyId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch family dashboard');
    }
  }

}
