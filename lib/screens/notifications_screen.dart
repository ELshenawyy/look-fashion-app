import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/screens/admin_order_detail_screen.dart';
import 'package:my_fashion_app/screens/order_chat_screen.dart';
import 'package:my_fashion_app/screens/orders_screen.dart';
import 'package:my_fashion_app/services/role_service.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  /// Returns a stream of notifications filtered correctly by role.
  static Stream<QuerySnapshot> getNotificationsStream({
    required String userId,
    required bool isAdmin,
  }) {
    final collection = FirebaseFirestore.instance.collection('notifications');
    if (isAdmin) {
      return collection.where('forRole', isEqualTo: 'admin').snapshots();
    } else {
      return collection.where('forUserId', isEqualTo: userId).snapshots();
    }
  }

  /// Returns a stream of unread notification count.
  static Stream<int> getUnreadCount({
    required String userId,
    required bool isAdmin,
  }) {
    return getNotificationsStream(userId: userId, isAdmin: isAdmin).map(
      (snap) => snap.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['read'] != true;
      }).length,
    );
  }

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Color _gold = Color(0xFFD4AF37);

  bool _isAdmin = false;
  bool _loadingRole = true;
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loadingRole = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final role = doc.data()?['role'] as String? ?? '';
    if (mounted) {
      setState(() {
        _userId = user.uid;
        _isAdmin = AppRole.isAdminLevel(role);
        _loadingRole = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    final firestore = FirebaseFirestore.instance;
    late QuerySnapshot snap;

    if (_isAdmin) {
      snap = await firestore
          .collection('notifications')
          .where('forRole', isEqualTo: 'admin')
          .where('read', isEqualTo: false)
          .get();
    } else {
      snap = await firestore
          .collection('notifications')
          .where('forUserId', isEqualTo: _userId)
          .where('read', isEqualTo: false)
          .get();
    }

    final batch = firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
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

    if (_loadingRole) {
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
            child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
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
                onPressed: _markAllRead,
                child: const Text('قراءة الكل',
                    style: TextStyle(color: _gold, fontSize: 13)),
              ),
            ],
          ),
        ],
        body: StreamBuilder<QuerySnapshot>(
          stream: NotificationsScreen.getNotificationsStream(
              userId: _userId, isAdmin: _isAdmin),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _gold));
            }

            final docs = snapshot.data?.docs ?? [];
            final sorted = List.of(docs)
              ..sort((a, b) {
                final aTime =
                    (a.data() as Map)['createdAt'] as Timestamp?;
                final bTime =
                    (b.data() as Map)['createdAt'] as Timestamp?;
                if (aTime == null || bTime == null) return 0;
                return bTime.compareTo(aTime);
              });

            if (sorted.isEmpty) {
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

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final doc = sorted[index];
                final data = doc.data() as Map<String, dynamic>;
                return _NotificationTile(
                  docId: doc.id,
                  data: data,
                  isAdmin: _isAdmin,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isAdmin;

  const _NotificationTile({
    required this.docId,
    required this.data,
    required this.isAdmin,
  });

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  /// الحرف الأول للأيقونة عند غياب اسم المرسل
  String _iconLetter(String type) {
    switch (type) {
      case 'new_order':
        return 'ط'; // طلب
      case 'order_status':
        return 'ح'; // حالة
      case 'chat_message':
        return 'ر'; // رسالة
      default:
        return 'إ'; // إشعار
    }
  }

  void _handleTap(BuildContext context, String type, String orderId,
      String senderName) {
    final isRead = data['read'] == true;
    if (!isRead) {
      FirebaseFirestore.instance
          .collection('notifications')
          .doc(docId)
          .update({'read': true});
    }

    switch (type) {
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
                otherUserName: senderName,
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
    final isRead = data['read'] == true;
    final type = data['type'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final orderId = data['orderId'] as String? ?? '';
    final senderName = data['senderName'] as String? ?? '';
    final senderPhone = data['senderPhone'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final timeStr = createdAt != null ? _timeAgo(createdAt.toDate()) : '';

    final avatarLetter =
        senderName.isNotEmpty ? senderName[0] : _iconLetter(type);

    return GestureDetector(
      onTap: () => _handleTap(context, type, orderId, senderName),
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
            // ── CircleAvatar ─────────────────────────────────────────
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

            // ── Content ───────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + unread dot
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isRead ? Colors.white54 : Colors.white,
                            fontWeight: isRead
                                ? FontWeight.normal
                                : FontWeight.w700,
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

                  // Phone (if present)
                  if (senderPhone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      senderPhone,
                      style: TextStyle(
                        color: isRead ? Colors.white30 : Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],

                  const SizedBox(height: 4),

                  // Body
                  Text(
                    body,
                    style: TextStyle(
                      color: isRead ? Colors.white38 : Colors.white70,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Time
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
