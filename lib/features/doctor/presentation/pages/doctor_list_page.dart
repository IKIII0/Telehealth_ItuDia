import 'package:flutter/material.dart';
import 'doctor_detail_page.dart';

class DoctorListPage extends StatefulWidget {
  const DoctorListPage({super.key});

  @override
  State<DoctorListPage> createState() => _DoctorListPageState();
}

class _DoctorListPageState extends State<DoctorListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'Semua';
  String _searchQuery = '';

  static const List<String> _filters = [
    'Semua',
    'Dokter Umum',
    'Spesialis Jantung',
    'Spesialis Anak',
    'Spesialis Kulit',
    'Spesialis Penyakit Dalam',
  ];

  final List<Map<String, dynamic>> _doctors = [
    {
      'name': 'Dr. Ahmad Fauzi, Sp.JP',
      'specialization': 'Spesialis Jantung',
      'experience': 12,
      'rating': 4.9,
      'price': 150000,
      'available': true,
      'avatarColor': const Color(0xFFE53935),
      'hospital': 'RS Jantung Harapan Kita',
      'bio':
          'Spesialis jantung berpengalaman dengan keahlian dalam penanganan penyakit jantung koroner, aritmia, dan gagal jantung. Telah menangani lebih dari 1.200 pasien jantung secara profesional.',
      'education': 'FK Universitas Indonesia • PPDS Kardiologi UI',
    },
    {
      'name': 'Dr. Siti Rahma, Sp.A',
      'specialization': 'Spesialis Anak',
      'experience': 8,
      'rating': 4.8,
      'price': 120000,
      'available': true,
      'avatarColor': const Color(0xFF1E88E5),
      'hospital': 'RSUP Dr. Cipto Mangunkusumo',
      'bio':
          'Dokter spesialis anak yang berdedikasi, berpengalaman dalam menangani berbagai penyakit anak dari neonatus hingga remaja dengan pendekatan yang ramah dan komunikatif.',
      'education': 'FK Universitas Gadjah Mada • PPDS Ilmu Kesehatan Anak UGM',
    },
    {
      'name': 'Dr. Budi Santoso',
      'specialization': 'Dokter Umum',
      'experience': 5,
      'rating': 4.6,
      'price': 75000,
      'available': false,
      'avatarColor': const Color(0xFF43A047),
      'hospital': 'Klinik Sehat Bersama',
      'bio':
          'Dokter umum berpengalaman dalam menangani berbagai keluhan kesehatan sehari-hari dengan pendekatan holistik dan edukasi kesehatan yang menyenangkan.',
      'education': 'FK Universitas Airlangga',
    },
    {
      'name': 'Dr. Dewi Kusuma, Sp.KK',
      'specialization': 'Spesialis Kulit',
      'experience': 10,
      'rating': 4.7,
      'price': 130000,
      'available': true,
      'avatarColor': const Color(0xFF8E24AA),
      'hospital': 'RS Dermatologi Indonesia',
      'bio':
          'Spesialis kulit dan kelamin dengan keahlian dalam dermatologi estetika dan penanganan penyakit kulit kronis seperti psoriasis, eksim, dan akne. Fellow AAD.',
      'education': 'FK Universitas Padjadjaran • PPDS Dermatologi UNPAD',
    },
    {
      'name': 'Dr. Rizky Pratama, Sp.PD',
      'specialization': 'Spesialis Penyakit Dalam',
      'experience': 15,
      'rating': 4.9,
      'price': 160000,
      'available': false,
      'avatarColor': const Color(0xFFFF8F00),
      'hospital': 'RSUD Dr. Soetomo',
      'bio':
          'Spesialis penyakit dalam senior dengan pengalaman luas menangani diabetes mellitus, hipertensi, dan gangguan metabolik. Konsultan aktif di 3 rumah sakit besar.',
      'education': 'FK Universitas Brawijaya • PPDS Penyakit Dalam UB',
    },
    {
      'name': 'Dr. Maya Indah, Sp.JP',
      'specialization': 'Spesialis Jantung',
      'experience': 9,
      'rating': 4.7,
      'price': 145000,
      'available': true,
      'avatarColor': const Color(0xFF00897B),
      'hospital': 'RS Siloam Kebon Jeruk',
      'bio':
          'Spesialis jantung yang bersemangat dengan keahlian dalam ekokardiografi dan penanganan gagal jantung akut maupun kronis. Aktif dalam penelitian kardiologi.',
      'education': 'FK Universitas Diponegoro • PPDS Kardiologi UNDIP',
    },
  ];

  List<Map<String, dynamic>> get _filteredDoctors {
    return _doctors.where((doctor) {
      final matchFilter = _selectedFilter == 'Semua' ||
          doctor['specialization'] == _selectedFilter;
      final matchSearch = _searchQuery.isEmpty ||
          (doctor['name'] as String)
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          (doctor['specialization'] as String)
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      return matchFilter && matchSearch;
    }).toList();
  }

  String _formatPrice(int price) {
    final str = price.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) result.write('.');
      result.write(str[i]);
    }
    return result.toString();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Dokter',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ──────────────────────────────────────────────────
          Container(
            color: const Color(0xFF2196F3),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Cari dokter atau spesialisasi...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
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

          // ── Filter Chips ─────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _selectedFilter = filter),
                      selectedColor: const Color(0xFF2196F3),
                      checkmarkColor: Colors.white,
                      backgroundColor: Colors.grey[100],
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF2196F3)
                            : Colors.grey[300]!,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Result count ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(Icons.medical_services_outlined,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${_filteredDoctors.length} dokter ditemukan',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          ),

          // ── Doctor List ──────────────────────────────────────────────────
          Expanded(
            child: _filteredDoctors.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 72, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Dokter tidak ditemukan',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Coba kata kunci atau filter lain',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _filteredDoctors.length,
                    itemBuilder: (context, index) {
                      return _DoctorCard(
                        doctor: _filteredDoctors[index],
                        formatPrice: _formatPrice,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Doctor Card Widget ───────────────────────────────────────────────────────

class _DoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final String Function(int) formatPrice;

  const _DoctorCard({required this.doctor, required this.formatPrice});

  @override
  Widget build(BuildContext context) {
    final bool isAvailable = doctor['available'] as bool;
    final Color avatarColor = doctor['avatarColor'] as Color;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      shadowColor: Colors.black12,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar + online dot ────────────────────────────────────────
            Stack(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: avatarColor.withOpacity(0.15),
                  child: Icon(Icons.person, size: 38, color: avatarColor),
                ),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: isAvailable ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // ── Info ───────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + status badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          doctor['name'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? const Color(0xFFE8F5E9)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isAvailable
                                ? const Color(0xFF66BB6A)
                                : Colors.grey[400]!,
                          ),
                        ),
                        child: Text(
                          isAvailable ? 'Tersedia' : 'Sibuk',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isAvailable
                                ? const Color(0xFF2E7D32)
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Specialization
                  Text(
                    doctor['specialization'] as String,
                    style: TextStyle(
                      color: avatarColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Hospital
                  Row(
                    children: [
                      Icon(Icons.local_hospital_outlined,
                          size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          doctor['hospital'] as String,
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Rating • Experience • Price
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 2),
                      Text(
                        (doctor['rating'] as double).toStringAsFixed(1),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.work_outline,
                          color: Colors.grey[400], size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${doctor['experience']} thn',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Mulai dari',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 10),
                          ),
                          Text(
                            'Rp ${formatPrice(doctor['price'] as int)}',
                            style: const TextStyle(
                              color: Color(0xFF2196F3),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Detail button
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                DoctorDetailPage(doctor: doctor),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Lihat Detail',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
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
