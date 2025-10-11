import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:flutter_expense_tracker/screens/chat_page.dart';
import 'package:flutter_expense_tracker/screens/graph_page.dart';
import 'package:flutter_expense_tracker/screens/insights_page.dart';
import 'package:flutter_expense_tracker/screens/summary_page.dart';
import 'package:flutter_expense_tracker/auth/login_page.dart';
import 'package:flutter_expense_tracker/services/api_service.dart';
import 'package:flutter_expense_tracker/services/notification_service.dart';
import '../models/expense.dart';

class ExpenseHomePage extends StatefulWidget {
  const ExpenseHomePage({Key? key}) : super(key: key);

  @override
  _ExpenseHomePageState createState() => _ExpenseHomePageState();
}

class _ExpenseHomePageState extends State<ExpenseHomePage> {
  // === controllers & services ===
  final ApiService apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  // === state ===
  List<Expense> expenses = [];
  double _monthlyBudget = 0.0;
  double _remainingBudget = 0.0;
  String _selectedCategory = 'Other';
  int _selectedIndex = 0;
  double _dailyLimit = 0.0;

  final Map<String, IconData> categoryIcons = {
    'Food': Icons.fastfood,
    'Transport': Icons.directions_car,
    'Shopping': Icons.shopping_bag,
    'Bills': Icons.receipt_long,
    'Other': Icons.category_outlined,
  };

