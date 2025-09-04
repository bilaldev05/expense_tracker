import 'dart:convert';

import 'package:http/http.dart' as http;
import '../models/expense.dart';

class ApiService {
  final String baseUrl = "http://192.168.100.4:8000";

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

  Future<String> getMonthlySummary(String month) async {
    final response = await http.get(Uri.parse('$baseUrl/summary/$month'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['summary'];
    } else {
      throw Exception('Failed to load summary');
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
}
