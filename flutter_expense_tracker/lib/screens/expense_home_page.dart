import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter_expense_tracker/screens/chat_page.dart';
import 'package:flutter_expense_tracker/screens/graph_page.dart';
import 'package:flutter_expense_tracker/screens/insights_page.dart';

import 'package:flutter_expense_tracker/screens/summary_page.dart';
import 'package:flutter_expense_tracker/services/notification_service.dart';
import 'package:flutter_expense_tracker/services/api_service.dart';
import 'package:flutter_expense_tracker/auth/login_page.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/expense.dart';
import 'dart:html' as html;

class ExpenseHomePage extends StatefulWidget {
  @override
  _ExpenseHomePageState createState() => _ExpenseHomePageState();
}

class _ExpenseHomePageState extends State<ExpenseHomePage> {
  // === EXISTING LOGIC & CONTROLLERS (unchanged) ===
  final ApiService apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();

  List<Expense> expenses = [];
  double _monthlyBudget = 0.0;
  double _remainingBudget = 0.0;
  String _selectedCategory = 'Other';
  int _selectedIndex = 0;
  double _dailyLimit = 0.0;
  double _forecastedExpense = 0.0;

  final Map<String, IconData> categoryIcons = {
    'Food': Icons.fastfood,
    'Transport': Icons.directions_car,
    'Shopping': Icons.shopping_bag,
    'Bills': Icons.receipt,
    'Other': Icons.category,
  };

  @override
  void initState() {
    super.initState();
    _loadExpenses();
    _loadBudget();
    _loadDailyLimit();
    _loadForecast();
  }

  void _loadExpenses() async {
    final fetchedExpenses = await apiService.getExpenses();
    for (var e in fetchedExpenses) {
      print("🔍 Loaded expense with ID: ${e.id}");
    }
    setState(() {
      expenses = fetchedExpenses;
    });
  }

  void _loadBudget() async {
    final budget = await apiService.getBudget();
    setState(() {
      _monthlyBudget = budget;
      _remainingBudget =
          _monthlyBudget - expenses.fold(0.0, (sum, e) => sum + e.amount);
    });
  }

