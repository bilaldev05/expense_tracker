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
    final uri = Uri.parse(
        'http://127.0.0.1:8000/upload'); 

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Edit Expense',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: const TextStyle(color: Colors.black),
                    filled: true,
                    fillColor: Colors.blue.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: const TextStyle(color: Colors.black),
                    filled: true,
                    fillColor: Colors.blue.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryController,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: const TextStyle(color: Colors.black),
                    filled: true,
                    fillColor: Colors.blue.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
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
              child: const Text(
                'Update',
                style: TextStyle(color: Colors.black),
              ),
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
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "Set Budget",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                ),
              ),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Enter amount",
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.blue.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text(
                    "Save",
                    style: TextStyle(color: Colors.black),
                  ),
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
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text(
                "Add Expense",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                ),
              ),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTextField(
                        _titleController,
                        "Title",
                        fillColor: Colors.blue.shade50,
                        textColor: Colors.black,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _amountController,
                        "Amount",
                        type: TextInputType.number,
                        fillColor: Colors.blue.shade50,
                        textColor: Colors.black,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _dateController,
                        "Date (YYYY-MM-DD)",
                        fillColor: Colors.blue.shade50,
                        textColor: Colors.black,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        items: categoryIcons.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Row(
                              children: [
                                Icon(entry.value, color: Colors.blue),
                                const SizedBox(width: 10),
                                Text(entry.key,
                                    style:
                                        const TextStyle(color: Colors.black)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _selectedCategory = value!),
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: const TextStyle(color: Colors.black54),
                          filled: true,
                          fillColor: Colors.blue.shade50,
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.blue),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide:
                                const BorderSide(color: Colors.blue, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _addExpense,
                        child: const Text(
                          "Save",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ));
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType type = TextInputType.text,
      Color fillColor = Colors.white,
      Color textColor = Colors.black}) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textColor.withOpacity(0.6)),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildExpenseList() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.only(bottom: 80), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 100),
              child: Center(
                child: Text(
                  "No expenses yet",
                  style: TextStyle(color: Colors.grey, fontSize: 18),
                ),
              ),
            )
          else
            ListView.builder(
              itemCount: expenses.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemBuilder: (context, index) {
                final e = expenses[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border(
                      left: BorderSide(
                        width: 4,
                        color: Colors.blue.shade400,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Expense Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title and Amount
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    "Rs. ${e.amount.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Category and Date
                              Row(
                                children: [
                                  const Icon(Icons.category,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    e.category,
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.calendar_today,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    e.date,
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
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
                                debugPrint(
                                    "❌ Skipped delete: ID is null or empty");
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit,
                                      color: Colors.blue, size: 18),
                                  SizedBox(width: 8),
                                  Text("Edit"),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      color: Colors.red, size: 18),
                                  SizedBox(width: 8),
                                  Text("Delete"),
                                ],
                              ),
                            ),
                          ],
                          icon: const Icon(Icons.more_vert,
                              color: Colors.black54, size: 20),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard() {
    final totalExpense = expenses.fold(0.0, (sum, e) => sum + e.amount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Total Expense",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Rs. ${totalExpense.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Remaining: Rs. ${_remainingBudget.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              _remainingBudget < 0 ? Colors.red : Colors.green,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: _showSetBudgetDialog,
                          icon: const Icon(Icons.edit,
                              size: 20, color: Colors.blue),
                          tooltip: 'Set Budget',
                          splashRadius: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Daily Limit Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Daily Limit",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Rs. ${_dailyLimit.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Forecasted Expense Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Forecast",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Rs. ${_forecastedExpense.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Upload Button
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.blue, // Text color
                backgroundColor: Colors.white, // Button background
                side: const BorderSide(color: Colors.blue), // Blue border
                elevation: 0,
              ),
              onPressed: () {
                pickImageWeb((Uint8List imageBytes, String fileName) async {
                  await uploadImageWeb(imageBytes, fileName);
                });
              },
              child: const Text("Extract Image"),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80), // for FAB
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBudgetCard(),
            _buildExpenseList(),
          ],
        ),
      ),
      InsightsPage(categoryTotals: _calculateCategoryTotals()),
      FutureBuilder(
        future: apiService.getMonthlySummary(
            "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}"),
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return const Center(child: Text("Failed to load summary"));
          return SummaryPage(summary: snapshot.data!);
        },
      ),
      GraphPage(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _selectedIndex == 0
          ? AppBar(
              backgroundColor: Colors.blue,
              centerTitle: true,
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ChatExpenseScreen()));
                  },
                  icon: const Icon(Icons.chat_bubble_outline,
                      color: Colors.white),
                  tooltip: 'Add via Chat',
                ),
                IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.white),
                ),
              ],
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.home, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    "Home",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            )
          : null,
      body: _pages[_selectedIndex],
      bottomNavigationBar: SizedBox(
          height: 56,
          child: BottomAppBar(
            color: Colors.blue,
            shape: const CircularNotchedRectangle(),
            notchMargin: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.home,
                    size: 22,
                    color: _selectedIndex == 0 ? Colors.white : Colors.white70,
                  ),
                  onPressed: () => setState(() => _selectedIndex = 0),
                ),
                IconButton(
                  icon: Icon(
                    Icons.pie_chart,
                    size: 22,
                    color: _selectedIndex == 1 ? Colors.white : Colors.white70,
                  ),
                  onPressed: () => setState(() => _selectedIndex = 1),
                ),
                const SizedBox(width: 48),
                IconButton(
                  icon: Icon(
                    Icons.analytics,
                    size: 22,
                    color: _selectedIndex == 2 ? Colors.white : Colors.white70,
                  ),
                  onPressed: () => setState(() => _selectedIndex = 2),
                ),
                IconButton(
                  icon: Icon(
                    Icons.show_chart, // Graph
                    size: 22,
                    color: _selectedIndex == 3 ? Colors.white : Colors.white70,
                  ),
                  onPressed: () => setState(() => _selectedIndex = 3),
                ),
              ],
            ),
          )),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 48,
        height: 48,
        child: FloatingActionButton(
          onPressed: _showAddExpenseDialog,
          backgroundColor: Colors.blue,
          child: const Icon(Icons.add, size: 22),
        ),
      ),
    );
  }
}
