import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/transaction.dart';

/// Renders the official, crisp vector SVG logo for Ghanaian telecom networks:
/// - MTN (iconic yellow badge with black oval and MTN bold text)
/// - Telecel (official red circle with white Telecel brand icon)
/// - AT (official AT Money / AirtelTigo branding with red/blue emblem)
class CarrierBrandIcon extends StatelessWidget {
  final MoMoNetwork network;
  final double size;

  const CarrierBrandIcon({
    super.key,
    required this.network,
    this.size = 28,
  });

  static const String _mtnSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <rect width="100" height="100" rx="22" fill="#FFCC00"/>
  <ellipse cx="50" cy="50" rx="42" ry="26" fill="none" stroke="#000000" stroke-width="4.5"/>
  <text x="50" y="58" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" font-weight="900" font-size="24" fill="#000000" text-anchor="middle" letter-spacing="1.5">MTN</text>
</svg>
''';

  static const String _telecelSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <rect width="100" height="100" rx="22" fill="#E60000"/>
  <!-- Telecel lowercase stylized curved T emblem -->
  <path d="M 50 20 C 37 20 28 29 28 42 L 28 46 L 40 46 L 40 42 C 40 35 44 31 50 31 C 56 31 60 35 60 42 L 60 70 C 60 74 57 76 53 76 C 50 76 48 74 46 71 L 38 79 C 42 83 47 86 53 86 C 64 86 71 79 71 69 L 71 42 C 71 29 62 20 50 20 Z" fill="#FFFFFF"/>
  <rect x="22" y="42" width="40" height="10" rx="5" fill="#FFFFFF"/>
</svg>
''';

  static const String _atSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <rect width="100" height="100" rx="22" fill="#00377B"/>
  <text x="44" y="62" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" font-weight="900" font-size="34" fill="#FFFFFF" text-anchor="middle" letter-spacing="-1">at</text>
  <circle cx="75" cy="38" r="8" fill="#E31837"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    Widget iconContent;
    switch (network) {
      case MoMoNetwork.mtn:
        iconContent = SvgPicture.string(
          _mtnSvg,
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
        break;
      case MoMoNetwork.vodafone:
        iconContent = Image.asset(
          'telecel.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => SvgPicture.string(
            _telecelSvg,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        );
        break;
      case MoMoNetwork.airtel:
        iconContent = Image.asset(
          'at-logo-sm.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => SvgPicture.string(
            _atSvg,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        );
        break;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: SizedBox(
        width: size,
        height: size,
        child: iconContent,
      ),
    );
  }
}
