import 'package:flutter/material.dart';

import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/async_state.dart';
import 'package:Telehealth/data/models/journal.dart';
import 'package:Telehealth/data/repositories/journal_repository.dart';

import 'package:Telehealth/features/health_journal/presentation/pages/add_journal_entry_page.dart';

class HealthJournalPage extends StatefulWidget {
  const HealthJournalPage({super.key});

  @override
  State<HealthJournalPage> createState() => _HealthJournalPageState();
}

class _HealthJournalPageState extends State<HealthJournalPage>
    with SingleTickerProviderStateMixin {
  /// Tab tetap untuk tiga metrik utama; datanya diambil dari repository dan
  /// difilter berdasarkan `categoryId`.
  static const List<String> _tabCategoryIds = ['cat1', 'cat2', 'cat3'];

  late TabController _tabController;

  // ── State ───────────────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;
  List<JournalEntry> _entries = <JournalEntry>[];
  List<JournalCategory> _categories = <JournalCategory>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCategoryIds.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entriesFuture = JournalRepository.instance.fetchEntries();
      final categoriesFuture = JournalRepository.instance.fetchCategories();
      final entries = await entriesFuture;
      final categories = await categoriesFuture;
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _categories = categories;
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

  JournalCategory _categoryFor(String id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return JournalRepository.instance.categoryById(id);
  }

  List<JournalEntry> _entriesFor(String categoryId) {
    final list = _entries.where((e) => e.categoryId == categoryId).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Future<void> _openForm({JournalEntry? entry}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddJournalEntryPage(entry: entry)),
    );
    if (result == true && mounted) {
      await _load();
    }
  }

  Future<void> _deleteEntry(JournalEntry entry) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus Catatan',
      message:
          'Yakin ingin menghapus catatan ini? Tindakan ini tidak dapat dibatalkan.',
    );
    if (!confirmed || !mounted) return;

    try {
      await JournalRepository.instance.delete(entry.id);
      if (!mounted) return;
      showAppSnack(context, 'Catatan dihapus');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'Gagal menghapus catatan', success: false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jurnal Kesehatan'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: scheme.onPrimary,
          indicatorWeight: 3,
          labelColor: scheme.onPrimary,
          unselectedLabelColor: scheme.onPrimary.withValues(alpha: 0.6),
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          tabs: _tabCategoryIds.map((id) => Tab(text: _tabLabel(id))).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingView(message: 'Memuat data jurnal...');
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    return TabBarView(
      controller: _tabController,
      children: _tabCategoryIds.map(_buildCategoryTab).toList(),
    );
  }

  Widget _buildCategoryTab(String categoryId) {
    final category = _categoryFor(categoryId);
    final entries = _entriesFor(categoryId);

    if (entries.isEmpty) {
      return EmptyView(
        icon: Icons.assignment_outlined,
        title: 'Belum ada catatan',
        message: 'Tambahkan catatan ${category.name} pertama Anda.',
        actionLabel: 'Tambah Catatan',
        onAction: _openForm,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Grafik ${category.name} (${category.unit})'),
          const SizedBox(height: 8),
          category.isPressure
              ? _pressureChart(entries)
              : _valueChart(entries, category),
          const SizedBox(height: 20),
          _sectionTitle('Riwayat Entri'),
          const SizedBox(height: 8),
          ...entries.reversed.map((e) => _entryCard(e, category)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Charts ──────────────────────────────────────────────────────────────────
  Widget _pressureChart(List<JournalEntry> entries) {
    const maxH = 130.0;
    const maxV = 160.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(Colors.red.shade400, 'Sistolik'),
                const SizedBox(width: 20),
                _legendDot(Colors.blue.shade400, 'Diastolik'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: entries.map((e) {
                final sys = (e.systolic ?? e.value.toInt()).toDouble();
                final dia = (e.diastolic ?? 0).toDouble();
                final sH = (sys / maxV).clamp(0.0, 1.0) * maxH;
                final dH = (dia / maxV).clamp(0.0, 1.0) * maxH;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _bar(11, sH, Colors.red.shade400),
                            const SizedBox(width: 2),
                            _bar(11, dH, Colors.blue.shade400),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _shortDate(e.date),
                          style: const TextStyle(fontSize: 9),
                          textAlign: TextAlign.center,
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
    );
  }

  Widget _valueChart(List<JournalEntry> entries, JournalCategory category) {
    final vals = entries.map((e) => e.value).toList();
    final maxV = vals.reduce((a, b) => a > b ? a : b);
    final minV = vals.reduce((a, b) => a < b ? a : b);
    final pad = category.id == 'cat3' ? 0.3 : 20.0;
    final range = maxV - minV;
    final heights = vals.map((v) => (v - minV + pad) / (range + pad)).toList();
    final decimals = category.id == 'cat3';
    return _barChart(
      heights: heights,
      valueLabels: vals
          .map((v) => decimals ? v.toStringAsFixed(1) : v.toInt().toString())
          .toList(),
      dateLabels: entries.map((e) => _shortDate(e.date)).toList(),
      color: _categoryColor(category.id),
    );
  }

  Widget _barChart({
    required List<double> heights, // 0.0 – 1.0
    required List<String> valueLabels,
    required List<String> dateLabels,
    required Color color,
    double maxBarH = 130,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(heights.length, (i) {
            final h = (heights[i] * maxBarH).clamp(8.0, maxBarH);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      valueLabels[i],
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      height: h,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabels[i],
                      style: const TextStyle(fontSize: 9),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _bar(double width, double height, Color color) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    ),
  );

  // ── Entry card with Edit / Delete ───────────────────────────────────────────
  Widget _entryCard(JournalEntry e, JournalCategory category) {
    final scheme = Theme.of(context).colorScheme;
    final ok = e.status == 'Normal';
    final valueText = category.isPressure
        ? '${e.systolic ?? e.value.toInt()}/${e.diastolic ?? '-'} ${category.unit}'
        : '${_formatValue(e.value, category)} ${category.unit}';
    final icon = category.isPressure
        ? Icons.favorite
        : _categoryIcon(category.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: ok
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  child: Icon(
                    icon,
                    color: ok ? Colors.green.shade600 : Colors.orange.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        valueText,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (e.note.trim().isNotEmpty)
                        Text(
                          e.note,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(e.date),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip(e.status, ok),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _openForm(entry: e),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(foregroundColor: scheme.primary),
                ),
                TextButton.icon(
                  onPressed: () => _deleteEntry(e),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Hapus'),
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String _tabLabel(String id) {
    switch (id) {
      case 'cat1':
        return 'Tek. Darah';
      case 'cat2':
        return 'Gula Darah';
      case 'cat3':
        return 'Berat Badan';
      default:
        return _categoryFor(id).name;
    }
  }

  Color _categoryColor(String id) {
    switch (id) {
      case 'cat1':
        return Colors.red.shade400;
      case 'cat2':
        return Colors.orange.shade400;
      case 'cat3':
        return Colors.purple.shade400;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _categoryIcon(String id) {
    switch (id) {
      case 'cat2':
        return Icons.water_drop;
      case 'cat3':
        return Icons.monitor_weight;
      case 'cat4':
        return Icons.thermostat;
      case 'cat5':
        return Icons.monitor_heart;
      default:
        return Icons.insights;
    }
  }

  String _formatValue(double v, JournalCategory category) =>
      category.id == 'cat3' ? v.toStringAsFixed(1) : v.toInt().toString();

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  Widget _sectionTitle(String t) => Text(
    t,
    style: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.bold,
      color: Colors.grey.shade800,
    ),
  );

  Widget _legendDot(Color color, String label) => Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );

  Widget _statusChip(String status, bool ok) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: ok ? Colors.green.shade100 : Colors.orange.shade100,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      status,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: ok ? Colors.green.shade700 : Colors.orange.shade700,
      ),
    ),
  );
}
