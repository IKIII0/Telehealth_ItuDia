import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Logo aplikasi dari aset SVG.
///
/// Aset aslinya berupa garis detak jantung putih. Warna dapat diubah lewat
/// [color] agar tetap terbaca di atas latar terang tanpa mengubah bentuk.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64, this.color});

  static const String assetPath = 'assets/images/telehealth_logo.svg';

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
      semanticsLabel: 'Logo Telehealth',
    );
  }
}
