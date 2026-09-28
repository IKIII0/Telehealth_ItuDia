import 'package:flutter/material.dart';

import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/async_state.dart';
import 'package:Telehealth/data/repositories/simulated_api.dart';

class SymptomCheckerPage extends StatefulWidget {
  const SymptomCheckerPage({super.key});

  @override
  State<SymptomCheckerPage> createState() => _SymptomCheckerPageState();
}

class _SymptomCheckerPageState extends State<SymptomCheckerPage> {
  // ── Multi-step state ────────────────────────────────────────────────────────
  int _currentStep = 0;
  bool _showResult = false;

  // ── Analisis async ──────────────────────────────────────────────────────────
  bool _loading = false;
  String? _error;
  List<Map<String, String>>? _analysis;

  // ── Step 1 ──────────────────────────────────────────────────────────────────
  String? _selectedArea;
  static const List<Map<String, dynamic>> _areas = [
    {'name': 'Kepala', 'icon': Icons.face_outlined},
    {'name': 'Dada', 'icon': Icons.favorite_border},
    {'name': 'Perut', 'icon': Icons.crop_square_outlined},
    {'name': 'Tangan', 'icon': Icons.back_hand_outlined},
    {'name': 'Kaki', 'icon': Icons.directions_walk},
  ];

  // ── Step 2 ──────────────────────────────────────────────────────────────────
  final Set<String> _selectedSymptoms = {};
  static const List<String> _allSymptoms = [
    'Sakit kepala',
    'Demam tinggi',
    'Batuk kering',
    'Batuk berdahak',
    'Pilek / hidung tersumbat',
    'Mual',
    'Muntah',
    'Nyeri dada',
    'Sesak napas',
    'Pusing / vertigo',
    'Kelelahan berlebih',
    'Nyeri otot / sendi',
  ];

  // ── Step 3 ──────────────────────────────────────────────────────────────────
  double _severity = 5;
  String _duration = 'Kurang dari 1 hari';
  static const List<String> _durationOpts = [
    'Kurang dari 1 hari',
    '1–3 hari',
    '4–7 hari',
    '1–2 minggu',
    'Lebih dari 2 minggu',
  ];
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Urgency ─────────────────────────────────────────────────────────────────
  String get _urgency {
    if (_severity >= 8) return 'Tinggi';
    if (_severity >= 5) return 'Sedang';
    return 'Rendah';
  }

  Color get _urgencyColor {
    if (_severity >= 8) return Colors.red;
    if (_severity >= 5) return Colors.orange;
    return Colors.green;
  }