  Future<void> uploadImageWeb(Uint8List imageBytes, String fileName) async {
    final base64Image = base64Encode(imageBytes);
    final url = Uri.parse("http://127.0.0.1:8000/upload_bill");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_id": "user123",
        "image_base64": "data:image/jpeg;base64,$base64Image"
      }),
    );

    if (response.statusCode == 200) {
      print("✅ Upload successful: ${response.body}");
    } else {
      print("❌ Upload failed: ${response.statusCode} - ${response.body}");
    }
  }

  Future<void> pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      await uploadImage(file);
    }
  }

  Future<void> _loadDailyLimit() async {
    try {
      final response =
          await http.get(Uri.parse('http://localhost:8000/daily-limit'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _dailyLimit = (data['limit'] ?? 0.0).toDouble();
        });
      } else {
        print('Failed to load daily limit');
      }
    } catch (e) {
      print('Error loading daily limit: $e');
    }
  }

  void pickImageWeb(Future<void> Function(Uint8List, String) onPicked) {
    html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((event) {
      final file = uploadInput.files?.first;
      if (file != null) {
        final reader = html.FileReader();

        reader.readAsArrayBuffer(file);
        reader.onLoadEnd.listen((e) async {
          final bytes = reader.result as Uint8List;
          await onPicked(bytes, file.name);
        });
      }
    });
  }

  void _loadForecast() async {
    final result = await apiService.getForecast();
    setState(() {
      _forecastedExpense = result;
    });
  }

  Map<String, double> _calculateCategoryTotals() {
    Map<String, double> totals = {};
    for (var e in expenses) {
      if (e.category.isNotEmpty) {
        totals[e.category] = (totals[e.category] ?? 0) + e.amount;
      }
    }
    return totals;
  }

  Future<void> _addExpense() async {
    if (_formKey.currentState!.validate()) {
      final newExpense = Expense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        amount: double.parse(_amountController.text),
        date: _dateController.text,
        category: _selectedCategory,
      );

      await apiService.addExpense(newExpense);
      _clearForm();
      Navigator.pop(context);
      _loadExpenses();

      await NotificationService.showNotification(
        title: "Expense Added",
        body: "Rs. ${newExpense.amount} under '${newExpense.category}'",
      );
    }
  }

  Future<void> uploadImage(File file) async {
    final uri = Uri.parse('http://127.0.0.1:8000/upload');

    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      print('Upload successful!');
    } else {
      print('Upload failed with status: ${response.statusCode}');
    }
  }

  Future<void> _deleteExpense(String id) async {
    if (id.isEmpty) {
      print("❌ Skipped delete: ID is null or empty");
      return;
    }

    await apiService.deleteExpense(id);
    _loadExpenses();
    await NotificationService.showNotification(
      title: "Expense Deleted",
      body: "An expense was removed.",
    );
  }

  void _clearForm() {
    _titleController.clear();
    _amountController.clear();
    _dateController.clear();
    _selectedCategory = 'Other';
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => LoginPage()));
  }

  // === UI: professional layout only (logic calls unchanged) ===

  void _showEditDialog(Map<String, dynamic> expense) {
    final titleController = TextEditingController(text: expense['title']);
    final amountController =
        TextEditingController(text: expense['amount'].toString());
    final categoryController = TextEditingController(text: expense['category']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text(
            'Edit Expense',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _styledTextField(titleController, 'Title'),
                const SizedBox(height: 12),
                _styledTextField(amountController, 'Amount',
                    type: TextInputType.number),
                const SizedBox(height: 12),
                _styledTextField(categoryController, 'Category'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                final updatedExpense = {
                  "id": expense['id'],
                  "title": titleController.text,
                  "amount": double.tryParse(amountController.text) ?? 0.0,
                  "category": categoryController.text,
                  "date": expense['date'],
                };

                final api = ApiService();
                await api.updateExpense(expense['id'], updatedExpense);
                Navigator.pop(context);
                setState(() {
                  _loadExpenses(); // Refresh the list
                });
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showSetBudgetDialog() {
    TextEditingController controller =
        TextEditingController(text: _monthlyBudget.toString());
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              title: const Text(
                "Set Budget",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Enter monthly budget",
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  child: const Text(
                    "Save",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  onPressed: () async {
                    final value = double.tryParse(controller.text);
                    if (value != null) {
                      await apiService.setBudget(value);
                      setState(() {
                        _monthlyBudget = value;
                        _remainingBudget = _monthlyBudget -
                            expenses.fold(0.0, (sum, e) => sum + e.amount);
                      });
                    }
                    Navigator.pop(context);
                  },
                ),
              ],
            ));
  }

  void _showAddExpenseDialog() {
    _clearForm();
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              title: const Text("Add Expense",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _styledTextField(_titleController, "Title"),
                      const SizedBox(height: 12),
                      _styledTextField(_amountController, "Amount",
                          type: TextInputType.number),
                      const SizedBox(height: 12),
                      _styledTextField(_dateController, "Date (YYYY-MM-DD)"),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        items: categoryIcons.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Row(
                              children: [
                                Icon(entry.value, color: Colors.blueAccent),
                                const SizedBox(width: 10),
                                Text(entry.key),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _selectedCategory = value!),
                        decoration: InputDecoration(
                          labelText: 'Category',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _addExpense,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text("Save",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ));
  }

  Widget _styledTextField(TextEditingController controller, String label,
      {TextInputType type = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Required';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildBudgetCard() {
    final totalExpense = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final usedPercent = (_monthlyBudget > 0)
        ? (totalExpense / _monthlyBudget).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: title + actions
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Monthly Overview",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _showSetBudgetDialog,
                icon: const Icon(Icons.edit, color: Colors.blueAccent),
              )
            ],
          ),

          const SizedBox(height: 8),

          // Cards row (flexible, no overflow)
          Row(
            children: [
              Expanded(
                child: _statCard(
                  "Budget",
                  "Rs. ${_monthlyBudget.toStringAsFixed(2)}",
                  icon: Icons.account_balance_wallet,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  "Spent",
                  "Rs. ${totalExpense.toStringAsFixed(2)}",
                  color: Colors.redAccent,
                  icon: Icons.trending_up,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  "Remaining",
                  "Rs. ${_remainingBudget.toStringAsFixed(2)}",
                  color: _remainingBudget < 0 ? Colors.red : Colors.green,
                  icon: Icons.savings,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress and small stats
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Budget Usage",
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: usedPercent,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      usedPercent > 0.9 ? Colors.red : Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${(usedPercent * 100).toStringAsFixed(1)}% used",
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text("Daily: Rs. ${_dailyLimit.toStringAsFixed(2)}",
                        style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Image extract button
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  pickImageWeb((Uint8List imageBytes, String fileName) async {
                    await uploadImageWeb(imageBytes, fileName);
                  });
                },
                icon: const Icon(Icons.image),
                label: const Text("Extract Image"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    String value, {
    Color color = Colors.blueAccent,
    IconData icon = Icons.info,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseList() {
    if (expenses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(
          child: Text(
            "No expenses yet",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: expenses.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(16, 8, 16, 80), // reduced bottom padding
      itemBuilder: (context, index) {
        final e = expenses[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.08),
              child: Icon(categoryIcons[e.category] ?? Icons.category,
                  color: Colors.blue),
            ),
            title: Text(
              e.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              "${e.category} • ${e.date}",
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: SizedBox(
              width: 120, // ensures it doesn’t squeeze
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Text(
                      "Rs. ${e.amount.toStringAsFixed(2)}",
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditDialog({
                          'id': e.id,
                          'title': e.title,
                          'amount': e.amount,
                          'date': e.date,
                          'category': e.category,
                        });
                      } else if (value == 'delete') {
                        if (e.id.isNotEmpty) {
                          _deleteExpense(e.id);
                        } else {
                          debugPrint("❌ Skipped delete: ID is null or empty");
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.black54),
                            SizedBox(width: 8),
                            Text("Edit"),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text("Delete"),
                          ],
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // === build ===
  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      // Page 1 — Home
      SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBudgetCard(),
              _buildExpenseList(),
            ],
          ),
        ),
      ),

      // Page 2 — Insights
      InsightsPage(categoryTotals: _calculateCategoryTotals()),

      // Page 3 — Summary
      const SummaryPage(),

      // Page 4 — Graph
      GraphPage(),
    ];

    // Example return (replace with your actual navigation logic)

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _selectedIndex == 0
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 1,
              centerTitle: true,
              title: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.home, color: Colors.blue),
                SizedBox(width: 8),
                Text("Home", style: TextStyle(color: Colors.black87)),
              ]),
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ChatExpenseScreen()));
                  },
                  icon: const Icon(Icons.chat_bubble_outline,
                      color: Colors.black54),
                  tooltip: 'Add via Chat',
                ),
                IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.black54),
                ),
              ],
            )
          : null,
      body: _pages[_selectedIndex],
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: SafeArea(
        top: false, // only respect bottom safe area
        child: BottomAppBar(
          color: Colors.white,
          elevation: 6,
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          child: SizedBox(
            height: 60, // reduced from 64 → avoids pixel overflow
            child: Row(
              children: [
                Expanded(
                    child: _navItem(icon: Icons.home, index: 0, label: "Home")),
                Expanded(
                    child: _navItem(
                        icon: Icons.pie_chart, index: 1, label: "Insights")),
                const SizedBox(width: 48), // space for FAB
                Expanded(
                    child: _navItem(
                        icon: Icons.analytics, index: 2, label: "Summary")),
                Expanded(
                    child: _navItem(
                        icon: Icons.show_chart, index: 3, label: "Graph")),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required int index,
    required String label,
  }) {
    final active = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: double.infinity, // 🔥 take full height of BottomAppBar
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // 🔥 center content
          children: [
            Icon(icon, color: active ? Colors.blue : Colors.grey, size: 22),
            const SizedBox(height: 2), // 🔧 reduced spacing
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.blue : Colors.grey,
                fontSize: 11, // 🔧 slightly smaller to fit
              ),
            ),
          ],
        ),
      ),
    );
  }
}
