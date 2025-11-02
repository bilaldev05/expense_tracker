import 'package:flutter/material.dart';
import 'package:flutter_expense_tracker/screens/finance_chat_screen.dart';
import 'package:flutter_expense_tracker/screens/expense_home_page.dart';
import 'package:flutter_expense_tracker/screens/family/family_dashboard_screen.dart';
import 'package:flutter_expense_tracker/utils/shared_preferences.dart';


class HomeAppBar extends StatefulWidget implements PreferredSizeWidget {
  final VoidCallback onLogout;

  const HomeAppBar({super.key, required this.onLogout});

  @override
  State<HomeAppBar> createState() => _HomeAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _HomeAppBarState extends State<HomeAppBar> {
  bool isFamilyMode = false;

  Future<void> _logout() async {
    await SharedPrefsHelper.clearAll();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.family_restroom, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Text(
            isFamilyMode ? "Family Home" : "My Home",
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ],
      ),
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.blueAccent),
        onPressed: () {
          // Optional: add drawer or side menu
        },
      ),
      actions: [
        // 🔄 Mode toggle button
        IconButton(
          icon: Icon(
            isFamilyMode ? Icons.home : Icons.groups,
            color: Colors.blueAccent,
          ),
          tooltip: isFamilyMode ? "Switch to My Home" : "Switch to Family Home",
          onPressed: () async {
            final familyId = await SharedPrefsHelper.getFamilyId();
            final userId = await SharedPrefsHelper.getUserId();

            setState(() {
              isFamilyMode = !isFamilyMode;
            });

            if (isFamilyMode) {
              // ✅ Always navigate, even if no family linked yet
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => FamilyDashboardScreen(
                    familyId: familyId ?? '',
                    userId: userId ?? '',
                  ),
                ),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const ExpenseHomePage(),
                ),
              );
            }
          },
        ),

        // 💬 Chat button
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent),
          tooltip: "Open Finance Chat",
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FinanceChatScreen()),
            );
          },
        ),

        // 🚪 Logout button
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          tooltip: "Logout",
          onPressed: _logout,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: Colors.grey.shade200,
          height: 1,
        ),
      ),
    );
  }
}
