// models/product_model.dart

import 'dart:core';

class PricePoint {
  int quantity;
  int price;

  PricePoint({required this.quantity, required this.price});

  Map<String, dynamic> toMap() {
    return {'quantity': quantity, 'price': price};
  }

  factory PricePoint.fromMap(Map<String, dynamic> map) {
    return PricePoint(quantity: map['quantity'], price: map['price']);
  }
}

class Product {
  final String product_id;
  final String productName;
  final String sellerName;
  final String instructions;
  final String category;
  final int stock;
  final int price;
  int? deliveryPrice;
  int? shippingFee;
  int? estimatedSettlement;
  String? estimatedSettlementDate;
  final int baselineTime;
  final List<PricePoint> pricePoints;
  final bool freeShipping;
  final String meridiem;
  final String? imgUrl;
  final List<String?> imgUrls;
  final String? deliveryManagerId;

  Product({
    required this.product_id,
    required this.productName,
    required this.sellerName,
    required this.category,
    required this.freeShipping,
    required this.instructions,
    required this.stock,
    required this.price,
    this.deliveryPrice,
    this.shippingFee,
    this.estimatedSettlement,
    this.estimatedSettlementDate,
    required this.baselineTime,
    required this.meridiem,
    required this.imgUrl,
    required this.imgUrls,
    required this.pricePoints,
    required this.deliveryManagerId,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      product_id: map['product_id'],
      productName: map['productName'] ?? '',
      instructions: map['instructions'] ?? '',
      stock: map['stock'] ?? 0,
      price:
          (map['pricePoints'] as List?)
              ?.map((pp) => PricePoint.fromMap(pp))
              .toList()[0]
              .price ??
          0,
      baselineTime: map['baselineTime'] ?? 0,
      meridiem: map['meridiem'] ?? 'AM',
      imgUrl: map['imgUrl'],
      imgUrls: List<String?>.from(map['imgUrls'] ?? []),
      sellerName: map['sellerName'] ?? '',
      category: map['category'] ?? '',
      pricePoints:
          (map['pricePoints'] as List?)
              ?.map((pp) => PricePoint.fromMap(pp))
              .toList() ??
          [],
      freeShipping: map['freeShipping'] ?? false,
      deliveryManagerId: map['deliveryManagerId'] ?? '',
      deliveryPrice: map['deliveryPrice'] ?? 0,
      shippingFee: map['shippingFee'] ?? 0,
      estimatedSettlement: map['estimatedSettlement'] ?? 0,
      estimatedSettlementDate: map['estimatedSettlementDate'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': product_id,
      'productName': productName,
      'instructions': instructions,
      'stock': stock,
      'price': price,
      'deliveryPrice': deliveryPrice,
      'shippingFee': shippingFee,
      'estimatedSettlement': estimatedSettlement,
      'estimatedSettlementDate': estimatedSettlementDate,
      'baselineTime': baselineTime,
      'meridiem': meridiem,
      'imgUrl': imgUrl,
      'imgUrls': imgUrls,
      'sellerName': sellerName,
      'category': category,
      'freeShipping': freeShipping,
      'pricePoints': pricePoints.map((pp) => pp.toMap()).toList(),
      'deliveryManagerId': deliveryManagerId,
    };
  }
}
