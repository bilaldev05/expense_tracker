import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_expense_tracker/screens/expense_home_page.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatExpenseScreen extends StatefulWidget {
  const ChatExpenseScreen({super.key});

  @override
  State<ChatExpenseScreen> createState() => _ChatExpenseScreenState();
}

class _ChatExpenseScreenState extends State<ChatExpenseScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  final String baseUrl = "http://localhost:8000";
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isTyping = false;

  Map<String, dynamic>? _pendingExpense;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onError: (_) => setState(() => _isListening = false),
      onStatus: (val) {
        if (val == "done") setState(() => _isListening = false);
      },
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) {
          setState(() => _controller.text = val.recognizedWords);
        },
      );
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  /// 🔹 Step 1: Send message — backend just parses (no DB insert yet)
  Future<void> _sendMessage() async {
    String message = _controller.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add({
        "sender": "user",
        "text": message,
        "time": DateTime.now().toString(),
      });
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/chat-expense"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final parsed = data["data"];

        // Store temporarily for confirmation
        _pendingExpense = parsed;

        _addBotMessage(
          "💬 You said: *${parsed['title']}* for **${parsed['amount']} Rs** under *${parsed['category']}*.\n\nWould you like to confirm this expense?",
          type: "confirmation",
        );
      } else {
        _addBotMessage("❌ Failed to process expense.");
      }
    } catch (e) {
      _addBotMessage("⚠️ Error: $e");
    }
  }

  /// 🔹 Step 2: Confirm and actually add to DB
  Future<void> _confirmExpense() async {
    if (_pendingExpense == null) return;

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/confirm-expense"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(_pendingExpense),
      );

      if (response.statusCode == 200) {
        setState(() {
          _messages.add({
            "sender": "bot",
            "text":
                "✅ Added *${_pendingExpense!['title']}* of **${_pendingExpense!['amount']} Rs** under *${_pendingExpense!['category']}* on ${_pendingExpense!['date']}.",
            "time": DateTime.now().toString(),
          });
        });

        _pendingExpense = null;

        // ✅ Delay for bot message animation
        Future.delayed(const Duration(milliseconds: 800), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ExpenseHomePage()),
          );
        });
      } else {
        _addBotMessage("❌ Failed to add expense to database.");
      }
    } catch (e) {
      _addBotMessage("⚠️ Error adding expense: $e");
    }
  }

  void _cancelExpense() {
    setState(() {
      _messages.add({
        "sender": "bot",
        "text": "❌ Expense cancelled.",
        "time": DateTime.now().toString(),
      });
      _pendingExpense = null;
    });
  }

  void _addBotMessage(String text, {String type = "normal"}) {
    Future.delayed(const Duration(milliseconds: 600), () {
      setState(() {
        _messages.add({
          "sender": "bot",
          "text": text,
          "type": type,
          "time": DateTime.now().toString(),
        });
        _isTyping = false;
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatTime(String timestamp) {
    final dt = DateTime.tryParse(timestamp);
    if (dt == null) return "";
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        toolbarHeight: 70,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        title: Row(
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              child: Icon(Icons.smart_toy_rounded,
                  color: Colors.blueAccent, size: 24),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Expense Bot",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  "Online • Assistant",
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return const _TypingBubble();
                }

                final msg = _messages[index];
                final isUser = msg["sender"] == "user";

                
                if (msg["type"] == "confirmation") {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(14),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg["text"],
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _confirmExpense,
                                icon: const Icon(Icons.check_circle,
                                    color: Colors.white, size: 18),
                                label: const Text(
                                  "Confirm",
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _cancelExpense,
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text("Cancel"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // 🔸 Normal messages
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
                            horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          gradient: isUser
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xff007BFF),
                                    Color(0xff00A8E8)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isUser ? null : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          msg["text"]!,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: isUser ? Colors.white : Colors.black87,
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

          // 🔹 Input Bar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onLongPressStart: (_) => _startListening(),
                    onLongPressEnd: (_) => _stopListening(),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.redAccent : Colors.grey,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        hintText: "Type a message or hold mic...",
                        border: InputBorder.none,
                        hintStyle:
                            TextStyle(color: Colors.black38, fontSize: 14),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xff007BFF), Color(0xff00A8E8)],
                        ),
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
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

/// Typing animation bubble
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        child: const _TypingDots(),
      ),
    );
  }
}

/// Typing dots animation
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
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: tick == i ? 1.0 : 0.3,
                child: const Text(
                  "•",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
