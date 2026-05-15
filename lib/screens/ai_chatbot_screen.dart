import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/constants/app_colors.dart';
import '../services/ai_service.dart';

class AiChatbotScreen extends ConsumerStatefulWidget {
  const AiChatbotScreen({super.key});

  @override
  ConsumerState<AiChatbotScreen> createState() => _AiChatbotScreenState();
}

class _AiChatbotScreenState extends ConsumerState<AiChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;
  final List<Map<String, dynamic>> _messages = [
    {
      'isUser': false,
      'text':
          'Hello! I am your AI Botanical Assistant. How can I help your garden flourish today?',
      'time': '10:00 AM',
    }
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    setState(() {
      _messages.add({
        'isUser': true,
        'text': userMessage,
        'time': _timeLabel(),
      });
      _messageController.clear();
      _isSending = true;
    });

    try {
      final conversation = _messages
          .map((message) => {
                'role': message['isUser'] == true ? 'user' : 'assistant',
                'content': message['text'].toString(),
              })
          .toList();
      final answer = await ref.read(aiServiceProvider).askBot(conversation);
      if (!mounted) return;
      setState(() {
        _messages.add({
          'isUser': false,
          'text': answer,
          'time': _timeLabel(),
        });
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'isUser': false,
          'text': error.toString(),
          'time': _timeLabel(),
        });
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.lightGreen,
              radius: 16,
              child:
                  Icon(LucideIcons.bot, color: AppColors.forestGreen, size: 20),
            ),
            SizedBox(width: 12),
            Text('Botanical Assistant'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Pre-defined question chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildSuggestionChip('Why are my leaves yellow?'),
                _buildSuggestionChip('Is this toxic to cats?'),
                _buildSuggestionChip('How often should I water?'),
              ],
            ),
          ),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(
                  text: message['text'],
                  isUser: message['isUser'],
                  time: message['time'],
                ).animate().fadeIn().slideY(begin: 0.2, end: 0);
              },
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              boxShadow: [
                BoxShadow(
                  color: AppColors.softBlack.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.paperclip,
                        color: AppColors.forestGreen),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.offWhite,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Ask about your plants...',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.emeraldGreen,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.pureWhite,
                              ),
                            )
                          : const Icon(LucideIcons.send,
                              color: AppColors.pureWhite, size: 20),
                      onPressed: _isSending ? null : _sendMessage,
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

  Widget _buildSuggestionChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(text),
        backgroundColor: AppColors.pureWhite,
        side: BorderSide(color: AppColors.emeraldGreen.withOpacity(0.3)),
        onPressed: _isSending
            ? null
            : () {
                _messageController.text = text;
                _sendMessage();
              },
      ),
    );
  }

  String _timeLabel() {
    final now = TimeOfDay.now();
    final hour = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildMessageBubble(
      {required String text, required bool isUser, required String time}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              backgroundColor: AppColors.emeraldGreen,
              radius: 12,
              child:
                  Icon(LucideIcons.bot, color: AppColors.pureWhite, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.emeraldGreen : AppColors.pureWhite,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight: isUser ? const Radius.circular(0) : null,
                  bottomLeft: !isUser ? const Radius.circular(0) : null,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.softBlack.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? AppColors.pureWhite : AppColors.softBlack,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser)
            const SizedBox(width: 48)
          else
            const SizedBox(width: 48), // Spacing for layout
        ],
      ),
    );
  }
}
