import 'package:flutter/material.dart';
import '../../models/account.dart';
import '../../models/product.dart';
import '../../services/ai_service.dart';

class _ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final List<dynamic>? products;

  _ChatMessage({required this.role, required this.content, this.products});
}

class AiChatScreen extends StatefulWidget {
  final Account account;
  final List<Product> products;

  const AiChatScreen({
    super.key,
    required this.account,
    required this.products,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Seed a greeting from the assistant
    _messages.add(
      _ChatMessage(
        role: 'assistant',
        content:
            'Hi! 👋 I\'m the shopping assistant for ${widget.account.name}. '
            'Ask me anything — what\'s available, prices, recommendations, or what goes well together!',
      ),
    );
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isLoading) return;

    _inputCtrl.clear();
    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      // Build history for the API (exclude the greeting which was client-only)
      final history = _messages
          .where((m) => !(m.role == 'assistant' && _messages.indexOf(m) == 0))
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final response = await AiService.shopAssistant(
        messages: history,
        products: widget.products,
        orgName: widget.account.name,
      );

      if (!mounted) return;
      setState(
        () => _messages.add(
          _ChatMessage(
            role: 'assistant',
            content: response['reply'] ?? '',
            products: response['products'] ?? [],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _messages.add(
          _ChatMessage(
            role: 'assistant',
            content:
                'Sorry, I couldn\'t get a response right now. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inStock = widget.products.where((p) => p.isAvailable).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Shopping Assistant',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              '${widget.account.name} · $inStock items in stock',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _TypingIndicator();
                }
                final msg = _messages[index];
                return _MessageBubble(message: msg);
              },
            ),
          ),
          _buildInputBar(theme),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Ask about products…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.amber,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _isLoading ? null : _sendMessage,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.send_rounded, color: Colors.black, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.amber,
              child: const Icon(
                Icons.auto_awesome,
                size: 14,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? Colors.amber
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser
                          ? Colors.black
                          : theme.colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),

                  if (message.products != null && message.products!.isNotEmpty)
                    Column(
                      children: message.products!.map((p) {
                        final image =
                            p['image'] ?? p['imageUrl'] ?? p['image_url'];
                        debugPrint('IMAGE URL => $image');
                        return Card(
                          margin: const EdgeInsets.only(top: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                if (image != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      image,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.image_not_supported),
                                    ),
                                  ),

                                const SizedBox(width: 8),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(p['name'] ?? ''),
                                      if (p['priceUsd'] != null)
                                        Text(
                                          '\$${p['priceUsd']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.7),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.amber,
            child: const Icon(
              Icons.auto_awesome,
              size: 14,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i * 0.15;
                    final opacity = (((_ctrl.value + delay) % 1.0) < 0.5)
                        ? 1.0
                        : 0.3;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Opacity(
                        opacity: opacity,
                        child: const CircleAvatar(
                          radius: 4,
                          backgroundColor: Colors.grey,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
