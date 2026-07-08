// models/product_model.dart

import 'dart:core';

import 'package:delivery_manager_interface/core/helpers/to_double.dart';

class PricePoint {
  int quantity;
  double price;
  bool? isMax;

  PricePoint({required this.quantity, required this.price, this.isMax});

  Map<String, dynamic> toMap() {
    return {
      'quantity': quantity,
      'price': price,
      if (isMax != null) 'isMax': isMax,
    };
  }

  factory PricePoint.fromMap(Map<String, dynamic> map) {
    return PricePoint(
      quantity: map['quantity'] ?? 1,
      price: toDouble(map['price']),
      isMax: map['isMax'] as bool?,
    );
  }
}

class Product {
  final String product_id;
  final String productName;
  final String sellerName;
  final String instructions;
  final String category;
  final int stock;
  final double price;
  final double supplyPrice;
  double? deliveryPrice;
  double? marginRate;
  double? shippingFee;
  double? estimatedSettlement;
  String? estimatedSettlementDate;
  final int baselineTime;
  final List<PricePoint> pricePoints;
  final bool freeShipping;
  final String meridiem;
  final String? imgUrl;
  final List<String?> imgUrls;
  final String? deliveryManagerId;
  final String taxType;
  final double returnDeliveryPrice;
  final double freeShippingThreshold;
  final bool noFreeShipping;
  final int maxPackagingQuantity;
  final bool isSingleQuantity;
  final int deliveryMinDays;
  final int deliveryMaxDays;
  final String storageInfo;
  final String? shippingMethod;
  final Map<String, dynamic>? address;

  Product({
    required this.product_id,
    required this.productName,
    required this.sellerName,
    required this.category,
    required this.freeShipping,
    required this.instructions,
    required this.stock,
    required this.price,
    required this.supplyPrice,
    this.deliveryPrice,
    this.marginRate,
    this.shippingFee,
    this.estimatedSettlement,
    this.estimatedSettlementDate,
    required this.baselineTime,
    required this.meridiem,
    required this.imgUrl,
    required this.imgUrls,
    required this.pricePoints,
    required this.deliveryManagerId,
    this.taxType = '과세',
    this.returnDeliveryPrice = 5000.0,
    this.freeShippingThreshold = 20000.0,
    this.noFreeShipping = false,
    this.maxPackagingQuantity = 50,
    this.isSingleQuantity = false,
    this.deliveryMinDays = 1,
    this.deliveryMaxDays = 3,
    this.storageInfo = '',
    this.shippingMethod = '택배배송',
    this.address,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    final rawPricePoints = map['pricePoints'] as List?;
    final parsedPricePoints = rawPricePoints
            ?.map((pp) => PricePoint.fromMap(Map<String, dynamic>.from(pp as Map)))
            .toList() ??
        [];
    final firstPrice = parsedPricePoints.isNotEmpty ? parsedPricePoints[0].price : toDouble(map['price']);

    return Product(
      product_id: map['product_id'] ?? '',
      productName: map['productName'] ?? '',
      instructions: map['instructions'] ?? '',
      stock: map['stock'] ?? 0,
      supplyPrice: toDouble(map['supplyPrice']),
      price: firstPrice,
      baselineTime: map['baselineTime'] ?? 0,
      meridiem: map['meridiem'] ?? 'AM',
      imgUrl: map['imgUrl'],
      imgUrls: List<String?>.from(map['imgUrls'] ?? []),
      sellerName: map['sellerName'] ?? '',
      category: map['category'] ?? '',
      pricePoints: parsedPricePoints,
      freeShipping: map['freeShipping'] ?? false,
      deliveryManagerId: map['deliveryManagerId'] ?? '',
      deliveryPrice: toDouble(map['deliveryPrice']),
      marginRate: toDouble(map['marginRate']),
      shippingFee: toDouble(map['shippingFee']),
      estimatedSettlement: toDouble(map['estimatedSettlement']),
      estimatedSettlementDate: map['estimatedSettlementDate'] ?? '',
      taxType: map['taxType'] ?? '과세',
      returnDeliveryPrice: toDouble(map['returnDeliveryPrice'] ?? 5000.0),
      freeShippingThreshold: toDouble(map['freeShippingThreshold'] ?? 20000.0),
      noFreeShipping: map['noFreeShipping'] ?? false,
      maxPackagingQuantity: map['maxPackagingQuantity'] ?? 50,
      isSingleQuantity: map['isSingleQuantity'] ?? false,
      deliveryMinDays: map['deliveryMinDays'] ?? 1,
      deliveryMaxDays: map['deliveryMaxDays'] ?? 3,
      storageInfo: map['storageInfo'] ?? '',
      shippingMethod: map['shippingMethod'] as String? ?? '택배배송',
      address: map['address'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': product_id,
      'productName': productName,
      'instructions': instructions,
      'stock': stock,
      'price': price,
      'supplyPrice': supplyPrice,
      'deliveryPrice': deliveryPrice,
      'marginRate': marginRate,
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
      'taxType': taxType,
      'returnDeliveryPrice': returnDeliveryPrice,
      'freeShippingThreshold': freeShippingThreshold,
      'noFreeShipping': noFreeShipping,
      'maxPackagingQuantity': maxPackagingQuantity,
      'isSingleQuantity': isSingleQuantity,
      'deliveryMinDays': deliveryMinDays,
      'deliveryMaxDays': deliveryMaxDays,
      'storageInfo': storageInfo,
      'shippingMethod': shippingMethod,
      'address': address,
    };
  }
}
