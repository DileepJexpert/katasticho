import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/ai_repository.dart';

/// Chat message model.
class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Map<String, dynamic>? data; // Structured data (tables, charts)

  _ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.data,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      text: "Hi! I'm your AI assistant. Ask me anything about your business finances.\n\n"
          "Try:\n"
          "- \"What's my total revenue this month?\"\n"
          "- \"Show me overdue invoices\"\n"
          "- \"What's my cash balance?\"\n"
          "- \"Compare this month vs last month\"",
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final aiRepo = ref.read(aiRepositoryProvider);
      final response = await aiRepo.query(text);
      final data = response['data'] as Map<String, dynamic>?;

      setState(() {
        _messages.add(_ChatMessage(
          text: data?['answer'] as String? ?? 'I couldn\'t process that query.',
          isUser: false,
          data: data?['results'] as Map<String, dynamic>?,
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: 'Sorry, I encountered an error. Please try again.',
          isUser: false,
        ));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: KColors.accent.withValues(alpha: 0.15),
                borderRadius: KSpacing.borderRadiusSm,
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 20, color: KColors.accent),
            ),
            KSpacing.hGapSm,
            const Text('AI Assistant'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(_ChatMessage(
                  text: "Chat cleared. How can I help you?",
                  isUser: false,
                ));
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: KSpacing.pagePadding,
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return const _TypingIndicator();
                }
                return _ChatBubble(message: _messages[index]);
              },
            ),
          ),

          // Quick suggestions
          if (_messages.length <= 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
              child: Row(
                children: [
                  _SuggestionChip(
                    label: 'Revenue this month',
                    onTap: () {
                      _messageController.text =
                          "What's my total revenue this month?";
                      _sendMessage();
                    },
                  ),
                  _SuggestionChip(
                    label: 'Overdue invoices',
                    onTap: () {
                      _messageController.text = 'Show me overdue invoices';
                      _sendMessage();
                    },
                  ),
                  _SuggestionChip(
                    label: 'Profit this quarter',
                    onTap: () {
                      _messageController.text =
                          "What's my profit this quarter?";
                      _sendMessage();
                    },
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.all(KSpacing.sm),
            decoration: BoxDecoration(
              color: KColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined),
                    color: KColors.textSecondary,
                    onPressed: () {
                      // Bill scanning placeholder
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Ask about your finances...',
                        border: OutlineInputBorder(
                          borderRadius: KSpacing.borderRadiusXl,
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: KColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  KSpacing.hGapSm,
                  Container(
                    decoration: const BoxDecoration(
                      color: KColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
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

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: KColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 16, color: KColors.accent),
            ),
            KSpacing.hGapSm,
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? KColors.primary
                    : KColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  if (!isUser)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                ],
              ),
              child: Text(
                message.text,
                style: KTypography.bodyMedium.copyWith(
                  color: isUser ? Colors.white : KColors.textPrimary,
                ),
              ),
            ),
          ),
          if (isUser) KSpacing.hGapSm,
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: KColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome,
                size: 16, color: KColors.accent),
          ),
          KSpacing.hGapSm,
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                _Dot(delay: 1),
                _Dot(delay: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    Future.delayed(Duration(milliseconds: widget.delay * 200), () {
      if (mounted) _controller.forward();
    });
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
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: KColors.textHint.withValues(alpha: _controller.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ActionChip(
        label: Text(label, style: KTypography.labelMedium),
        backgroundColor: KColors.primary.withValues(alpha: 0.06),
        side: const BorderSide(color: KColors.primary, width: 0.5),
        onPressed: onTap,
      ),
    );
  }
}
