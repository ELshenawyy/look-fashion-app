import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderChatScreen extends StatefulWidget {
  final String orderId;
  final String otherUserName;

  const OrderChatScreen({
    Key? key,
    required this.orderId,
    required this.otherUserName,
  }) : super(key: key);

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);
  static const String _adminWhatsApp = '201200507628'; // رقم الأدمن

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isAdmin = false;
  String _customerName = '';
  String _customerPhone = '';
  String _customerEmail = '';

  @override
  void initState() {
    super.initState();
    _loadOrderInfo();
  }

  Future<void> _loadOrderInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if current user is admin
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final role = userDoc.data()?['role'] as String? ?? '';
    final isAdmin = role.toLowerCase() == 'admin';

    // Load order data
    final orderDoc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .get();
    final orderData = orderDoc.data();

    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
      _customerName = orderData?['userName'] as String? ??
          orderData?['userEmail'] as String? ??
          'العميل';
      _customerPhone = orderData?['phone'] as String? ?? '';
      _customerEmail = orderData?['userEmail'] as String? ?? '';
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  CollectionReference get _messagesRef => FirebaseFirestore.instance
      .collection('orders')
      .doc(widget.orderId)
      .collection('messages');

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _messageController.clear();

    await _messagesRef.add({
      'text': text,
      'senderId': user.uid,
      'senderEmail': user.email,
      'senderName': user.displayName ?? user.email ?? 'مستخدم',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Create notification for the other party
    final orderDoc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .get();
    final orderData = orderDoc.data();
    if (orderData != null) {
      final orderUserId = orderData['userId'] as String? ?? '';
      final customerName = orderData['userName'] as String? ?? 'العميل';

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'chat_message',
        'title': _isAdmin ? 'رسالة من الإدارة' : 'رسالة من $customerName',
        'body': text.length > 50 ? '${text.substring(0, 50)}...' : text,
        'orderId': widget.orderId,
        'forRole': _isAdmin ? null : 'admin',
        'forUserId': _isAdmin ? orderUserId : null,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openWhatsApp() async {
    // Admin contacts customer, User contacts admin
    final phone = _isAdmin ? _formatPhone(_customerPhone) : _adminWhatsApp;

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رقم الهاتف غير متاح'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final url = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح واتساب'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Formats Egyptian phone number to international format for WhatsApp
  String _formatPhone(String phone) {
    phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (phone.startsWith('0')) {
      return '2$phone'; // 01200507628 → 201200507628
    }
    if (phone.startsWith('+')) {
      return phone.substring(1);
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Build the title based on admin/user role
    final chatTitle = _isAdmin
        ? 'محادثة مع $_customerName'
        : (widget.otherUserName.isNotEmpty
            ? 'محادثة مع ${widget.otherUserName}'
            : 'محادثة الطلب');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chatTitle, style: const TextStyle(fontSize: 15)),
            if (_isAdmin && _customerPhone.isNotEmpty)
              Text(
                _customerPhone,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              )
            else if (_isAdmin && _customerEmail.isNotEmpty)
              Text(
                _customerEmail,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _gold),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // WhatsApp button
          IconButton(
            onPressed: _openWhatsApp,
            icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 26),
            tooltip: 'تواصل عبر واتساب',
          ),
        ],
      ),
      body: Column(
        children: [
          // Admin info banner for customer phone
          if (_isAdmin && _customerPhone.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _panel,
              child: Row(
                children: [
                  const Icon(Icons.phone_outlined, color: _gold, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'رقم العميل: $_customerPhone',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _openWhatsApp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat, color: Color(0xFF25D366), size: 14),
                          SizedBox(width: 4),
                          Text('واتساب', style: TextStyle(color: Color(0xFF25D366), fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesRef.orderBy('createdAt').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _gold));
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline, color: Colors.white24, size: 64),
                        const SizedBox(height: 12),
                        const Text('ابدأ المحادثة',
                            style: TextStyle(color: Colors.white54, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                            _isAdmin
                                ? 'أرسل رسالة للعميل بخصوص هذا الطلب'
                                : 'أرسل رسالة للتواصل بخصوص هذا الطلب',
                            style: const TextStyle(color: Colors.white30, fontSize: 13)),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _openWhatsApp,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                    _isAdmin
                                        ? 'تواصل مع العميل عبر واتساب'
                                        : 'أو تواصل عبر واتساب',
                                    style: const TextStyle(color: Color(0xFF25D366), fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == user?.uid;
                    return _MessageBubble(data: data, isMe: isMe);
                  },
                );
              },
            ),
          ),
          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            decoration: const BoxDecoration(
              color: _panel,
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالة...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: _gold,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMe;

  const _MessageBubble({required this.data, required this.isMe});

  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final text = data['text'] as String? ?? '';
    final senderName = data['senderName'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final timeStr = createdAt != null
        ? '${createdAt.toDate().hour}:${createdAt.toDate().minute.toString().padLeft(2, '0')}'
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: isMe ? _gold.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
          border: Border.all(
            color: isMe ? _gold.withValues(alpha: 0.3) : Colors.white12,
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  senderName,
                  style: TextStyle(
                    color: _gold.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: const TextStyle(color: Colors.white30, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
