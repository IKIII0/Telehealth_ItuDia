import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/async_state.dart';
import 'package:Telehealth/data/models/chat_message.dart';
import 'package:Telehealth/data/models/conversation.dart';
import 'package:Telehealth/data/repositories/chat_repository.dart';
import 'package:flutter/material.dart';

/// Ruang percakapan: menampilkan gelembung pesan antara pengguna
/// dengan dokter atau keluarga.
class ChatRoomPage extends StatefulWidget {
  const ChatRoomPage({super.key, required this.conversation});

  final Conversation conversation;

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  String? _error;
  bool _sending = false;
  List<ChatMessage> _messages = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await ChatRepository.instance.fetchMessages(
        widget.conversation.id,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final message = await ChatRepository.instance.send(
        widget.conversation.id,
        text,
      );
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, message];
        _sending = false;
      });
      _controller.clear();
      _scrollToBottom();
      _replyLater();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showAppSnack(context, 'Gagal mengirim pesan', success: false);
    }
  }

  Future<void> _replyLater() async {
    try {
      final reply = await ChatRepository.instance.autoReply(
        widget.conversation.id,
      );
      if (!mounted) return;
      setState(() => _messages = [..._messages, reply]);
      _scrollToBottom();
    } catch (_) {
      // Balasan otomatis diabaikan bila gagal.
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final conversation = widget.conversation;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _HeaderAvatar(conversation: conversation),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    conversation.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: conversation.isOnline
                              ? Colors.greenAccent
                              : Colors.white54,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${conversation.role} • '
                        '${conversation.isOnline ? 'Online' : 'Offline'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(scheme)),
          _buildComposer(scheme),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading) {
      return const LoadingView(message: 'Memuat percakapan...');
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_messages.isEmpty) {
      return const EmptyView(
        icon: Icons.chat_bubble_outline,
        title: 'Belum ada pesan',
        message: 'Mulai percakapan dengan mengirim pesan pertama.',
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _MessageBubble(
        message: _messages[index],
        conversation: widget.conversation,
      ),
    );
  }

  Widget _buildComposer(ColorScheme scheme) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Tulis pesan...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF0F2F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: scheme.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 46,
              height: 46,
              child: FilledButton(
                onPressed: _sending ? null : _send,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 4),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white24,
        child: Text(
          conversation.initials,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.conversation});

  final ChatMessage message;
  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMe = message.isMe;
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.72;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: conversation.color.withValues(alpha: 0.15),
              child: Text(
                conversation.initials,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: conversation.color,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? scheme.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.text,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.time,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
