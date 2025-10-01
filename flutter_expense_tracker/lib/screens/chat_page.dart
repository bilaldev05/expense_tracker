import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatExpenseScreen extends StatefulWidget {
  const ChatExpenseScreen({super.key});

  @override
  State<ChatExpenseScreen> createState() => _ChatExpenseScreenState();
}

class _ChatExpenseScreenState extends State<ChatExpenseScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final String apiUrl = "http://localhost:8000/chat-expense";
  bool _isTyping = false; // <-- typing indicator flag

  Future<void> _sendMessage() async {
    String message = _controller.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add({
        "sender": "user",
        "text": message,
        "time": DateTime.now().toString(),
      });
      _isTyping = true; // show typing indicator
    });
    _controller.clear();

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final parsed = data["data"];

        String reply =
            "✅ Added *${parsed['title']}* of **${parsed['amount']} Rs** under *${parsed['category']}* on ${parsed['date']}";

        setState(() {
          _messages.add({
            "sender": "bot",
            "text": reply,
            "time": DateTime.now().toString(),
          });
          _isTyping = false; // hide typing indicator
        });
      } else {
        setState(() {
          _messages.add({
            "sender": "bot",
            "text": "❌ Failed to add expense",
            "time": DateTime.now().toString(),
          });
          _isTyping = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          "sender": "bot",
          "text": "⚠️ Error: $e",
          "time": DateTime.now().toString(),
        });
        _isTyping = false;
      });
    }
  }

  String _formatTime(String timestamp) {
    final dt = DateTime.tryParse(timestamp);
    if (dt == null) return "";
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 4,
        title: Row(
          children: const [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Icon(Icons.smart_toy, color: Colors.blueAccent, size: 20),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Expense Bot",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "Online",
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            )
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  // Typing indicator bubble
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Bot is typing",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _TypingDots(),
                        ],
                      ),
                    ),
                  );
                }

                final msg = _messages[index];
                bool isUser = msg["sender"] == "user";

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          gradient: isUser
                              ? const LinearGradient(
                                  colors: [Colors.blueAccent, Colors.lightBlue],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isUser ? null : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          msg["text"]!,
                          style: TextStyle(
                            fontSize: 15,
                            color: isUser ? Colors.white : Colors.black87,
                            fontWeight:
                                isUser ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(msg["time"]),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        hintText: "Type an expense...",
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.blueAccent,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated typing dots widget
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        int tick = (_controller.value * 3).floor() % 3;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Opacity(
                opacity: tick == i ? 1.0 : 0.3,
                child: const Text(
                  "•",
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
