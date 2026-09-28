import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class UserAvatarWidget extends StatelessWidget {
  final String? avatarData;
  final String name;
  final double radius;
  final Color? backgroundColor;
  final TextStyle? textStyle;

  const UserAvatarWidget({
    super.key,
    required this.avatarData,
    required this.name,
    this.radius = 20,
    this.backgroundColor,
    this.textStyle,
  });

  ImageProvider? _resolveImage() {
    if (avatarData == null || avatarData!.isEmpty) return null;
    try {
      if (avatarData!.startsWith('data:image')) {
        final commaIdx = avatarData!.indexOf(',');
        if (commaIdx != -1) {
          final b64 = avatarData!.substring(commaIdx + 1);
          return MemoryImage(base64Decode(b64));
        }
      } else if (avatarData!.startsWith('http://') || avatarData!.startsWith('https://')) {
        return NetworkImage(avatarData!);
      } else {
        // Raw base64 string
        return MemoryImage(base64Decode(avatarData!));
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final img = _resolveImage();
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppColors.primary,
      backgroundImage: img,
      child: img == null
          ? Text(
              initial,
              style: textStyle ??
                  TextStyle(
                    fontSize: radius * 0.9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            )
          : null,
    );
  }
}
