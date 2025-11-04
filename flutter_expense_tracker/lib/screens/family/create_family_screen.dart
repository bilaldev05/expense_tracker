import 'package:flutter/material.dart';
import 'package:flutter_expense_tracker/screens/family/family_dashboard_screen.dart';
import 'package:flutter_expense_tracker/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateFamilyScreen extends StatefulWidget {
  final String userId;

  const CreateFamilyScreen({super.key, required this.userId});

  @override
  State<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends State<CreateFamilyScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  bool _loading = false;

  Future<void> _createFamily() async {
    final name = _nameController.text.trim();
    final budget = double.tryParse(_budgetController.text.trim()) ?? 0.0;

    if (name.isEmpty || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid name and budget")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final api = ApiService();
      final result = await api.createFamily(name, budget, widget.userId);

      final familyId = result['family_id'];
      if (familyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Family created but no ID returned.")),
        );
        return;
      }

      // ✅ Save family ID locally for quick access later
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("family_id", familyId.toString());

      // ✅ Navigate to Family Dashboard
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FamilyDashboardScreen(
              familyId: familyId.toString(),
              userId: widget.userId,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Family")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Family Name"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _budgetController,
              decoration: const InputDecoration(labelText: "Total Budget"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _createFamily,
                    child: const Text("Create Family"),
                  ),
          ],
        ),
      ),
    );
  }
}
