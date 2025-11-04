import 'package:flutter/material.dart';
import 'package:flutter_expense_tracker/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JoinFamilyScreen extends StatefulWidget {
  final String userId;

  const JoinFamilyScreen({super.key, required this.userId});

  @override
  State<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<JoinFamilyScreen> {
  final TextEditingController _inviteCodeController = TextEditingController();
  bool _loading = false;

  Future<void> _joinFamily() async {
    final inviteCode = _inviteCodeController.text.trim();
    if (inviteCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an invite code")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final api = ApiService();
      final response = await api.joinFamily(inviteCode, widget.userId);

      if (response['family_id'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("family_id", response['family_id']);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Successfully joined family!")),
        );

        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/familyDashboard',
            arguments: {
              'familyId': response['family_id'],
              'userId': widget.userId,
            },
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid invite code")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error joining family: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Join Family"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Text(
              "Enter Family Invite Code",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _inviteCodeController,
              decoration: InputDecoration(
                labelText: "Invite Code",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.group_add),
              label: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("Join Family"),
              onPressed: _loading ? null : _joinFamily,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 10),
            const Text(
              "Don’t have a family? You can create one from your Family Dashboard.",
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
