import 'package:flutter/material.dart';
import 'package:flutter_expense_tracker/screens/family/family_dashboard_screen.dart';
import 'package:flutter_expense_tracker/screens/family/create_family_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onLogout;

  const HomeAppBar({super.key, required this.onLogout});

  Future<void> _openFamilyDashboard(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("user_id");
    final familyId = prefs.getString("family_id");

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in first")),
      );
      return;
    }

    if (familyId != null && familyId.isNotEmpty) {
      // ✅ If user already has a family → open Family Dashboard
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FamilyDashboardScreen(
            familyId: familyId,
            userId: userId,
          ),
        ),
      );
    } else {
      // 🆕 No family yet → Create new one
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateFamilyScreen(userId: userId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text("Expense Tracker"),
      actions: [
        IconButton(
          icon: const Icon(Icons.family_restroom),
          tooltip: "Family Dashboard",
          onPressed: () => _openFamilyDashboard(context),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: "Logout",
          onPressed: onLogout,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
