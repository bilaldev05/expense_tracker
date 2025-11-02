import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'family_dashboard_screen.dart';

class JoinFamilyScreen extends StatefulWidget {
  final String userId;
  const JoinFamilyScreen({super.key, required this.userId});

  @override
  State<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<JoinFamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool isLoading = false;

  Future<void> _joinFamily() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    try {
      final api = ApiService();
      final result =
          await api.joinFamily(_codeController.text.trim(), widget.userId);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FamilyDashboardScreen(
              familyId: result['family_id'],
              userId: widget.userId,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Family'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade600,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB3E5FC), Color(0xFF81D4FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Join Existing Family",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Family ID / Code',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          val!.isEmpty ? 'Enter a family code' : null,
                    ),
                    const SizedBox(height: 28),
                    isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton.icon(
                            onPressed: _joinFamily,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.group_add_outlined),
                            label: const Text(
                              'Join Family',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
