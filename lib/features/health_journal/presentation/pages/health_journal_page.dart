import 'package:flutter/material.dart';

class HealthJournalPage extends StatefulWidget {
  const HealthJournalPage({super.key});

  @override
  State<HealthJournalPage> createState() => _HealthJournalPageState();
}

class _HealthJournalPageState extends State<HealthJournalPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Dummy data ──────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _bp = [
    {'date': '20 Sep', 'sys': 120, 'dia': 80,  'status': 'Normal',    'note': 'Setelah istirahat'},
    {'date': '21 Sep', 'sys': 135, 'dia': 88,  'status': 'Perhatian', 'note': 'Setelah olahraga'},
    {'date': '22 Sep', 'sys': 118, 'dia': 78,  'status': 'Normal',    'note': 'Pagi hari'},
    {'date': '23 Sep', 'sys': 122, 'dia': 82,  'status': 'Normal',    'note': 'Sebelum makan'},
    {'date': '24 Sep', 'sys': 140, 'dia': 90,  'status': 'Perhatian', 'note': 'Stres kerja'},
    {'date': '25 Sep', 'sys': 119, 'dia': 79,  'status': 'Normal',    'note': 'Setelah meditasi'},
  ];

  final List<Map<String, dynamic>> _bs = [
    {'date': '20 Sep', 'value': 95,  'status': 'Normal',    'note': 'Puasa pagi'},
    {'date': '21 Sep', 'value': 140, 'status': 'Perhatian', 'note': '2 jam setelah makan'},
    {'date': '22 Sep', 'value': 98,  'status': 'Normal',    'note': 'Puasa pagi'},
    {'date': '23 Sep', 'value': 105, 'status': 'Normal',    'note': 'Sebelum sarapan'},
    {'date': '24 Sep', 'value': 155, 'status': 'Perhatian', 'note': 'Setelah makan besar'},
    {'date': '25 Sep', 'value': 92,  'status': 'Normal',    'note': 'Puasa pagi'},
  ];

  final List<Map<String, dynamic>> _wt = [
    {'date': '20 Sep', 'value': 65.5, 'status': 'Normal', 'note': 'Pagi hari'},
    {'date': '21 Sep', 'value': 65.8, 'status': 'Normal', 'note': 'Setelah makan'},
    {'date': '22 Sep', 'value': 65.2, 'status': 'Normal', 'note': 'Setelah olahraga'},
    {'date': '23 Sep', 'value': 65.6, 'status': 'Normal', 'note': 'Pagi hari'},
    {'date': '24 Sep', 'value': 66.0, 'status': 'Normal', 'note': 'Malam hari'},
    {'date': '25 Sep', 'value': 65.4, 'status': 'Normal', 'note': 'Pagi hari'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        title: const Text('Jurnal Kesehatan',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Tek. Darah'),
            Tab(text: 'Gula Darah'),
            Tab(text: 'Berat Badan'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blue.shade700,
        onPressed: () {
          Navigator.pushNamed(context, '/journal/add');
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah', style: TextStyle(color: Colors.white)),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBpTab(),
          _buildBsTab(),
          _buildWtTab(),
        ],
      ),
    );
  }

  // ── Blood Pressure Tab ──────────────────────────────────────────────────────
  Widget _buildBpTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Grafik Tekanan Darah (mmHg)'),
          const SizedBox(height: 8),
          _buildBpChart(),
          const SizedBox(height: 20),
          _sectionTitle('Riwayat Entri'),
          const SizedBox(height: 8),
          ..._bp.map((e) => _bpCard(e)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildBpChart() {
    const maxH = 130.0;
    const maxV = 160.0;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
              children: _bp.map((e) {
                final sH = ((e['sys'] as num) / maxV) * maxH;
                final dH = ((e['dia'] as num) / maxV) * maxH;
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
                            Container(
                              width: 11,
                              height: sH,
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4)),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Container(
                              width: 11,
                              height: dH,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade400,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(e['date'] as String,
                            style: const TextStyle(fontSize: 9),
                            textAlign: TextAlign.center),
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

  Widget _bpCard(Map<String, dynamic> e) {
    final ok = e['status'] == 'Normal';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: ok ? Colors.green.shade100 : Colors.orange.shade100,
          child: Icon(Icons.favorite,
              color: ok ? Colors.green.shade600 : Colors.orange.shade600,
              size: 20),
        ),
        title: Text('${e['sys']}/${e['dia']} mmHg',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(e['note'] as String,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(e['date'] as String,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            _statusChip(e['status'] as String, ok),
          ],
        ),
      ),
    );
  }

  // ── Blood Sugar Tab ─────────────────────────────────────────────────────────
  Widget _buildBsTab() {
    final vals = _bs.map((e) => (e['value'] as int).toDouble()).toList();
    final maxV = vals.reduce((a, b) => a > b ? a : b);
    final minV = vals.reduce((a, b) => a < b ? a : b);
    final range = maxV - minV;
    final heights = vals.map((v) => (v - minV + 20) / (range + 20)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Grafik Gula Darah (mg/dL)'),
          const SizedBox(height: 8),
          _barChart(
            heights: heights,
            valueLabels: vals.map((v) => v.toInt().toString()).toList(),
            dateLabels: _bs.map((e) => e['date'] as String).toList(),
            color: Colors.orange.shade400,
          ),
          const SizedBox(height: 20),
          _sectionTitle('Riwayat Entri'),
          const SizedBox(height: 8),
          ..._bs.map((e) => _genericCard(e, '${e['value']} mg/dL', Icons.water_drop)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Weight Tab ──────────────────────────────────────────────────────────────
  Widget _buildWtTab() {
    final vals = _wt.map((e) => e['value'] as double).toList();
    final maxV = vals.reduce((a, b) => a > b ? a : b);
    final minV = vals.reduce((a, b) => a < b ? a : b);
    final range = maxV - minV;
    final heights = vals.map((v) => (v - minV + 0.3) / (range + 0.3)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Grafik Berat Badan (kg)'),
          const SizedBox(height: 8),
          _barChart(
            heights: heights,
            valueLabels: vals.map((v) => v.toStringAsFixed(1)).toList(),
            dateLabels: _wt.map((e) => e['date'] as String).toList(),
            color: Colors.purple.shade400,
          ),
          const SizedBox(height: 20),
          _sectionTitle('Riwayat Entri'),
          const SizedBox(height: 8),
          ..._wt.map((e) => _genericCard(e, '${e['value']} kg', Icons.monitor_weight)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Bar chart (custom, no external package) ─────────────────────────────────
  Widget _barChart({
    required List<double> heights,       // 0.0 – 1.0
    required List<String> valueLabels,
    required List<String> dateLabels,
    required Color color,
    double maxBarH = 130,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    Text(valueLabels[i],
                        style: const TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Container(
                      height: h,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(5)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(dateLabels[i],
                        style: const TextStyle(fontSize: 9),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Generic entry card ──────────────────────────────────────────────────────
  Widget _genericCard(Map<String, dynamic> e, String valueText, IconData icon) {
    final ok = e['status'] == 'Normal';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: ok ? Colors.green.shade100 : Colors.orange.shade100,
          child: Icon(icon,
              color: ok ? Colors.green.shade600 : Colors.orange.shade600,
              size: 20),
        ),
        title: Text(valueText,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(e['note'] as String,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(e['date'] as String,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            _statusChip(e['status'] as String, ok),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────────
  Widget _sectionTitle(String t) => Text(t,
      style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800));

  Widget _legendDot(Color color, String label) => Row(children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]);

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