  // ── Navigation ───────────────────────────────────────────────────────────────
  void _next() {
    if (_currentStep == 0) {
      if (_selectedArea == null) {
        _snack('Pilih area tubuh terlebih dahulu');
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (_selectedSymptoms.isEmpty) {
        _snack('Pilih minimal satu gejala');
        return;
      }
      setState(() => _currentStep = 2);
    } else {
      _analyze();
    }
  }

  /// Menjalankan analisis gejala secara asinkron (dengan jeda simulasi).
  Future<void> _analyze() async {
    if (_selectedSymptoms.isEmpty) {
      setState(() => _showResult = true);
      _snack('Pilih minimal satu gejala terlebih dahulu');
      return;
    }

    setState(() {
      _showResult = true;
      _loading = true;
      _error = null;
      _analysis = null;
    });

    try {
      final result = await SimulatedApi.run(_buildAnalysis);
      if (!mounted) return;
      setState(() {
        _analysis = result;
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

  List<Map<String, String>> _buildAnalysis() {
    return const [
      {
        'name': 'Flu / Influenza',
        'prob': '75%',
        'desc': 'Infeksi virus pada saluran pernapasan',
      },
      {
        'name': 'Common Cold',
        'prob': '60%',
        'desc': 'Infeksi ringan saluran pernapasan atas',
      },
      {
        'name': 'Kelelahan Umum',
        'prob': '45%',
        'desc': 'Kondisi akibat kurang istirahat & stres',
      },
    ];
  }

  void _back() {
    setState(() {
      if (_showResult) {
        _showResult = false;
      } else if (_currentStep > 0) {
        _currentStep--;
      }
    });
  }

  void _restart() {
    setState(() {
      _currentStep = 0;
      _showResult = false;
      _selectedArea = null;
      _selectedSymptoms.clear();
      _severity = 5;
      _duration = _durationOpts.first;
      _noteCtrl.clear();
      _loading = false;
      _error = null;
      _analysis = null;
    });
  }

  void _snack(String msg) {
    showAppSnack(context, msg, success: false);
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        title: const Text(
          'Cek Gejala',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(child: _showResult ? _buildResult() : _buildCurrentStep()),
          _buildNavBar(),
        ],
      ),
    );
  }

  // ── Step indicator ───────────────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    final labels = ['Area Tubuh', 'Gejala', 'Detail'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            _stepCircle(i, labels[i]),
            if (i < labels.length - 1) _connector(i),
          ],
        ],
      ),
    );
  }

  Widget _stepCircle(int index, String label) {
    final scheme = Theme.of(context).colorScheme;
    final isDone = index < _currentStep || _showResult;
    final isActive = index == _currentStep && !_showResult;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? Colors.green
                : isActive
                ? scheme.primary
                : Colors.grey.shade300,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
            color: isActive
                ? scheme.primary
                : isDone
                ? Colors.green
                : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _connector(int index) {
    final isPassed = index < _currentStep || _showResult;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 22),
        color: isPassed ? Colors.green : Colors.grey.shade300,
      ),
    );
  }

  // ── Steps ────────────────────────────────────────────────────────────────────
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      default:
        return _buildStep3();
    }
  }

  // Step 1 – Body area
  Widget _buildStep1() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle('Pilih Area Tubuh yang Bermasalah'),
          _stepSubtitle('Pilih bagian tubuh yang paling terasa tidak nyaman'),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: _areas.map((area) {
              final isSelected = _selectedArea == area['name'];
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedArea = area['name'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? scheme.primaryContainer : Colors.white,
                    border: Border.all(
                      color: isSelected ? scheme.primary : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? scheme.primary.withValues(alpha: 0.2)
                            : Colors.black12,
                        blurRadius: isSelected ? 10 : 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        area['icon'] as IconData,
                        size: 28,
                        color: isSelected
                            ? scheme.primary
                            : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        area['name'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? scheme.primary
                              : Colors.grey.shade700,
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
    );
  }

  // Step 2 – Symptoms
  Widget _buildStep2() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stepTitle('Pilih Gejala yang Dirasakan'),
              _stepSubtitle('Bisa pilih lebih dari satu gejala'),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_selectedSymptoms.length} gejala dipilih',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: _allSymptoms.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
              itemBuilder: (context, i) {
                final sym = _allSymptoms[i];
                final sel = _selectedSymptoms.contains(sym);
                return CheckboxListTile(
                  value: sel,
                  activeColor: scheme.primary,
                  tileColor: sel ? scheme.primaryContainer : null,
                  title: Text(
                    sym,
                    style: TextStyle(
                      fontSize: 14,
                      color: sel ? scheme.primary : Colors.grey.shade800,
                    ),
                  ),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedSymptoms.add(sym);
                      } else {
                        _selectedSymptoms.remove(sym);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // Step 3 – Detail
  Widget _buildStep3() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle('Detail Gejala'),
          _stepSubtitle(
            'Lengkapi informasi berikut untuk analisis yang lebih akurat',
          ),
          const SizedBox(height: 16),

          // Severity slider
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tingkat Keparahan',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ringan',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      Text(
                        'Sedang',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      Text(
                        'Berat',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: _urgencyColor,
                      thumbColor: _urgencyColor,
                      inactiveTrackColor: Colors.grey.shade200,
                    ),
                    child: Slider(
                      value: _severity,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: _severity.round().toString(),
                      onChanged: (v) => setState(() => _severity = v),
                    ),
                  ),
                  Center(
                    child: Text(
                      '${_severity.round()} / 10',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: _urgencyColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Duration
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Durasi Gejala',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    // `value` (bukan `initialValue`) agar pilihan ikut ter-reset
                    // saat pengguna menekan "Mulai Ulang".
                    // ignore: deprecated_member_use
                    value: _duration,
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.timer_outlined,
                        color: scheme.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: _durationOpts
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text(
                              d,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _duration = v!),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Notes
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Catatan Tambahan',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Ceritakan kondisi Anda lebih lanjut...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.all(12),
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

  // ── Result ───────────────────────────────────────────────────────────────────
  Widget _buildResult() {
    if (_loading) {
      return const LoadingView(message: 'Menganalisis gejala Anda...');
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _analyze);
    }

    final diseases = _analysis;
    if (diseases == null || diseases.isEmpty) {
      return EmptyView(
        icon: Icons.fact_check_outlined,
        title: 'Belum Ada Analisis',
        message:
            'Pilih gejala terlebih dahulu, lalu tekan "Lihat Hasil" '
            'untuk memulai analisis.',
        actionLabel: _selectedSymptoms.isEmpty ? null : 'Mulai Analisis',
        onAction: _selectedSymptoms.isEmpty ? null : _analyze,
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final recs = [
      'Istirahat cukup minimal 8 jam per malam',
      'Minum air putih minimal 2 liter per hari',
      'Konsumsi makanan bergizi seimbang',
      'Hindari aktivitas fisik berat sementara waktu',
      _severity >= 8
          ? 'Segera kunjungi dokter atau IGD terdekat!'
          : 'Konsultasikan ke dokter jika gejala memburuk',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          Card(
            color: scheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.analytics_outlined, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Hasil Analisis',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _chip('Area: ${_selectedArea ?? "-"}', Colors.white24),
                      _chip(
                        '${_selectedSymptoms.length} gejala',
                        Colors.white24,
                      ),
                      _chip('Durasi: $_duration', Colors.white24),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'Tingkat Urgency: ',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _urgencyColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _urgency,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Warning banner (if high)
          if (_severity >= 8)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade600,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gejala Anda tergolong berat. Segera hubungi dokter atau kunjungi IGD terdekat.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Possible diseases
          _resultSectionTitle('Kemungkinan Kondisi'),
          const SizedBox(height: 8),
          ...diseases.map(
            (d) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(
                    Icons.local_hospital_outlined,
                    color: scheme.primary,
                  ),
                ),
                title: Text(
                  d['name'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  d['desc'] as String,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    d['prob'] as String,
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Recommendations
          _resultSectionTitle('Rekomendasi'),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: recs.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Mulai Ulang'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(color: scheme.primary),
                    foregroundColor: scheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/chat');
                  },
                  icon: const Icon(Icons.chat_outlined, color: Colors.white),
                  label: const Text(
                    'Chat Dokter',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    backgroundColor: scheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Nav bar ──────────────────────────────────────────────────────────────────
  Widget _buildNavBar() {
    final scheme = Theme.of(context).colorScheme;
    final showBack = _currentStep > 0 || _showResult;
    final isLast = _currentStep == 2 && !_showResult;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showBack) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _back,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Kembali'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(color: scheme.primary),
                  foregroundColor: scheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (!_showResult)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _next,
                icon: Icon(
                  isLast ? Icons.check_circle_outline : Icons.arrow_forward,
                  color: Colors.white,
                ),
                label: Text(
                  isLast ? 'Lihat Hasil' : 'Lanjut',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  backgroundColor: scheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Shared helpers ───────────────────────────────────────────────────────────
  Widget _stepTitle(String t) => Text(
    t,
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.grey.shade800,
    ),
  );

  Widget _stepSubtitle(String t) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 4),
    child: Text(t, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
  );

  Widget _resultSectionTitle(String t) => Text(
    t,
    style: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.bold,
      color: Colors.grey.shade800,
    ),
  );

  Widget _chip(String label, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}
