import 'package:flutter/material.dart';
import 'package:my_fashion_app/constants/app_config.dart';
import 'package:my_fashion_app/core/di/injection_container.dart';
import 'package:my_fashion_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_fashion_app/features/chat/domain/entities/chat_message_entity.dart';
import 'package:my_fashion_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:my_fashion_app/features/orders/domain/entities/order_entity.dart';
import 'package:my_fashion_app/features/orders/domain/usecases/get_order_by_id.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderChatScreen extends StatefulWidget {
  final String orderId;
  final String otherUserName;

  const OrderChatScreen({
    super.key,
    required this.orderId,
    required this.otherUserName,
  });

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final ChatProvider _chatProvider;

  bool _isAuthorized = true;
  bool _loading = true;
  OrderEntity? _order;

  @override
  void initState() {
    super.initState();
    _chatProvider = sl<ChatProvider>();
    _loadOrderInfo();
  }

  Future<void> _loadOrderInfo() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final res = await sl<GetOrderById>()(widget.orderId);
    if (!mounted) return;

    res.fold((f) {
      setState(() {
        _loading = false;
        _isAuthorized = false;
      });
    }, (order) {
      final authorized = user.isAdmin || order.userId == user.uid;
      setState(() {
        _order = order;
        _isAuthorized = authorized;
        _loading = false;
      });
      if (authorized) {
        _chatProvider.watchOrder(widget.orderId);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    _messageController.clear();
    final senderName =
        user.displayName ?? user.email ?? user.phone ?? 'مستخدم';

    final ok = await _chatProvider.send(
      orderId: widget.orderId,
      text: text,
      senderId: user.uid,
      senderName: senderName,
      senderEmail: user.email,
      isAdminSender: user.isAdmin,
    );

    if (!mounted) return;
    if (!ok && _chatProvider.failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_chatProvider.failure!.message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      _chatProvider.clearFailure();
    } else {
      _scrollToBottom();
    }
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
    final isAdmin = context.read<AuthProvider>().user?.isAdmin ?? false;
    var phone =
        isAdmin ? _formatPhone(_order?.phone ?? '') : AppConfig.adminWhatsApp;

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رقم الهاتف غير متاح'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // sanitize: wa.me يقبل أرقام فقط بدون 00 أو +
    phone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (phone.startsWith('00')) phone = phone.substring(2);

    final url = Uri.parse('https://wa.me/$phone');
    // ⚠ نُحاول مباشرة بـ externalApplication بدل canLaunchUrl + launchUrl
    // (canLaunchUrl يرجع false على Android 11+ بدون queries، وحتى مع
    // queries أحياناً false positive).
    try {
      final ok =
          await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح واتساب. تأكد من تثبيت التطبيق.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح واتساب: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatPhone(String phone) {
    phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (phone.startsWith('0')) return '2$phone';
    if (phone.startsWith('+')) return phone.substring(1);
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user?.isAdmin ?? false;

    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: _gold)),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _gold),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('محادثة الطلب',
              style: TextStyle(color: Colors.white, fontSize: 15)),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, color: Colors.white24, size: 72),
              SizedBox(height: 16),
              Text('غير مصرح بالوصول',
                  style: TextStyle(color: Colors.white54, fontSize: 18)),
              SizedBox(height: 8),
              Text(
                'هذه المحادثة تخص طلباً لا يعود لك.',
                style: TextStyle(color: Colors.white30, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final customerName = _order?.userName.isNotEmpty == true
        ? _order!.userName
        : (_order?.userEmail ?? 'العميل');
    final customerPhone = _order?.phone ?? '';
    final customerEmail = _order?.userEmail ?? '';

    // الأدمن يرى اسم العميل (للعمل). المستخدم لا يرى اسم
    // الموظف/الإدمن — يرى "إدارة تطبيق طلّة" (لحماية الـ identity).
    final chatTitle = isAdmin
        ? 'محادثة مع $customerName'
        : 'إدارة تطبيق طلّة';

    return ChangeNotifierProvider<ChatProvider>.value(
      value: _chatProvider,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _gold),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(chatTitle,
                  style: const TextStyle(fontSize: 15, color: Colors.white)),
              if (isAdmin && customerPhone.isNotEmpty)
                Text(customerPhone,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12))
              else if (isAdmin && customerEmail.isNotEmpty)
                Text(customerEmail,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
            ],
          ),
          actions: [
            // الـ admin يقدر يفتح WhatsApp مع العميل (لإكمال الطلب).
            // المستخدم لا يرى الزر — لتجنب تعريض رقم admin.
            if (isAdmin)
              IconButton(
                onPressed: _openWhatsApp,
                icon: const Icon(Icons.chat,
                    color: Color(0xFF25D366), size: 26),
                tooltip: 'تواصل عبر واتساب',
              ),
          ],
        ),
        body: Column(
          children: [
            if (isAdmin && customerPhone.isNotEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: _panel,
                child: Row(
                  children: [
                    const Icon(Icons.phone_outlined, color: _gold, size: 16),
                    const SizedBox(width: 8),
                    Text('رقم العميل: $customerPhone',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    const Spacer(),
                    GestureDetector(
                      onTap: _openWhatsApp,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF25D366)
                                  .withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat,
                                color: Color(0xFF25D366), size: 14),
                            SizedBox(width: 4),
                            Text('واتساب',
                                style: TextStyle(
                                    color: Color(0xFF25D366),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, provider, _) {
                  final messages = provider.messages;
                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline,
                              color: Colors.white24, size: 64),
                          const SizedBox(height: 12),
                          const Text('ابدأ المحادثة',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(
                            isAdmin
                                ? 'أرسل رسالة للعميل بخصوص هذا الطلب'
                                : 'أرسل رسالة للتواصل بخصوص هذا الطلب',
                            style: const TextStyle(
                                color: Colors.white30, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _openWhatsApp,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xFF25D366)
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.chat,
                                      color: Color(0xFF25D366), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                      isAdmin
                                          ? 'تواصل مع العميل عبر واتساب'
                                          : 'أو تواصل عبر واتساب',
                                      style: const TextStyle(
                                          color: Color(0xFF25D366),
                                          fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _scrollToBottom());

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg = messages[i];
                      final isMe = msg.senderId == user?.uid;
                      return _MessageBubble(message: msg, isMe: isMe);
                    },
                  );
                },
              ),
            ),
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
                          hintStyle:
                              const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor:
                              Colors.white.withValues(alpha: 0.06),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
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
                        icon: const Icon(Icons.send_rounded,
                            color: Colors.black, size: 20),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageEntity message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final timeStr = message.createdAt != null
        ? '${message.createdAt!.hour}:${message.createdAt!.minute.toString().padLeft(2, '0')}'
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: isMe
              ? _gold.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
          border: Border.all(
            color: isMe
                ? _gold.withValues(alpha: 0.3)
                : Colors.white12,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName,
                  style: TextStyle(
                    color: _gold.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Text(
              message.text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, height: 1.4),
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
