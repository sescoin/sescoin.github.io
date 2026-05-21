import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.username,
    this.avatarUrl,
    this.radius = 24,
    this.onTap,
  });

  final String username;
  final String? avatarUrl;
  final double radius;
  final VoidCallback? onTap;

  // Génère une couleur déterministe depuis le username
  Color _colorFromUsername(BuildContext context) {
    final colors = [
      const Color(0xFF6C5CE7),
      const Color(0xFF00B894),
      const Color(0xFFE17055),
      const Color(0xFF0984E3),
      const Color(0xFFFDAC5D),
      const Color(0xFFE84393),
    ];
    final index = username.codeUnits.fold(0, (a, b) => a + b) % colors.length;
    return colors[index];
  }

  String get _initials {
    final parts = username.split('.');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return username.isNotEmpty ? username[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final isUrl = avatarUrl != null &&
        (avatarUrl!.startsWith('http://') || avatarUrl!.startsWith('https://'));
    final isEmoji = avatarUrl != null && !isUrl && avatarUrl!.isNotEmpty;

    final Widget avatar = isUrl
        ? CircleAvatar(
            radius: radius,
            backgroundImage: NetworkImage(avatarUrl!),
            backgroundColor: _colorFromUsername(context),
          )
        : CircleAvatar(
            radius: radius,
            backgroundColor: _colorFromUsername(context),
            child: isEmoji
                ? Text(avatarUrl!, style: TextStyle(fontSize: radius * 0.85))
                : Text(
                    _initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: radius * 0.65,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }
}
