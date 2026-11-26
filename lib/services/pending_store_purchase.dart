import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Device-local checkout guard, never an entitlement or proof of payment.
class StorePurchase {
  final String store, transactionId, productId, identifierKind;
  final DateTime? purchaseDate;
  const StorePurchase(this.store, this.transactionId, this.productId,
      {this.purchaseDate, this.identifierKind = 'store'});
  Map<String, dynamic> toJson() => {
        'store': store,
        'transactionId': transactionId,
        'productId': productId,
        'identifierKind': identifierKind,
        'purchaseDate': purchaseDate?.toUtc().toIso8601String()
      };
  factory StorePurchase.fromJson(Map<String, dynamic> json) => StorePurchase(
      json['store'] as String,
      json['transactionId'] as String,
      json['productId'] as String,
      purchaseDate: DateTime.tryParse(json['purchaseDate']?.toString() ?? ''),
      identifierKind: _kind(json));
  static String _kind(Map<String, dynamic> json) {
    final kind = json['identifierKind'] ?? 'store';
    if (kind != 'store' && kind != 'revenuecat') {
      throw const FormatException('Unknown receipt identity');
    }
    return kind as String;
  }
}

class PendingStorePurchase {
  final String productId;
  final DateTime startedAt;
  final StorePurchase? receipt;
  const PendingStorePurchase(this.productId, this.startedAt, {this.receipt});
  PendingStorePurchase withReceipt(StorePurchase value) =>
      PendingStorePurchase(productId, startedAt, receipt: value);
  Map<String, dynamic> toJson() => {
        'productId': productId,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'receipt': receipt?.toJson()
      };
  factory PendingStorePurchase.fromJson(Map<String, dynamic> json) =>
      PendingStorePurchase(json['productId'] as String,
          DateTime.parse(json['startedAt'] as String),
          receipt: json['receipt'] is Map
              ? StorePurchase.fromJson(
                  Map<String, dynamic>.from(json['receipt']))
              : null);
}

class PendingPurchaseStorage {
  static Future<void> _tail = Future.value();
  static Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}).catchError((Object _) {});
    return result;
  }

  /// Reserve before the native SDK can charge. All open paywalls share this guard.
  Future<PendingStorePurchase> reserve(String user, String product) =>
      _serialized(() async {
        if (await read(user) != null) {
          throw const PendingCheckoutException();
        }
        final value = PendingStorePurchase(product, DateTime.now().toUtc());
        await save(user, value);
        return value;
      });

  String _key(String user) =>
      'zullo.pending_purchase.v1.${Uri.encodeComponent(user)}';
  Future<PendingStorePurchase?> read(String user) async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_key(user));
    if (value == null) return null;
    // A damaged record must fail closed, not silently allow another charge.
    return PendingStorePurchase.fromJson(
        Map<String, dynamic>.from(jsonDecode(value)));
  }

  Future<bool> attachReceipt(
          String user, PendingStorePurchase expected, StorePurchase receipt) =>
      _serialized(() async {
        final actual = await read(user);
        if (actual == null ||
            actual.productId != expected.productId ||
            actual.startedAt != expected.startedAt) {
          return false;
        }
        await save(user, expected.withReceipt(receipt));
        return true;
      });

  Future<void> save(String user, PendingStorePurchase value) async {
    if (!await (await SharedPreferences.getInstance())
        .setString(_key(user), jsonEncode(value.toJson()))) {
      throw StateError('Pending checkout could not be saved');
    }
  }

  Future<void> clear(String user, {PendingStorePurchase? expected}) =>
      _serialized(() async {
        if (expected != null) {
          final actual = await read(user);
          if (actual == null ||
              actual.productId != expected.productId ||
              actual.startedAt != expected.startedAt) {
            return;
          }
        }
        if (!await (await SharedPreferences.getInstance()).remove(_key(user))) {
          throw StateError('Pending checkout could not be cleared');
        }
      });
}

class PendingCheckoutException implements Exception {
  const PendingCheckoutException();
}
