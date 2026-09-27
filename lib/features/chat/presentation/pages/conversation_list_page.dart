import 'package:flutter/material.dart';

class ConversationListPage extends StatefulWidget {
  const ConversationListPage({super.key});

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Dummy data ─────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _conversations = [
    {
      'name': 'Dr. Ahmad Fauzi',
      'role': 'Dokter',
      'type': 'dokter',
      'lastMessage':
          'Baik, jangan lupa minum obat secara teratur ya dan kontrol lagi minggu depan.',
      'time': '10:30',
      'unreadCount': 2,
      'isOnline': true,
      'initials': 'AF',
      'color': const Color(0xFFE53935),
    },
    {
      'name': 'Dr. Siti Rahma',
      'role': 'Dokter',
      'type': 'dokter',
      'lastMessage':
          'Hasil lab sudah saya terima, hasilnya normal semua. Tidak perlu khawatir.',
      'time': '09:15',
      'unreadCount': 0,
      'isOnline': true,
      'initials': 'SR',
      'color': const Color(0xFF1E88E5),
    },
    {
      'name': 'Budi (Ayah)',
      'role': 'Keluarga',
      'type': 'keluarga',
      'lastMessage':
          'Sudah ke dokter tadi pagi, katanya harus istirahat total selama 3 hari.',
      'time': 'Kemarin',
      'unreadCount': 1,
      'isOnline': false,
      'initials': 'B',
      'color': const Color(0xFF43A047),
    },
    {
      'name': 'Dr. Dewi Kusuma',
      'role': 'Dokter',
      'type': 'dokter',
      'lastMessage':
          'Silakan kirimkan foto kulit yang bermasalah agar saya bisa mengevaluasi.',
      'time': 'Kemarin',
      'unreadCount': 0,
      'isOnline': false,
      'initials': 'DK',
      'color': const Color(0xFF8E24AA),
    },
    {
      'name': 'Rina (Ibu)',
      'role': 'Keluarga',
      'type': 'keluarga',
      'lastMessage':
          'Jangan lupa jadwal kontrol minggu depan ya, sudah saya daftarkan.',
      'time': 'Selasa',
      'unreadCount': 3,
      'isOnline': true,
      'initials': 'R',
      'color': const Color(0xFFFF8F00),
    },
    {
      'name': 'Dr. Rizky Pratama',
      'role': 'Dokter',
      'type': 'dokter',
      'lastMessage':
          'Tensi darah Anda masih perlu dipantau setiap hari. Catat hasilnya.',
      'time': 'Senin',
      'unreadCount': 0,
      'isOnline': false,
      'initials': 'RP',
      'color': const Color(0xFF00897B),
    },
  ];

  // ── filtering ──────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _getList(String type) {
    return _conversations.where((c) {
      final matchType = type == 'semua' || c['type'] == type;
      final matchSearch = _searchQuery.isEmpty ||
          (c['name'] as String)
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          (c['lastMessage'] as String)
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      return matchType && matchSearch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Pesan',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Cari percakapan...',
                    hintStyle:
                        TextStyle(color: Colors.grey[400], fontSize: 14),
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon:
                                const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // TabBar
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _ConversationTab(conversations: _getList('semua')),
          _ConversationTab(conversations: _getList('dokter')),
          _ConversationTab(
            conversations: _getList('keluarga'),
            emptyLabel: 'Belum ada percakapan keluarga',
            emptySubLabel: 'Tambahkan anggota keluarga untuk mulai chat',
            emptyIcon: Icons.family_restroom,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/doctors');
        },
        backgroundColor: const Color(0xFF2196F3),
        child: const Icon(Icons.chat_rounded, color: Colors.white),
      ),
    );
  }
}

// ─── Tab content widget ───────────────────────────────────────────────────────

class _ConversationTab extends StatelessWidget {
  final List<Map<String, dynamic>> conversations;
  final String emptyLabel;
  final String emptySubLabel;
  final IconData emptyIcon;

  const _ConversationTab({
    required this.conversations,
    this.emptyLabel = 'Belum ada percakapan',
    this.emptySubLabel = 'Mulai percakapan baru',
    this.emptyIcon = Icons.chat_bubble_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              emptyLabel,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubLabel,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: conversations.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 80, endIndent: 16),
      itemBuilder: (context, index) =>
          _ConversationItem(conversation: conversations[index]),
    );
  }
}

// ─── Single conversation row ──────────────────────────────────────────────────

class _ConversationItem extends StatelessWidget {
  final Map<String, dynamic> conversation;

  const _ConversationItem({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final color = conversation['color'] as Color;
    final bool isOnline = conversation['isOnline'] as bool;
    final int unread = conversation['unreadCount'] as int;
    final bool isDoctor = conversation['type'] == 'dokter';

    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Membuka chat dengan ${conversation['name']}'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        color: unread > 0
            ? const Color(0xFFF0F7FF)
            : Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Avatar + online indicator ────────────────────────────────
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: color.withOpacity(0.15),
                  child: Text(
                    conversation['initials'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 2),
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
                          conversation['name'] as String,
                          style: TextStyle(
                            fontWeight: unread > 0
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        conversation['time'] as String,
                        style: TextStyle(
                          color: unread > 0
                              ? const Color(0xFF2196F3)
                              : Colors.grey,
                          fontSize: 12,
                          fontWeight: unread > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 3),

                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDoctor
                          ? const Color(0xFFE3F2FD)
                          : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      conversation['role'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDoctor
                            ? const Color(0xFF1565C0)
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),

                  // Last message + unread badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          conversation['lastMessage'] as String,
                          style: TextStyle(
                            color: unread > 0
                                ? Colors.black87
                                : Colors.grey[500],
                            fontSize: 13,
                            fontWeight: unread > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints:
                              const BoxConstraints(minWidth: 20),
                          height: 20,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              unread.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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
