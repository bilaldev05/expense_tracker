import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_expense_tracker/services/api_service.dart';
import 'package:share_plus/share_plus.dart';

import 'package:shared_preferences/shared_preferences.dart';

class FamilyDashboardScreen extends StatefulWidget {
  final String familyId;
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
  final ApiService api = ApiService();
  Map<String, dynamic>? familyData;
  bool _loading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadFamilyData();
  }

  Future<void> _loadFamilyData() async {
    try {
      final data = await api.getFamilyDashboard(widget.familyId);
      final prefs = await SharedPreferences.getInstance();

      // Check if user is admin
      _isAdmin = data['members'].isNotEmpty && data['members'][0] == widget.userId;

      setState(() {
        familyData = data;
        _loading = false;
      });

      await prefs.setString('family_id', widget.familyId);
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading dashboard: $e')));
    }
  }

  Future<void> _inviteMember() async {
    final inviteCode = familyData?['invite_code'] ?? 'ABC123';
    final inviteLink =
        'https://nikahplus-familyapp.com/join?family=$inviteCode';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Invite Family Members",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text("Share this code or link to let others join your family."),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(inviteCode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Invite code copied")),
                      );
                    },
                  )
                ],
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => Share.share('Join my family on Nikah Plus: $inviteLink'),
              icon: const Icon(Icons.share),
              label: const Text("Share Invite Link"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMember(String memberId) async {
    if (!_isAdmin) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove Member"),
        content: const Text("Are you sure you want to remove this member?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Remove")),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await api.removeMember(widget.familyId, memberId);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Member removed")));
        _loadFamilyData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _leaveFamily() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Leave Family"),
        content: const Text("Are you sure you want to leave this family?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Leave")),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await api.leaveFamily(widget.userId);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('family_id');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You left the family")));
          Navigator.pushReplacementNamed(context, '/home');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error leaving family: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (familyData == null) {
      return const Scaffold(
        body: Center(child: Text("No family data found")),
      );
    }

    final members = List<Map<String, dynamic>>.from(familyData?['members'] ?? []);
    final expenses = List<Map<String, dynamic>>.from(familyData?['expenses'] ?? []);
    final totalBudget = familyData?['total_budget'] ?? 0.0;
    final remaining = familyData?['remaining_budget'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(familyData?['family_name'] ?? "Family Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: _inviteMember,
            tooltip: "Invite Member",
          ),
          if (!_isAdmin)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              tooltip: "Leave Family",
              onPressed: _leaveFamily,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFamilyData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ---- Budget Summary ----
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text("Budget Overview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text("Total Budget: \$${totalBudget.toStringAsFixed(2)}"),
                      Text("Remaining: \$${remaining.toStringAsFixed(2)}"),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: remaining / totalBudget,
                        backgroundColor: Colors.grey.shade300,
                        color: Colors.green,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              // ---- Members ----
              _sectionTitle("Family Members (${members.length})"),
              ...members.map((m) => ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(m["name"] ?? "Unnamed"),
                    subtitle: Text("Spent: \$${m["spent"] ?? 0}"),
                    trailing: _isAdmin && m["user_id"] != widget.userId
                        ? IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteMember(m["user_id"]),
                          )
                        : null,
                  )),

              const SizedBox(height: 20),
              // ---- Expenses ----
              _sectionTitle("Recent Expenses (${expenses.length})"),
              ...expenses.map((e) => ListTile(
                    leading: const Icon(Icons.receipt_long, color: Colors.teal),
                    title: Text(e["title"]),
                    subtitle: Text("By ${e["user_name"]}"),
                    trailing: Text("- \$${e["amount"]}"),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
