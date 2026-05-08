import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// أدوات مشتركة لحالات الطلب
/// تُستخدم في orders_screen, admin_orders_screen, admin_order_detail_screen
abstract class OrderUtils {
  // ── لون الحالة ──────────────────────────────────────────────────────────
  static Color statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ── تسمية الحالة بالعربية ────────────────────────────────────────────────
  static String statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'قيد المعالجة';
      case 'confirmed':
        return 'تم التأكيد';
      case 'shipped':
        return 'تم الشحن';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  // ── استخراج DateTime من حقل Firestore (Timestamp أو DateTime) ──────────
  static DateTime resolveDate(Map<String, dynamic> data) {
    final v = data['createdAt'] ?? data['updatedAt'];
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ── تنسيق التاريخ والوقت ────────────────────────────────────────────────
  static String formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year}  '
        '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // ── تسمية عنصر الطلب — يُخفي المقاس/اللون إن كانا فارغَين أو 'افتراضي' ─
  static String buildItemLabel(Map<String, dynamic> item) {
    final qty = item['quantity'];
    final size = item['size'] as String? ?? '';
    final color = item['color'] as String? ?? '';
    final parts = <String>['x$qty'];
    if (size.isNotEmpty && size != 'افتراضي') parts.add(size);
    if (color.isNotEmpty && color != 'افتراضي') parts.add(color);
    return parts.join('  •  ');
  }
}
