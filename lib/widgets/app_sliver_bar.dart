import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/screens/notifications_screen.dart';

/// AppBar موحد لكل صفحات التطبيق — يدعم تأثير الـ Sliver
class AppSliverBar extends StatelessWidget {
  const AppSliverBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions = const [],
    this.leading,
    this.floating = true,
    this.pinned = false,
    this.snap = true,
    this.backgroundColor = Colors.black,
    this.toolbarHeight = 56.0,
    this.automaticallyImplyLeading = false,
  });

  final String? title;
  final Widget? titleWidget;
  final List<Widget> actions;
  final Widget? leading;
  final bool floating;
  final bool pinned;
  final bool snap;
  final Color backgroundColor;
  final double toolbarHeight;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: backgroundColor,
      foregroundColor: Colors.white,
      floating: floating,
      snap: snap && floating,
      pinned: pinned,
      toolbarHeight: toolbarHeight,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      title: titleWidget ??
          (title != null
              ? Text(
                  title!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null),
      actions: actions,
      elevation: 0,
    );
  }
}

/// عنوان "طَلّة" — حرف الطاء ذهبي، الباقي أبيض
class TalaAppBarTitle extends StatelessWidget {
  const TalaAppBarTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        children: [
          TextSpan(
            text: 'طَ',
            style: TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          TextSpan(
            text: 'لّة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// زر الجرس مع badge لعدد الإشعارات غير المقروءة
class NotificationBellAction extends StatelessWidget {
  const NotificationBellAction({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnap) {
        final isAdmin =
            (userSnap.data?.data() as Map?)?['role']?.toString().toLowerCase() ==
                'admin';

        return StreamBuilder<int>(
          stream: NotificationsScreen.getUnreadCount(
            userId: user.uid,
            isAdmin: isAdmin,
          ),
          builder: (context, countSnap) {
            final count = countSnap.data ?? 0;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white, size: 26),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                ),
                if (count > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFD4AF37),
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
