import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:Telehealth/data/models/medicine_catalog.dart';
import 'package:Telehealth/data/services/medicine_service.dart';
import 'package:Telehealth/features/hospital_admin/presentation/theme/admin_theme.dart';

/// Dropdown obat yang dapat dicari dan terhubung ke `medicines_catalog`.
///
/// Perilaku:
/// - Bentuk tertutup menampilkan obat terpilih (atau teks resep dokter yang
///   sudah ada) dengan ikon panah dropdown.
/// - Saat dibuka, muncul panel dropdown berisi kolom pencarian dan daftar obat
///   aktif dari database.
/// - Pencarian memakai debounce 300 ms dan query ke [MedicineService].
/// - Memilih obat memanggil [onSelected] agar pemanggil dapat mengisi dosis,
///   frekuensi, durasi, dan instruksi dari nilai default katalog.
/// - Opsi "Gunakan nama obat custom" mengubah field menjadi input teks bebas
///   untuk obat yang belum terdaftar.
class MedicineDropdownField extends StatefulWidget {
  const MedicineDropdownField({
    super.key,
    required this.controller,
    required this.onSelected,
    this.enabled = true,
    this.labelText = 'Nama obat',
    this.hintText = 'Pilih obat dari katalog…',
    this.validator,
  });

  final TextEditingController controller;
  final ValueChanged<MedicineCatalogItem> onSelected;
  final bool enabled;
  final String labelText;
  final String hintText;
  final FormFieldValidator<String>? validator;

  @override
  State<MedicineDropdownField> createState() => _MedicineDropdownFieldState();
}

class _MedicineDropdownFieldState extends State<MedicineDropdownField> {
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  final GlobalKey<FormFieldState<String>> _formFieldKey =
      GlobalKey<FormFieldState<String>>();
  final GlobalKey _anchorKey = GlobalKey();
  final LayerLink _link = LayerLink();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _customFocus = FocusNode();
  final TextEditingController _search = TextEditingController();

  OverlayEntry? _overlay;
  Timer? _debounce;
  List<MedicineCatalogItem> _results = const [];
  String _searchTerm = '';
  String? _errorMessage;
  bool _loading = false;
  bool _open = false;
  bool _showAbove = false;
  bool _customMode = false;
  double _fieldWidth = 320;
  int _searchSequence = 0;
  late String _currentText;

