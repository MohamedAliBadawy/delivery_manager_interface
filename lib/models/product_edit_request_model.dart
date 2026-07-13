class ProductEditRequestModel {
  final String id;
  final String productId;
  final bool? isNewProduct;
  final String? sellerUid;
  final String? requestedBy;
  final String? sellerName;
  final String? marketLink;
  final String? shippingMethod;
  final Map<String, dynamic>? address;
  final String category;
  final String productName;
  final String taxType;
  final double supplyPrice;
  final double deliveryPrice;
  final double shippingFee;
  final double returnDeliveryPrice;
  final double freeShippingThreshold;
  final bool noFreeShipping;
  final int maxPackagingQuantity;
  final bool isSingleQuantity;
  final List<Map<String, dynamic>> pricePoints;
  final int deliveryMinDays;
  final int deliveryMaxDays;
  final String storageInfo;
  final String instructions;
  final int stock;
  final String imgUrl;
  final List<String> imgUrls;
  final dynamic requestedAt; // Can be Timestamp or FieldValue
  final String status;

  ProductEditRequestModel({
    required this.id,
    required this.productId,
    this.isNewProduct,
    this.sellerUid,
    this.requestedBy,
    this.sellerName,
    this.marketLink,
    this.shippingMethod,
    this.address,
    required this.category,
    required this.productName,
    required this.taxType,
    required this.supplyPrice,
    required this.deliveryPrice,
    required this.shippingFee,
    required this.returnDeliveryPrice,
    required this.freeShippingThreshold,
    required this.noFreeShipping,
    required this.maxPackagingQuantity,
    required this.isSingleQuantity,
    required this.pricePoints,
    required this.deliveryMinDays,
    required this.deliveryMaxDays,
    required this.storageInfo,
    required this.instructions,
    required this.stock,
    required this.imgUrl,
    required this.imgUrls,
    required this.requestedAt,
    required this.status,
  });

  factory ProductEditRequestModel.fromMap(String docId, Map<String, dynamic> map) {
    return ProductEditRequestModel(
      id: docId,
      productId: map['product_id'] ?? '',
      isNewProduct: map['isNewProduct'] as bool?,
      sellerUid: map['sellerUid'] as String?,
      requestedBy: map['requested_by'] as String?,
      sellerName: map['sellerName'] as String?,
      marketLink: map['marketLink'] as String?,
      shippingMethod: map['shippingMethod'] as String?,
      address: map['address'] as Map<String, dynamic>?,
      category: map['category'] ?? '',
      productName: map['productName'] ?? '',
      taxType: map['taxType'] ?? '',
      supplyPrice: (map['supplyPrice'] ?? 0.0).toDouble(),
      deliveryPrice: (map['deliveryPrice'] ?? 0.0).toDouble(),
      shippingFee: (map['shippingFee'] ?? 0.0).toDouble(),
      returnDeliveryPrice: (map['returnDeliveryPrice'] ?? 0.0).toDouble(),
      freeShippingThreshold: (map['freeShippingThreshold'] ?? 0.0).toDouble(),
      noFreeShipping: map['noFreeShipping'] ?? false,
      maxPackagingQuantity: map['maxPackagingQuantity'] ?? 1,
      isSingleQuantity: map['isSingleQuantity'] ?? false,
      pricePoints: List<Map<String, dynamic>>.from(
        (map['pricePoints'] as List?)?.map(
          (item) => Map<String, dynamic>.from(item as Map),
        ) ?? [],
      ),
      deliveryMinDays: map['deliveryMinDays'] ?? 1,
      deliveryMaxDays: map['deliveryMaxDays'] ?? 3,
      storageInfo: map['storageInfo'] ?? '',
      instructions: map['instructions'] ?? '',
      stock: map['stock'] ?? 0,
      imgUrl: map['imgUrl'] ?? '',
      imgUrls: List<String>.from(map['imgUrls'] ?? []),
      requestedAt: map['requested_at'],
      status: map['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      if (isNewProduct != null) 'isNewProduct': isNewProduct,
      if (sellerUid != null) 'sellerUid': sellerUid,
      if (requestedBy != null) 'requested_by': requestedBy,
      if (sellerName != null) 'sellerName': sellerName,
      if (marketLink != null) 'marketLink': marketLink,
      if (shippingMethod != null) 'shippingMethod': shippingMethod,
      'address': address,
      'category': category,
      'productName': productName,
      'taxType': taxType,
      'supplyPrice': supplyPrice,
      'deliveryPrice': deliveryPrice,
      'shippingFee': shippingFee,
      'returnDeliveryPrice': returnDeliveryPrice,
      'freeShippingThreshold': freeShippingThreshold,
      'noFreeShipping': noFreeShipping,
      'maxPackagingQuantity': maxPackagingQuantity,
      'isSingleQuantity': isSingleQuantity,
      'pricePoints': pricePoints,
      'deliveryMinDays': deliveryMinDays,
      'deliveryMaxDays': deliveryMaxDays,
      'storageInfo': storageInfo,
      'instructions': instructions,
      'stock': stock,
      'imgUrl': imgUrl,
      'imgUrls': imgUrls,
      'requested_at': requestedAt,
      'status': status,
    };
  }
}
