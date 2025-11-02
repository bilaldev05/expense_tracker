import 'package:flutter/material.dart';
import 'package:flutter_expense_tracker/auth/login_page.dart';
import 'package:flutter_expense_tracker/widgets/home_appbar.dart';
import 'package:flutter_expense_tracker/screens/family/join_family_screen.dart';
import 'package:flutter_expense_tracker/screens/family/create_family_screen.dart';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FamilyDashboardScreen extends StatefulWidget {
  final String? familyId;
  final String userId;

  const FamilyDashboardScreen({
    super.key,
    required this.familyId,
    required this.userId,
  });

  @override
  State<FamilyDashboardScreen> createState() => _FamilyDashboardScreenState();
}

class _FamilyDashboardScreenState extends State<FamilyDashboardScreen> {
  Map<String, dynamic>? familyData;
  bool isLoading = true;
  int _selectedIndex = 0;
  String? currentFamilyId;

  @override
  void initState() {
    super.initState();
    currentFamilyId = widget.familyId;
    _loadFamilyData();
  }

  Future<void> _loadFamilyData() async {
    if (currentFamilyId == null || currentFamilyId!.isEmpty) {
      setState(() {
        isLoading = false;
        familyData = null;
      });
      return;
    }

    try {
      final api = ApiService();
      final data = await api.getFamilyDashboard(currentFamilyId!);
      setState(() {
        familyData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading family data: $e')),
      );
    }
  }

  /// 🧭 Logout
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) =>  LoginPage()),
        (route) => false,
      );
    }
  }

  /// 🧩 Dashboard UI
  Widget _buildFamilyDashboard() {
    final members = (familyData?['members'] as List?) ?? [];
    final expenses = (familyData?['expenses'] as List?) ?? [];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "👨‍👩‍👧 Family: ${familyData!['family_name'] ?? 'Unnamed Family'}",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text("💳 Family ID: ${currentFamilyId ?? 'N/A'}"),
          Text("💰 Total Budget: Rs. ${familyData!['total_budget'] ?? 0}"),
          Text("💸 Remaining: Rs. ${familyData!['remaining_budget'] ?? 0}"),
          const SizedBox(height: 16),
          const Text(
            "Members:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...members.map((m) {
            final name = m is Map ? m['name'] ?? 'Unknown' : m.toString();
            return ListTile(
              leading: const Icon(Icons.person, color: Colors.blueAccent),
              title: Text(name),
            );
          }),
          const Divider(),
          const Text(
            "Recent Expenses:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: expenses.isEmpty
                ? const Center(child: Text("No expenses yet"))
                : ListView.builder(
                    itemCount: expenses.length,
                    itemBuilder: (context, i) {
                      final exp = expenses[i];
                      final title = exp is Map ? exp['title'] ?? 'Unnamed' : exp.toString();
                      final amount = exp is Map ? exp['amount'] ?? 0 : 0;
                      return ListTile(
                        leading: const Icon(Icons.money, color: Colors.green),
                        title: Text(title.toString()),
                        trailing: Text("Rs. $amount"),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 🔁 Bottom nav
  Future<void> _onItemTapped(int index) async {
    setState(() => _selectedIndex = index);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => index == 0
            ? JoinFamilyScreen(userId: widget.userId)
            : CreateFamilyScreen(userId: widget.userId),
      ),
    );

    if (result != null && result is Map && result['family_id'] != null) {
      setState(() {
        currentFamilyId = result['family_id'];
        isLoading = true;
      });
      await _loadFamilyData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFamily =
        currentFamilyId != null && currentFamilyId!.isNotEmpty && familyData != null;

    return Scaffold(
      appBar: HomeAppBar(onLogout: _logout),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasFamily
              ? _buildFamilyDashboard()
              : const Center(
                  child: Text(
                    "No family linked yet.\nYou can Join or Create one below.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
      bottomNavigationBar: hasFamily
          ? null
          : BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: Colors.blueAccent,
              unselectedItemColor: Colors.grey,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.group_add),
                  label: "Join Family",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.family_restroom),
                  label: "Create Family",
                ),
              ],
            ),
    );
  }
}
