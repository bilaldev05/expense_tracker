import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _api = ApiService();

  final List<_ChatMsg> _messages = [
    _ChatMsg(
        role: 'bot',
        text:
            'Hi! Tell me your expense in plain English.\nExample: “I ate a burger of 500rs at KFC yesterday”'),
  ];

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMsg(role: 'user', text: text));
      _controller.clear();
    });

    try {
      final created = await _api.addExpenseFromText(text);

      setState(() {
        _messages.add(_ChatMsg(
          role: 'bot',
          text:
              'Got it! Added:\n• ${created.title}\n• Rs. ${created.amount.toStringAsFixed(0)}\n• ${created.category}\n• ${created.date}',
        ));
      });

      await NotificationService.showNotification(
        title: "Expense Added (Chat)",
        body: "Rs. ${created.amount.toStringAsFixed(0)} • ${created.title}",
      );
    } catch (e) {
      setState(() {
        _messages.add(_ChatMsg(
            role: 'bot',
            text:
                'Sorry, I couldn’t parse that. Please include the amount, e.g., “rs 500”.'));
      });
    }

    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add via Chat"),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final isUser = m.role == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      m.text,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: "e.g., I ate a burger of 500rs at KFC",
                        filled: true,
                        fillColor: Colors.blue.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                    color: Colors.blue,
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _ChatMsg {
  final String role; // 'user' | 'bot'
  final String text;
  _ChatMsg({required this.role, required this.text});
}
