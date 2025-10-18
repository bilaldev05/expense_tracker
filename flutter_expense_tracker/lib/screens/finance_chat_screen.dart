import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FinanceChatScreen extends StatefulWidget {
  const FinanceChatScreen({super.key});

  @override
  State<FinanceChatScreen> createState() => _FinanceChatScreenState();
}

class _FinanceChatScreenState extends State<FinanceChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;

  // 🌐 Send message to FastAPI backend
  Future<String> sendMessageToBackend(String message) async {
    const String apiUrl = "http://localhost:8000/ai-chat"; // update if needed

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"message": message}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["response"] ?? "No response received.";
    } else {
      return "Error: ${response.statusCode}";
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _controller.clear();
      _isTyping = true;
    });

    final reply = await sendMessageToBackend(text);

    setState(() {
      _messages.add({'role': 'assistant', 'content': reply});
      _isTyping = false;
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _chatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF007BFF), Color(0xFF0059B3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFE9F3FF), Color(0xFFD6E6FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: isUser
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.black12.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(2, 3),
            )
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 15.5,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF007BFF), Color(0xFF0059B3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Finance Chatbot 💬',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 10, bottom: 10),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _chatBubble(msg['content']!, msg['role'] == 'user');
              },
            ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                "Typing...",
                style:
                    TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
          SafeArea(
            child: Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Ask about your expenses or advice...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF007BFF), Color(0xFF0059B3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
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
