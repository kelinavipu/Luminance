import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../dashboard/dashboard_data_service.dart';
import '../../utils/time_utils.dart';

class AiGuidanceScreen extends StatefulWidget {
  const AiGuidanceScreen({super.key});

  @override
  State<AiGuidanceScreen> createState() => _AiGuidanceScreenState();
}

class _AiGuidanceScreenState extends State<AiGuidanceScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DashboardDataService _dataService = DashboardDataService();
  
  final List<Message> _messages = [
    Message(
      text: 'Hello! I am DigiGuide. I can help you understand your digital habits and find balance. What\'s on your mind?',
      isUser: false,
    ),
  ];
  bool _isLoading = false;

  final String _groqApiKey = "YOUR_GROQ_KEY_HERE";

  @override
  void initState() {
    super.initState();
    _dataService.loadAllData(); // Pre-load stats for context
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    
    final userText = _controller.text;
    setState(() {
      _messages.add(Message(text: userText, isUser: true));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      // Build context string
      final topAppsStr = _dataService.topAppUsage.entries
          .take(5)
          .map((e) => "${e.key} (${TimeUtils.formatMinutes(e.value)})")
          .join(", ");
      
      final contextMsg = "Current Time: ${DateTime.now().toString()}. "
          "User Stats today: Total Time: ${TimeUtils.formatMinutes(_dataService.totalScreenTimeHours)}, "
          "Unlocks: ${_dataService.unlockCount}, Guilt Index: ${_dataService.guiltIndex.toStringAsFixed(1)}%, "
          "Top Apps: $topAppsStr. "
          "Guilt logic: Weighted composite of goal overshoot, late-night usage, and negative app categories.";

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': [
            {
              'role': 'system',
              'content': 'You are DigiGuide, a supportive digital wellbeing coach. '
                  'Context: $contextMsg. '
                  'Help users manage mobile addiction with practical, empathetic advice. '
                  'Use the provided stats to give specific insights. Keep responses under 4 sentences.'
            },
            ..._messages.map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text
            }),
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices'][0]['message']['content'];
        setState(() {
          _messages.add(Message(text: reply.trim(), isUser: false));
        });
      } else {
        print("Groq Chat Error: ${response.statusCode} ${response.body}");
        setState(() {
          _messages.add(Message(text: "I'm having trouble connecting to my brain right now. Please check your connection.", isUser: false));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(Message(text: "Sorry, I hit a snag. Let's try again in a moment.", isUser: false));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Guidance'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg, primary, isDark);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          _buildInputArea(primary, isDark),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, Color primary, bool isDark) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: msg.isUser ? primary : (isDark ? Colors.grey[850] : Colors.grey[200]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: msg.isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: msg.isUser ? Radius.zero : const Radius.circular(16),
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: msg.isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(Color primary, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Type your message...',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            icon: Icon(Icons.send, color: primary),
          ),
        ],
      ),
    );
  }
}

class Message {
  final String text;
  final bool isUser;
  Message({required this.text, required this.isUser});
}
