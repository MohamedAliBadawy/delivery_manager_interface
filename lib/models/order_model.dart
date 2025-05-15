import 'package:intl/intl.dart';

class MyOrder {
  String orderId;
  String cashReceipt;
  String courier;
  String deliveryAddress;
  String deliveryInstructions;
  String orderStatus;
  String paymentMethod;
  String productId;
  int quantity;
  double totalPrice;
  String orderDate;
  Map<String, dynamic> trackingEvents;
  String trackingNumber;
  String userId;
  String deliveryManagerId;
  String deliveryManager;
  MyOrder({
    required this.orderId,
    required this.userId,
    required this.cashReceipt,
    required this.courier,
    required this.deliveryAddress,
    required this.deliveryInstructions,
    required this.orderStatus,
    required this.paymentMethod,
    required this.productId,
    required this.quantity,
    required this.totalPrice,
    required this.orderDate,
    required this.trackingEvents,
    required this.trackingNumber,
    required this.deliveryManagerId,
    required this.deliveryManager,
  });

  Map<String, Object?> toDocument() {
    return {
      'orderId': orderId,
      'userId': userId,
      'cashReceipt': cashReceipt,
      'courier': courier,
      'deliveryAddress': deliveryAddress,
      'deliveryInstructions': deliveryInstructions,
      'orderStatus': orderStatus,
      'paymentMethod': paymentMethod,
      'productId': productId,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'orderDate': orderDate,
      'trackingEvents': trackingEvents,
      'trackingNumber': trackingNumber,
      'deliveryManagerId': deliveryManagerId,
      'deliveryManager': deliveryManager,
    };
  }

  static MyOrder fromDocument(Map<String, dynamic> doc) {
    return MyOrder(
      orderId: doc['orderId'] ?? '',
      userId: doc['userId'] ?? '',
      cashReceipt: doc['cashReceipt'] ?? '',
      courier: doc['courier'] ?? '',
      deliveryAddress: doc['deliveryAddress'] ?? '',
      deliveryInstructions: doc['deliveryInstructions'] ?? '',
      orderStatus: doc['orderStatus'] ?? '',
      paymentMethod: doc['paymentMethod'] ?? '',
      productId: doc['productId'] ?? '',
      quantity: doc['quantity'] ?? 0,
      totalPrice: doc['totalPrice'] ?? 0.0,
      orderDate: doc['orderDate'] ?? '',
      trackingEvents: doc['trackingEvents'] ?? {},
      trackingNumber: doc['trackingNumber'] ?? '',
      deliveryManagerId: doc['deliveryManagerId'] ?? '',
      deliveryManager: doc['deliveryManager'] ?? '',
    );
  }

  String get formattedOrderDate {
    final formatter = DateFormat('MM/dd/yyyy, hh:mm a');
    return formatter.format(DateTime.parse(orderDate));
  }
}
