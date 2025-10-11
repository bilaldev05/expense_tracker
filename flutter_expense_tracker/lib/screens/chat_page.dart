import 'dart:convert';
import 'package:flutter/material.dart';
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
  final String apiUrl = "http://localhost:8000/chat-expense";

  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isTyping = false;

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
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final parsed = data["data"];

        String reply =
            "✅ Added *${parsed['title']}* of **${parsed['amount']} Rs** under *${parsed['category']}* on ${parsed['date']}.";

        _addBotMessage(reply);
      } else {
        _addBotMessage("❌ Failed to add expense. Please try again.");
      }
    } catch (e) {
      _addBotMessage("⚠️ Error: $e");
    }
  }

  void _addBotMessage(String text) {
    Future.delayed(const Duration(milliseconds: 600), () {
      setState(() {
        _messages.add({
          "sender": "bot",
          "text": text,
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

          // --- Message Input Bar ---
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

/// Typing bubble for bot
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

/// Typing animation dots
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