  @override
  void initState() {
    super.initState();
    _loadExpenses();
    _loadBudget();
    _loadDailyLimit();
    _loadForecast();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // === Data / API logic (kept intact) ===
  void _loadExpenses() async {
    final fetchedExpenses = await apiService.getExpenses();
    for (var e in fetchedExpenses) {
      debugPrint("🔍 Loaded expense with ID: ${e.id}");
    }
    setState(() {
      expenses = fetchedExpenses;
      _remainingBudget =
          _monthlyBudget - expenses.fold(0.0, (sum, e) => sum + e.amount);
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
        debugPrint('Failed to load daily limit: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading daily limit: $e');
    }
  }

  void _loadForecast() async {
    setState(() {});
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

  Future<void> _deleteExpense(String id) async {
    if (id.isEmpty) {
      debugPrint("❌ Skipped delete: ID is null or empty");
      return;
    }
    await apiService.deleteExpense(id);
    _loadExpenses();
    await NotificationService.showNotification(
      title: "Expense Deleted",
      body: "An expense was removed.",
    );
  }

  Future<void> uploadImage(File file) async {
    final uri = Uri.parse('http://127.0.0.1:8000/upload');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await request.send();

    if (response.statusCode == 200) {
      debugPrint('Upload successful!');
    } else {
      debugPrint('Upload failed with status: ${response.statusCode}');
    }
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
      debugPrint("✅ Upload successful: ${response.body}");
    } else {
      debugPrint("❌ Upload failed: ${response.statusCode} - ${response.body}");
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
          // Convert result to Uint8List
          final result = reader.result;
          if (result is ByteBuffer) {
            final bytes = result.asUint8List();
            await onPicked(bytes, file.name);
          } else if (result is Uint8List) {
            await onPicked(result, file.name);
          } else {
            // Fallback: attempt to cast
            try {
              final bytes = Uint8List.view((reader.result as dynamic));
              await onPicked(bytes, file.name);
            } catch (_) {
              debugPrint("Unable to read web file bytes.");
            }
          }
        });
      }
    });
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

  Map<String, double> _calculateCategoryTotals() {
    Map<String, double> totals = {};
    for (var e in expenses) {
      if (e.category.isNotEmpty) {
        totals[e.category] = (totals[e.category] ?? 0) + e.amount;
      }
    }
    return totals;
  }

  // === UI helpers ===
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

  Widget _statCard(
    String title,
    String value, {
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blueAccent.withOpacity(0.08),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Container(
            height: 20,
            width: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.9),
                  color.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 10,
            ),
          ),
          const SizedBox(width: 6),

          // Text column (wrapped in Flexible to prevent overflow)
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color.withOpacity(0.9),
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard() {
    final totalExpense = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final usedPercent = (_monthlyBudget > 0)
        ? (totalExpense / _monthlyBudget).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Colors.blueGrey.shade50.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// HEADER
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Monthly Overview",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _showSetBudgetDialog,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.blueAccent,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            /// STAT CARDS ROW
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    "Total Budget",
                    "Rs. ${_monthlyBudget.toStringAsFixed(2)}",
                    color: Colors.indigoAccent,
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    "Spent",
                    "Rs. ${totalExpense.toStringAsFixed(2)}",
                    color: Colors.redAccent,
                    icon: Icons.trending_up_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    "Remaining",
                    "Rs. ${_remainingBudget.toStringAsFixed(2)}",
                    color: _remainingBudget < 0 ? Colors.red : Colors.teal,
                    icon: Icons.savings_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            /// PROGRESS INDICATOR CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blueAccent.withOpacity(0.08),
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Budget Usage",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: usedPercent,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(
                        usedPercent > 0.9
                            ? Colors.redAccent
                            : (usedPercent > 0.6
                                ? Colors.orangeAccent
                                : Colors.blueAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${(usedPercent * 100).toStringAsFixed(1)}% used",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        "Daily Limit: Rs. ${_dailyLimit.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            /// ACTION BUTTONS
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      pickImageWeb(
                          (Uint8List imageBytes, String fileName) async {
                        await uploadImageWeb(imageBytes, fileName);
                      });
                    },
                    icon: const Icon(Icons.image_outlined, size: 20),
                    label: const Text(
                      "Extract Image",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.withOpacity(0.9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                      shadowColor: Colors.blueAccent.withOpacity(0.3),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseList() {
    if (expenses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(
          child: Text(
            "No expenses recorded yet 💰",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: expenses.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemBuilder: (context, index) {
        final e = expenses[index];
        final Color accentColor = _getCategoryColor(e.category);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black12.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    accentColor.withOpacity(0.9),
                    accentColor.withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                categoryIcons[e.category] ?? Icons.category_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                e.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: 0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            subtitle: Text(
              "${e.category} • ${e.date}",
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Rs. ${e.amount.toStringAsFixed(2)}",
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.black54, size: 18),
                          SizedBox(width: 8),
                          Text("Edit",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              )),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Text("Delete",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              )),
                        ],
                      ),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert, color: Colors.black54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 🎨 Helper for consistent accent colors
  MaterialColor _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Colors.orange;
      case 'shopping':
        return Colors.pink;
      case 'travel':
        return Colors.blue;
      case 'bills':
        return Colors.red;
      case 'entertainment':
        return Colors.purple;
      default:
        return Colors.teal;
    }
  }

  // === Dialogs ===
  void _showAddExpenseDialog() {
    _clearForm();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text("Add Expense",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _styledTextField(_titleController, 'Title'),
                const SizedBox(height: 12),
                _styledTextField(_amountController, 'Amount',
                    type: TextInputType.number),
                const SizedBox(height: 12),
                _styledTextField(_dateController, 'Date (YYYY-MM-DD)'),
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
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
      ),
    );
  }

  void _showSetBudgetDialog() {
    TextEditingController controller =
        TextEditingController(text: _monthlyBudget.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text("Set Budget",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: "Enter monthly budget",
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            child:
                const Text("Cancel", style: TextStyle(color: Colors.redAccent)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Save", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
      ),
    );
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Edit Expense',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final updatedExpense = {
                  "id": expense['id'],
                  "title": titleController.text,
                  "amount": double.tryParse(amountController.text) ?? 0.0,
                  "category": categoryController.text,
                  "date": expense['date'],
                };

                await apiService.updateExpense(expense['id'], updatedExpense);
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

  // === Navigation helpers ===
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
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: active ? Colors.blueAccent : Colors.grey, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  color: active ? Colors.blueAccent : Colors.grey,
                  fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // === build ===
  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      // Home
      SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBudgetCard(),
              _buildExpenseList(),
              const SizedBox(height: 80), // space for FAB & bottom nav
            ],
          ),
        ),
      ),

      // Insights
      InsightsPage(categoryTotals: _calculateCategoryTotals()),

      // Summary
      const SummaryPage(),

      // Graph
      GraphPage(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _selectedIndex == 0
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 1,
              centerTitle: true,
              title: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.home, color: Colors.blueAccent),
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
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: BottomAppBar(
          color: Colors.white,
          elevation: 6,
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          child: SizedBox(
            height: 64,
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
}