  @override
  void initState() {
    super.initState();
    _currentText = widget.controller.text;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant MedicineDropdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _currentText = widget.controller.text;
    }
    if (!widget.enabled) _closeDropdown();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _overlay?.remove();
    _overlay = null;
    widget.controller.removeListener(_onControllerChanged);
    _search.dispose();
    _searchFocus.dispose();
    _customFocus.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final text = widget.controller.text;
    if (text == _currentText) return;
    _currentText = text;
    if (!mounted) return;
    setState(() {});
    _formFieldKey.currentState?.didChange(text);
  }

  // ─── Buka / tutup dropdown ─────────────────────────────────────────────────

  void _toggleDropdown() {
    if (_open) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    if (!widget.enabled) return;
    if (_open) return;

    _search.clear();
    _searchTerm = '';
    _results = const [];
    _errorMessage = null;
    _loading = true;
    _showAbove = _shouldShowAbove();
    setState(() => _open = true);

    _insertOverlay();
    _runSearch('');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) _searchFocus.requestFocus();
    });
  }

  void _closeDropdown() {
    if (_overlay == null && !_open) return;
    _debounce?.cancel();
    _searchFocus.unfocus();
    _overlay?.remove();
    _overlay = null;
    if (!mounted) {
      _open = false;
      return;
    }
    setState(() => _open = false);
  }

  void _insertOverlay() {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      setState(() => _open = false);
      return;
    }
    _overlay = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_overlay!);
  }

  bool _shouldShowAbove() {
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return false;
    final top = box.localToGlobal(Offset.zero).dy;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final spaceBelow = screenHeight - (top + box.size.height);
    return spaceBelow < 260 && top > spaceBelow;
  }

  // ─── Pencarian ─────────────────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () => _runSearch(value));
  }

  Future<void> _runSearch(String term) async {
    final sequence = ++_searchSequence;
    if (mounted) {
      setState(() {
        _searchTerm = term;
        _loading = true;
        _errorMessage = null;
      });
      _overlay?.markNeedsBuild();
    }

    List<MedicineCatalogItem> results;
    String? errorMessage;
    try {
      results = await MedicineService.instance.searchMedicines(term, limit: 40);
    } catch (error) {
      results = const [];
      errorMessage = error is MedicineServiceException
          ? error.message
          : 'Gagal memuat katalog obat. Coba lagi.';
    }

    if (!mounted || !_open || sequence != _searchSequence) return;

    setState(() {
      _results = results;
      _loading = false;
      _errorMessage = errorMessage;
    });
    _overlay?.markNeedsBuild();
  }

  // ─── Aksi pilihan ──────────────────────────────────────────────────────────

  void _select(MedicineCatalogItem item) {
    widget.controller.text = item.medicineName;
    widget.controller.selection = TextSelection.collapsed(
      offset: item.medicineName.length,
    );
    _formFieldKey.currentState
      ?..didChange(item.medicineName)
      ..validate();
    _closeDropdown();
    widget.onSelected(item);
  }

  void _activateCustomMode() {
    _closeDropdown();
    setState(() => _customMode = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _customFocus.requestFocus();
    });
  }

  void _backToCatalog() {
    setState(() => _customMode = false);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_customMode) return _buildCustomField();

    return LayoutBuilder(
      builder: (context, constraints) {
        _fieldWidth = constraints.maxWidth;

        return CompositedTransformTarget(
          link: _link,
          child: FormField<String>(
            key: _formFieldKey,
            initialValue: _currentText,
            validator: widget.validator,
            builder: (field) {
              return GestureDetector(
                key: _anchorKey,
                onTap: widget.enabled ? _toggleDropdown : null,
                child: InputDecorator(
                  isEmpty: _currentText.trim().isEmpty,
                  decoration: InputDecoration(
                    labelText: widget.labelText,
                    hintText: widget.hintText,
                    errorText: field.errorText,
                    suffixIcon: Icon(
                      _open
                          ? Icons.arrow_drop_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      size: 22,
                    ),
                  ),
                  child: Text(
                    _currentText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCustomField() {
    return TextFormField(
      controller: widget.controller,
      focusNode: _customFocus,
      enabled: widget.enabled,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: 'mis. nama obat sesuai resep dokter',
        suffixIcon: IconButton(
          tooltip: 'Kembali pilih dari katalog',
          onPressed: widget.enabled ? _backToCatalog : null,
          icon: const Icon(Icons.list_alt_rounded, size: 19),
        ),
      ),
      validator: widget.validator,
    );
  }

  // ─── Panel dropdown ────────────────────────────────────────────────────────

  Widget _buildOverlay(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeDropdown,
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: Offset(0, _showAbove ? -6 : 6),
          targetAnchor: _showAbove ? Alignment.topLeft : Alignment.bottomLeft,
          followerAnchor: _showAbove ? Alignment.bottomLeft : Alignment.topLeft,
          child: TextFieldTapRegion(
            child: SizedBox(
              width: _fieldWidth,
              child: Material(
                color: AdminColors.surface,
                elevation: 12,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminColors.border),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: _panelMaxHeight(context),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSearchHeader(),
                        const Divider(height: 1),
                        Flexible(child: _buildResults()),
                        const Divider(height: 1),
                        _buildCustomOption(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _panelMaxHeight(BuildContext context) {
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return 320;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final available = _showAbove ? top : screenHeight - bottom;
    return math.min(360, math.max(180, available - 16));
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
      child: TextField(
        controller: _search,
        focusNode: _searchFocus,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Cari nama obat atau zat aktif…',
          prefixIcon: Icon(Icons.search_rounded, size: 19),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading && _results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Memuat katalog obat…',
              style: TextStyle(fontSize: 12.5, color: AdminColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      if (_errorMessage != null) return _buildErrorState();

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        child: Row(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 18,
              color: AdminColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _searchTerm.isEmpty
                        ? 'Belum ada obat aktif di katalog.'
                        : 'Obat "$_searchTerm" tidak ditemukan.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.textMuted,
                    ),
                  ),
                  if (_searchTerm.isEmpty) ...[
                    const SizedBox(height: 3),
                    const Text(
                      'Pastikan seed katalog (supabase/07) sudah dijalankan.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: AdminColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _results.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) => _MedicineDropdownTile(
        item: _results[index],
        onTap: () => _select(_results[index]),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: AdminColors.danger,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AdminColors.danger,
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _runSearch(_searchTerm),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Coba lagi'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomOption() {
    return InkWell(
      onTap: _activateCustomMode,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(Icons.edit_note_rounded, size: 18, color: AdminColors.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Gunakan nama obat custom',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AdminColors.primary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AdminColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicineDropdownTile extends StatelessWidget {
  const _MedicineDropdownTile({required this.item, required this.onTap});

  final MedicineCatalogItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = [
      if (item.genericName.isNotEmpty) item.genericName,
      if (item.dosageForm.isNotEmpty) item.dosageForm,
    ].join(' • ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AdminColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.medication_rounded,
                size: 17,
                color: AdminColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.medicineName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                  if (secondary.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      secondary,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AdminColors.textMuted,
                      ),
                    ),
                  ],
                  if (item.defaultSummary.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.defaultSummary,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AdminColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.category.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AdminColors.infoSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.category,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.info,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
