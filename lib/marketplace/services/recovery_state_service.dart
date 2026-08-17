import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/payment_models.dart';

class RecoveryStateService {
  RecoveryStateService._();

  static const paymentIdKey = 'currentMarketplacePaymentId';
  static const paymentOrderIdKey = 'currentMarketplacePaymentOrderId';
  static const paymentStatusKey = 'currentMarketplacePaymentStatus';
  static const paymentIdempotencyKey =
      'currentMarketplacePaymentIdempotencyKey';
  static const orderIdKey = 'currentMarketplaceOrderId';
  static const ownerIdKey = 'currentMarketplaceRecoveryOwnerId';

  static Future<void> prepareForUser(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final ownerId = prefs.getInt(ownerIdKey);
    if (ownerId != null && ownerId != userId) {
      await clearAll();
      debugRecovery('user_changed old=$ownerId new=$userId');
    }
    await prefs.setInt(ownerIdKey, userId);
    debugRecovery('user_ready');
  }

  static Future<void> savePayment(
    PaymentConfirmation payment, {
    required String idempotencyKey,
    required int userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(paymentIdKey, payment.paymentId);
    await prefs.setInt(paymentOrderIdKey, payment.orderId);
    await prefs.setString(paymentStatusKey, payment.status);
    await prefs.setString(paymentIdempotencyKey, idempotencyKey);
    await prefs.setInt(ownerIdKey, userId);
    debugRecovery('payment_saved');
  }

  static Future<void> updatePaymentStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(paymentStatusKey, status);
    debugRecovery('payment_status_updated');
  }

  static Future<void> clearPayment() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(paymentIdKey);
    await prefs.remove(paymentOrderIdKey);
    await prefs.remove(paymentStatusKey);
    await prefs.remove(paymentIdempotencyKey);
    debugRecovery('payment_cleared');
  }

  static Future<void> saveOrder(int orderId, {int? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(orderIdKey, orderId);
    if (userId != null) await prefs.setInt(ownerIdKey, userId);
    debugRecovery('order_saved');
  }

  static Future<void> clearOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(orderIdKey);
    debugRecovery('order_cleared');
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(paymentIdKey);
    await prefs.remove(paymentOrderIdKey);
    await prefs.remove(paymentStatusKey);
    await prefs.remove(paymentIdempotencyKey);
    await prefs.remove(orderIdKey);
    await prefs.remove(ownerIdKey);
  }

  static Future<RecoverySnapshot> read() async {
    final prefs = await SharedPreferences.getInstance();
    return RecoverySnapshot(
      paymentId: prefs.getInt(paymentIdKey),
      paymentOrderId: prefs.getInt(paymentOrderIdKey),
      paymentStatus: prefs.getString(paymentStatusKey),
      paymentIdempotencyKey: prefs.getString(paymentIdempotencyKey),
      orderId: prefs.getInt(orderIdKey),
      ownerId: prefs.getInt(ownerIdKey),
    );
  }

  static void debugRecovery(String message) {
    debugPrint('[Recovery.Start] $message');
  }
}

class RecoverySnapshot {
  final int? paymentId;
  final int? paymentOrderId;
  final String? paymentStatus;
  final String? paymentIdempotencyKey;
  final int? orderId;
  final int? ownerId;

  const RecoverySnapshot({
    this.paymentId,
    this.paymentOrderId,
    this.paymentStatus,
    this.paymentIdempotencyKey,
    this.orderId,
    this.ownerId,
  });
}
