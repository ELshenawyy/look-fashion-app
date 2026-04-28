import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/screens/order_chat_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

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
        _isAdmin = role.toLowerCase() == 'admin';
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
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('يرجى تسجيل الدخول',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    if (_loadingRole) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('الإشعارات'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _gold),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('قراءة الكل',
                style: TextStyle(color: _gold, fontSize: 13)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: NotificationsScreen.getNotificationsStream(
          userId: _userId,
          isAdmin: _isAdmin,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _gold));
          }

          final docs = snapshot.data?.docs ?? [];

          // Sort newest first (client-side, no composite index needed)
          final sorted = List.of(docs)
            ..sort((a, b) {
              final aTime = (a.data() as Map)['createdAt'] as Timestamp?;
              final bTime = (b.data() as Map)['createdAt'] as Timestamp?;
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
              return _NotificationTile(docId: doc.id, data: data);
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _NotificationTile({required this.docId, required this.data});

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  IconData _iconForType(String type) {
    switch (type) {
      case 'new_order':
        return Icons.shopping_bag_outlined;
      case 'order_status':
        return Icons.local_shipping_outlined;
      case 'chat_message':
        return Icons.chat_bubble_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRead = data['read'] == true;
    final type = data['type'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final orderId = data['orderId'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final timeStr = createdAt != null ? _timeAgo(createdAt.toDate()) : '';

    return GestureDetector(
      onTap: () {
        if (!isRead) {
          FirebaseFirestore.instance
              .collection('notifications')
              .doc(docId)
              .update({'read': true});
        }
        if (orderId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderChatScreen(
                orderId: orderId,
                otherUserName: '',
              ),
            ),
          );
        }
      },
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isRead
                    ? Colors.white10
                    : _gold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconForType(type),
                color: isRead ? Colors.white38 : _gold,
                size: 20,
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
                  const SizedBox(height: 4),
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
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${date.day}/${date.month}/${date.year}';
  }
}
