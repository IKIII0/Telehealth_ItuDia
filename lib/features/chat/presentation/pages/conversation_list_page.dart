import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/core/widgets/role_badge.dart';
import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/async_state.dart';
import 'package:Telehealth/core/widgets/patient_nav_bar.dart';
import 'package:Telehealth/data/models/conversation.dart';
import 'package:Telehealth/data/repositories/conversation_repository.dart';

class ConversationListPage extends StatefulWidget {
  const ConversationListPage({super.key, this.showNavBar = false});

  final bool showNavBar;

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _loading = true;
  String? _error;
  List<Conversation> _conversations = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final conversations = await ConversationRepository.instance.fetchAll();
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── filtering ────────────────────────────────────────────────────────────

  List<Conversation> _getList(String type) {
    return _conversations.where((c) {
      final matchType = type == 'semua' || c.type == type;
      final matchSearch =
          _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.lastMessage.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchType && matchSearch;
    }).toList();
  }

  void _resetSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  // ── actions ────────────────────────────────────────────────────────────────

  Future<void> _deleteConversation(Conversation conversation) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus Percakapan',
      message: 'Hapus percakapan dengan ${conversation.name}?',
    );
    if (!confirmed || !mounted) return;

    try {
      await ConversationRepository.instance.delete(conversation.id);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      showAppSnack(context, 'Percakapan dihapus');
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'Gagal menghapus percakapan', success: false);
    }
  }

  void _openConversation(Conversation conversation) {
    context.pushNamed(
      AppRoutes.patientChatRoomName,
      pathParameters: {'conversationId': conversation.id},
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Pesan',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: scheme.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: const [RoleBadge.patient()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Cari percakapan...',
                    hintStyle: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13.5,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.grey[500],
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: Colors.grey[500],
                              size: 18,
                            ),
                            onPressed: _resetSearch,
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // TabBar
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'Semua'),
                  Tab(text: 'Dokter'),
                  Tab(text: 'Keluarga'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: widget.showNavBar
          ? const PatientNavBar(currentIndex: 2)
          : null,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.pushNamed(AppRoutes.patientDoctorsName);
        },
        backgroundColor: scheme.primary,
        elevation: 2,
        child: const Icon(Icons.chat_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingView(message: 'Memuat percakapan...');
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    final isSearching = _searchQuery.isNotEmpty;
    return TabBarView(
      controller: _tabController,
      children: [
        _ConversationTab(
          conversations: _getList('semua'),
          isSearching: isSearching,
          onResetSearch: _resetSearch,
          onOpen: _openConversation,
          onDelete: _deleteConversation,
        ),
        _ConversationTab(
          conversations: _getList('dokter'),
          isSearching: isSearching,
          onResetSearch: _resetSearch,
          onOpen: _openConversation,
          onDelete: _deleteConversation,
          emptyLabel: 'Belum ada percakapan dokter',
          emptySubLabel: 'Mulai konsultasi dengan dokter',
          emptyIcon: Icons.medical_services_outlined,
        ),
        _ConversationTab(
          conversations: _getList('keluarga'),
          isSearching: isSearching,
          onResetSearch: _resetSearch,
          onOpen: _openConversation,
          onDelete: _deleteConversation,
          emptyLabel: 'Belum ada percakapan keluarga',
          emptySubLabel: 'Tambahkan anggota keluarga untuk mulai chat',
          emptyIcon: Icons.family_restroom,
        ),
      ],
    );
  }
}

// ─── Tab content widget ───────────────────────────────────────────────────────

class _ConversationTab extends StatelessWidget {
  final List<Conversation> conversations;
  final bool isSearching;
  final VoidCallback onResetSearch;
  final void Function(Conversation) onOpen;
  final void Function(Conversation) onDelete;
  final String emptyLabel;
  final String emptySubLabel;
  final IconData emptyIcon;

  const _ConversationTab({
    required this.conversations,
    required this.isSearching,
    required this.onResetSearch,
    required this.onOpen,
    required this.onDelete,
    this.emptyLabel = 'Belum ada percakapan',
    this.emptySubLabel = 'Mulai percakapan baru',
    this.emptyIcon = Icons.chat_bubble_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      if (isSearching) {
        return EmptyView(
          icon: Icons.search_off,
          title: 'Percakapan tidak ditemukan',
          message: 'Coba kata kunci lain',
          actionLabel: 'Reset Pencarian',
          onAction: onResetSearch,
        );
      }
      return EmptyView(
        icon: emptyIcon,
        title: emptyLabel,
        message: emptySubLabel,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 96),
      itemCount: conversations.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 72,
        endIndent: 16,
        color: Colors.grey.shade100,
      ),
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return _ConversationItem(
          conversation: conversation,
          onOpen: () => onOpen(conversation),
          onDelete: () => onDelete(conversation),
        );
      },
    );
  }
}

// ─── Single conversation row ──────────────────────────────────────────────────

class _ConversationItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _ConversationItem({
    required this.conversation,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool isOnline = conversation.isOnline;
    final int unread = conversation.unreadCount;

    return InkWell(
      onTap: onOpen,
      onLongPress: onDelete,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Avatar + online indicator ────────────────────────────────
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: scheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    conversation.initials,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // ── Text content ─────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + timestamp
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          conversation.name,
                          style: TextStyle(
                            fontWeight: unread > 0
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: 14.5,
                            color: Colors.grey.shade900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        conversation.time,
                        style: TextStyle(
                          color: unread > 0
                              ? scheme.primary
                              : Colors.grey.shade500,
                          fontSize: 11,
                          fontWeight: unread > 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 3),

                  // Last message + unread badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage,
                          style: TextStyle(
                            color: unread > 0
                                ? Colors.grey.shade800
                                : Colors.grey.shade600,
                            fontSize: 12.5,
                            fontWeight: unread > 0
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(minWidth: 18),
                          height: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Center(
                            child: Text(
                              unread.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
