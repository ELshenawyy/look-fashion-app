import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';

/// Widget مشترك يعرض صورة المستخدم من AuthProvider (Real-time عبر stream).
/// - إن وُجدت صورة: يعرضها عبر CachedNetworkImage
/// - إن لم توجد: يعرض أول حرف من الاسم داخل دائرة ملونة
class UserAvatarWidget extends StatelessWidget {
  final double radius;

  const UserAvatarWidget({super.key, this.radius = 20});

  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        if (user == null) {
          return _InitialAvatar(initial: 'م', radius: radius);
        }

        final photoUrl = user.photoUrl ?? '';
        final name = user.displayName ??
            user.email?.split('@').first ??
            '';
        final initial =
            name.isNotEmpty ? name.trim()[0].toUpperCase() : 'م';

        if (photoUrl.isNotEmpty) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: _gold.withValues(alpha: 0.15),
            backgroundImage: CachedNetworkImageProvider(photoUrl),
          );
        }

        return _InitialAvatar(initial: initial, radius: radius);
      },
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String initial;
  final double radius;

  const _InitialAvatar({required this.initial, required this.radius});

  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _gold.withValues(alpha: 0.18),
      child: Text(
        initial,
        style: TextStyle(
          color: _gold,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}
