import 'package:flutter/material.dart';
import 'package:my_fashion_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_fashion_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:my_fashion_app/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:my_fashion_app/screens/admin_order_detail_screen.dart';
import 'package:my_fashion_app/screens/order_chat_screen.dart';
import 'package:my_fashion_app/screens/orders_screen.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';
import 'package:provider/provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  /// Wrapper مساعد للـ NotificationBellAction (يحافظ على الـ API القديمة).
  static Stream<int> getUnreadCount({
    required String userId,
    required bool isAdmin,
  }) {
    // ignore: deprecated_member_use_from_same_package
    return _kUnreadCountResolver(userId, isAdmin);
  }

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

/// محقن من main.dart بعد تهيئة DI.
late Stream<int> Function(String userId, bool isAdmin) _kUnreadCountResolver;

void registerUnreadCountResolver(
    Stream<int> Function(String userId, bool isAdmin) fn) {
  _kUnreadCountResolver = fn;
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  static const int _pageSize = 20;
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context
            .read<NotificationsProvider>()
            .startWatching(userId: user.uid, isAdmin: user.isAdmin);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final backButton = IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _gold),
      onPressed: () => Navigator.pop(context),
    );

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            AppSliverBar(
              title: 'الإشعارات',
              leading: backButton,
              automaticallyImplyLeading: false,
            ),
          ],
          body: const Center(
            child: Text('يرجى تسجيل الدخول',
                style: TextStyle(color: Colors.white54)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          AppSliverBar(
            title: 'الإشعارات',
            leading: backButton,
            automaticallyImplyLeading: false,
            actions: [
              TextButton(
                onPressed: () =>
                    context.read<NotificationsProvider>().markAllAsRead(),
                child: const Text('قراءة الكل',
                    style: TextStyle(color: _gold, fontSize: 13)),
              ),
            ],
          ),
        ],
        body: Consumer<NotificationsProvider>(
          builder: (context, provider, _) {
            if (provider.loading) {
              return const Center(
                  child: CircularProgressIndicator(color: _gold));
            }

            final all = provider.notifications;

            if (all.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none,
                        color: Colors.white24, size: 72),
                    SizedBox(height: 16),
                    Text('لا توجد إشعارات',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 18)),
                  ],
                ),
              );
            }

            final visible = all.take(_visibleCount).toList();
            final hasMore = all.length > _visibleCount;

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: visible.length + (hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == visible.length) {
                  return Center(
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _visibleCount += _pageSize),
                      icon: const Icon(Icons.expand_more, color: _gold),
                      label: Text(
                        'تحميل المزيد (${all.length - _visibleCount} متبقية)',
                        style: const TextStyle(color: _gold),
                      ),
                    ),
                  );
                }
                return _NotificationTile(notification: visible[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationEntity notification;

  const _NotificationTile({required this.notification});

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  String _iconLetter(String type) {
    switch (type) {
      case 'new_order':
        return 'ط';
      case 'order_status':
        return 'ح';
      case 'chat_message':
        return 'ر';
      default:
        return 'إ';
    }
  }

  void _handleTap(BuildContext context) {
    final n = notification;
    if (!n.read) {
      context.read<NotificationsProvider>().markAsRead(n.id);
    }

    final orderId = n.orderId ?? '';
    switch (n.type) {
      case 'new_order':
        if (orderId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminOrderDetailScreen(orderId: orderId),
            ),
          );
        }
        break;
      case 'chat_message':
        if (orderId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderChatScreen(
                orderId: orderId,
                otherUserName: n.senderName,
              ),
            ),
          );
        }
        break;
      case 'order_status':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OrdersScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final isRead = n.read;
    final timeStr =
        n.createdAt != null ? _timeAgo(n.createdAt!) : '';
    final avatarLetter =
        n.senderName.isNotEmpty ? n.senderName[0] : _iconLetter(n.type);

    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? Colors.white10 : _gold.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isRead
                  ? Colors.white10
                  : _gold.withValues(alpha: 0.2),
              child: Text(
                avatarLetter,
                style: TextStyle(
                  color: isRead ? Colors.white38 : _gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: TextStyle(
                            color: isRead ? Colors.white54 : Colors.white,
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: _gold, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  if (n.senderPhone != null && n.senderPhone!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      n.senderPhone!,
                      style: TextStyle(
                        color: isRead ? Colors.white30 : Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    n.body,
                    style: TextStyle(
                      color: isRead ? Colors.white38 : Colors.white70,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(timeStr,
                      style: const TextStyle(
                          color: Colors.white30, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'الآن';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      if (m == 1) return 'منذ دقيقة';
      if (m == 2) return 'منذ دقيقتين';
      if (m <= 10) return 'منذ $m دقائق';
      return 'منذ $m دقيقة';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      if (h == 1) return 'منذ ساعة';
      if (h == 2) return 'منذ ساعتين';
      if (h <= 10) return 'منذ $h ساعات';
      return 'منذ $h ساعة';
    }
    if (diff.inDays < 7) {
      final d = diff.inDays;
      if (d == 1) return 'منذ يوم';
      if (d == 2) return 'منذ يومين';
      if (d <= 10) return 'منذ $d أيام';
      return 'منذ $d يوم';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}
