import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:delivery_manager_interface/core/localization.dart';
import 'package:delivery_manager_interface/models/product_edit_request_model.dart';
import 'package:delivery_manager_interface/models/product_model.dart';
import 'package:delivery_manager_interface/services/kakao_service.dart';
import 'package:delivery_manager_interface/widgets/address_search_dialog.dart';
import 'package:delivery_manager_interface/widgets/hover_scrollbar.dart';

class ProductEditFormWidget extends StatefulWidget {
  final Product product;
  final VoidCallback onCancel;
  final VoidCallback onSuccess;

  const ProductEditFormWidget({
    super.key,
    required this.product,
    required this.onCancel,
    required this.onSuccess,
  });

  @override
  State<ProductEditFormWidget> createState() => _ProductEditFormWidgetState();
}

class _ProductEditFormWidgetState extends State<ProductEditFormWidget> {
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = true;

  late String _category;
  late String _productName;
  late String _taxType;
  late double _supplyPrice;
  late double _deliveryPrice;
  late double _shippingFee; // remote area delivery fee
  late double _returnDeliveryPrice;
  late double _freeShippingThreshold;
  late bool _noFreeShipping;
  late int _maxPackagingQuantity;
  late bool _isSingleQuantity;

  // Dynamic list of price options
  List<Map<String, dynamic>> _pricePoints = [];

  late int _deliveryMinDays;
  late int _deliveryMaxDays;
  late String _storageInfo;
  late String _instructions;
  late int _stock;

  // Image slots
  String? _mainImageUrl;
  List<String> _additionalImageUrls = [];
  final List<bool> _isUploadingImage = [false, false, false, false, false];

  late String _shippingMethod;
  List<String> _includedSigungu = [];
  List<String> _excludedEupmyeondong = [];

  final ScrollController _sigunguScrollController = ScrollController();
  final ScrollController _eupmyeondongScrollController = ScrollController();

  @override
  void dispose() {
    _sigunguScrollController.dispose();
    _eupmyeondongScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    final data = widget.product;

    _category = data.category;
    _productName = data.productName;
    _taxType = data.taxType;
    _supplyPrice = data.supplyPrice;
    _deliveryPrice = data.deliveryPrice ?? 0.0;
    _shippingFee = data.shippingFee ?? 0.0;
    _returnDeliveryPrice = data.returnDeliveryPrice;
    _freeShippingThreshold = data.freeShippingThreshold;
    _noFreeShipping = data.noFreeShipping;
    _maxPackagingQuantity = data.maxPackagingQuantity;
    _isSingleQuantity = data.isSingleQuantity;

    // Load price points
    _pricePoints =
        data.pricePoints
            .map(
              (item) => {
                'quantity': item.quantity,
                'price': item.price,
                'isMax': item.isMax ?? false,
              },
            )
            .toList();
    if (_pricePoints.isNotEmpty) {
      bool foundMax = false;
      for (var pt in _pricePoints) {
        if (pt['isMax'] == true || pt['quantity'] == _maxPackagingQuantity) {
          pt['isMax'] = true;
          foundMax = true;
          break;
        }
      }
      if (!foundMax) {
        _pricePoints.last['isMax'] = true;
      }
    } else {
      if (_isSingleQuantity) {
        _pricePoints = [
          {'quantity': 1, 'price': 10000.0, 'isMax': true},
        ];
      } else {
        _pricePoints = [
          {'quantity': _maxPackagingQuantity, 'price': 10000.0, 'isMax': true},
        ];
      }
    }

    _deliveryMinDays = data.deliveryMinDays;
    _deliveryMaxDays = data.deliveryMaxDays;
    _storageInfo = data.description;
    _instructions = data.instructions;
    _stock = data.stock;

    _mainImageUrl = data.imgUrl;
    _additionalImageUrls = List<String>.from(
      data.imgUrls.where((url) => url != null),
    );
    while (_additionalImageUrls.length < 4) {
      _additionalImageUrls.add('');
    }

    _shippingMethod = data.shippingMethod ?? '택배배송';
    _includedSigungu = [];
    _excludedEupmyeondong = [];
    if (data.address != null) {
      final addrMap = data.address!;
      if (addrMap.containsKey('includedSigungu') &&
          addrMap['includedSigungu'] is List) {
        _includedSigungu = List<String>.from(addrMap['includedSigungu']);
      } else {
        final legacyName = addrMap['address_name']?.toString() ?? '';
        if (legacyName.isNotEmpty) {
          final parts = legacyName.split(' ');
          if (parts.length >= 2) {
            _includedSigungu = ['${parts[0]} ${parts[1]}'];
          } else {
            _includedSigungu = [legacyName];
          }
        }
      }
      if (addrMap.containsKey('excludedEupmyeondong') &&
          addrMap['excludedEupmyeondong'] is List) {
        _excludedEupmyeondong = List<String>.from(
          addrMap['excludedEupmyeondong'],
        );
      }
    }
  }

  void _addIncludedSigungu() async {
    final kakaoService = KakaoApiService(
      apiKey: '772742afea4cfac8c58ed62cfa7d1777',
    );

    final result = await showDialog(
      context: context,
      builder: (context) => AddressSearchDialog(kakaoService: kakaoService),
    );

    if (!mounted) return;

    if (result != null && result is Map) {
      String? d1;
      String? d2;
      String? d3;
      if (result['address'] != null) {
        d1 = result['address']['region_1depth_name'];
        d2 = result['address']['region_2depth_name'];
        d3 = result['address']['region_3depth_name'];
      }
      if ((d3 == null || d3.isEmpty) && result['road_address'] != null) {
        d1 = result['road_address']['region_1depth_name'];
        d2 = result['road_address']['region_2depth_name'];
        d3 = result['road_address']['region_3depth_name'];
      }
      if (d3 == null || d3.isEmpty) {
        final name = result['address_name']?.toString() ?? '';
        final parts = name.split(' ');
        if (parts.length >= 3) {
          d1 = parts[0];
          d2 = parts[1];
          d3 = parts[2];
        } else if (parts.isNotEmpty) {
          d1 = parts[0];
          if (parts.length >= 2) {
            d2 = parts[1];
          }
        }
      }

      if (d1 != null && d1.isNotEmpty) {
        final newSigungu =
            (d2 != null && d2.isNotEmpty)
                ? ((d3 != null && d3.isNotEmpty) ? '$d1 $d2 $d3' : '$d1 $d2')
                : d1;
        if (!_includedSigungu.contains(newSigungu)) {
          setState(() {
            _includedSigungu.add(newSigungu);
          });
        }
      }
    }
  }

  void _addExcludedEupmyeondong() async {
    final kakaoService = KakaoApiService(
      apiKey: '772742afea4cfac8c58ed62cfa7d1777',
    );

    final result = await showDialog(
      context: context,
      builder: (context) => AddressSearchDialog(kakaoService: kakaoService),
    );

    if (!mounted) return;

    if (result != null && result is Map) {
      String? d1;
      String? d2;
      String? d3;
      if (result['address'] != null) {
        d1 = result['address']['region_1depth_name'];
        d2 = result['address']['region_2depth_name'];
        d3 = result['address']['region_3depth_name'];
      }
      if ((d3 == null || d3.isEmpty) && result['road_address'] != null) {
        d1 = result['road_address']['region_1depth_name'];
        d2 = result['road_address']['region_2depth_name'];
        d3 = result['road_address']['region_3depth_name'];
      }
      if (d3 == null || d3.isEmpty) {
        final name = result['address_name']?.toString() ?? '';
        final parts = name.split(' ');
        if (parts.length >= 3) {
          d1 = parts[0];
          d2 = parts[1];
          d3 = parts[2];
        }
      }

      if (d3 != null && d3.isNotEmpty) {
        final fullDong =
            (d1 != null && d1.isNotEmpty)
                ? ((d2 != null && d2.isNotEmpty) ? '$d1 $d2 $d3' : '$d1 $d3')
                : d3;
        if (!_excludedEupmyeondong.contains(fullDong)) {
          setState(() {
            _excludedEupmyeondong.add(fullDong);
          });
        }
      }
    }
  }

  Widget _buildBrutalistTag({
    required String label,
    required VoidCallback onDelete,
    bool isExclude = false,
  }) {
    final displayLabel = isExclude ? '- $label' : '+ $label';
    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1),
      ),
      height: 32,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              displayLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          InkWell(
            onTap: onDelete,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Colors.black, width: 1)),
                color: Colors.black,
              ),
              child: const Text(
                'x',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrutalistAddButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.black, width: 1),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.add, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildBrutalistSection({
    required String title,
    required List<String> items,
    required VoidCallback onAdd,
    required Function(int) onDelete,
    required ScrollController controller,
    bool isExclude = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: HoverScrollbar(
            controller: controller,
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    ...items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final val = entry.value;
                      final displayName = val;
                      return _buildBrutalistTag(
                        label: displayName,
                        onDelete: () => onDelete(index),
                        isExclude: isExclude,
                      );
                    }).toList(),
                    _buildBrutalistAddButton(onAdd),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadCategories() async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('categories')
              .orderBy('order')
              .get();
      if (mounted) {
        setState(() {
          _categories =
              snap.docs.map((doc) {
                return {
                  'id': doc.id,
                  'name': doc.data()['name'] ?? '',
                  'order': doc.data()['order'] ?? 0,
                };
              }).toList();
          _isLoadingCategories = false;
          if (_categories.isNotEmpty) {
            final ids = _categories.map((c) => c['id'] as String).toList();
            final names = _categories.map((c) => c['name'] as String).toList();
            if (ids.contains(_category)) {
              // Valid ID
            } else if (names.contains(_category)) {
              // Matches name, map to ID
              final matchedCat = _categories.firstWhere(
                (c) => c['name'] == _category,
              );
              _category = matchedCat['id'] as String;
            } else {
              _category = ids.first;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  void _addPricePoint() {
    if (_isSingleQuantity || _maxPackagingQuantity <= 1) return;
    if (_pricePoints.length >= 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('pe_option_limit_error'))));
      return;
    }
    if (_pricePoints.length >= _maxPackagingQuantity) return;
    setState(() {
      _pricePoints.insert(_pricePoints.length - 1, {
        'quantity': 1,
        'price': 10000.0,
      });
    });
  }

  void _removePricePoint(int index) {
    if (_pricePoints[index]['isMax'] == true || _pricePoints.length <= 1)
      return;
    setState(() {
      _pricePoints.removeAt(index);
    });
  }

  Future<void> _pickAndUploadImage(int slotIndex, bool isMain) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    final overallIndex = isMain ? 0 : slotIndex + 1;
    setState(() {
      _isUploadingImage[overallIndex] = true;
    });

    try {
      final String filename =
          'prod_${DateTime.now().millisecondsSinceEpoch}_$overallIndex.jpg';
      final ref = FirebaseStorage.instance.ref().child(
        'product_images/$filename',
      );

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(File(pickedFile.path));
      }

      final url = await ref.getDownloadURL();

      if (mounted) {
        setState(() {
          if (isMain) {
            _mainImageUrl = url;
          } else {
            _additionalImageUrls[slotIndex] = url;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('업로드 실패: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage[overallIndex] = false;
        });
      }
    }
  }

  void _showImageOptions(int slotIndex, bool isMain) {
    final url = isMain ? _mainImageUrl : _additionalImageUrls[slotIndex];
    final hasImage = url != null && url.isNotEmpty;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.black),
                title: Text(
                  tr('pe_taxable') == '과세' ? '사진 변경' : 'Change Image',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(slotIndex, isMain);
                },
              ),
              if (hasImage)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    tr('pe_taxable') == '과세' ? '사진 삭제' : 'Delete Image',
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    setState(() {
                      if (isMain) {
                        _mainImageUrl = null;
                      } else {
                        _additionalImageUrls[slotIndex] = '';
                      }
                    });
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_mainImageUrl == null || _mainImageUrl!.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('pe_image_required'))));
      return;
    }

    if (_shippingMethod == '지역배송' && _includedSigungu.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('pe_no_regions_selected'))));
      return;
    }

    // Sort price points before submitting
    if (_pricePoints.length > 1) {
      final maxPt = _pricePoints.firstWhere(
        (pt) => pt['isMax'] == true,
        orElse: () => _pricePoints.last,
      );
      final customPts =
          _pricePoints.where((pt) => pt['isMax'] != true).toList();
      customPts.sort((a, b) {
        final aQty = a['quantity'] as int? ?? 1;
        final bQty = b['quantity'] as int? ?? 1;
        return aQty.compareTo(bQty);
      });
      setState(() {
        _pricePoints = [...customPts, maxPt];
      });
    }

    final nav = Navigator.of(context);
    final sm = ScaffoldMessenger.of(context);

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              content: Row(
                children: [
                  const CircularProgressIndicator(color: Colors.black),
                  const SizedBox(width: 16),
                  Text(tr('pe_edit_requesting')),
                ],
              ),
            ),
      );

      String sellerName = '';
      final managerUid =
          (widget.product.deliveryManagerId != null &&
                  widget.product.deliveryManagerId!.isNotEmpty)
              ? widget.product.deliveryManagerId!
              : widget
                  .product
                  .sellerName; // Fallback to sellerName if deliveryManagerId is empty
      if (managerUid.isNotEmpty) {
        try {
          final doc =
              await FirebaseFirestore.instance
                  .collection('deliveryManagers')
                  .doc(managerUid)
                  .get();
          if (doc.exists) {
            final data = doc.data();
            sellerName = data?['brandName'] ?? data?['name'] ?? '';
          } else {
            final query =
                await FirebaseFirestore.instance
                    .collection('deliveryManagers')
                    .where('userId', isEqualTo: managerUid)
                    .get();
            if (query.docs.isNotEmpty) {
              final data = query.docs.first.data();
              sellerName = data['brandName'] ?? data['name'] ?? '';
            }
          }
        } catch (_) {}
      }
      if (sellerName.isEmpty) {
        sellerName = widget.product.sellerName;
      }

      final request = ProductEditRequestModel(
        id: '',
        productId: widget.product.product_id,
        sellerUid:
            (widget.product.deliveryManagerId != null &&
                    widget.product.deliveryManagerId!.isNotEmpty)
                ? widget.product.deliveryManagerId
                : null,
        requestedBy:
            (widget.product.deliveryManagerId != null &&
                    widget.product.deliveryManagerId!.isNotEmpty)
                ? widget.product.deliveryManagerId
                : null,
        sellerName: sellerName,
        category: _category,
        productName: _productName,
        taxType: _taxType,
        supplyPrice: _supplyPrice,
        deliveryPrice: _deliveryPrice,
        shippingFee: _shippingFee,
        returnDeliveryPrice: _returnDeliveryPrice,
        freeShippingThreshold: _freeShippingThreshold,
        noFreeShipping: _noFreeShipping,
        maxPackagingQuantity: _maxPackagingQuantity,
        isSingleQuantity: _isSingleQuantity,
        pricePoints: _pricePoints,
        deliveryMinDays: _deliveryMinDays,
        deliveryMaxDays: _deliveryMaxDays,
        storageInfo: _storageInfo,
        instructions: _instructions,
        stock: _stock,
        imgUrl: _mainImageUrl ?? '',
        imgUrls: _additionalImageUrls.where((url) => url.isNotEmpty).toList(),
        shippingMethod: _shippingMethod,
        address:
            _shippingMethod == '지역배송'
                ? {
                  'address_name':
                      _includedSigungu.isEmpty
                          ? ''
                          : (_includedSigungu.length == 1
                              ? _includedSigungu.first.split(' ').last
                              : '${_includedSigungu.first.split(' ').last} 외 ${_includedSigungu.length - 1}곳'),
                  'includedSigungu': _includedSigungu,
                  'excludedEupmyeondong': _excludedEupmyeondong,
                }
                : null,
        requestedAt: FieldValue.serverTimestamp(),
        status: 'pending',
      );

      await FirebaseFirestore.instance
          .collection('product_edit_requests')
          .add(request.toMap());

      nav.pop(); // pop loading dialog

      sm.showSnackBar(SnackBar(content: Text(tr('pe_req_edit_success'))));
      widget.onSuccess();
    } catch (e) {
      try {
        nav.pop();
      } catch (_) {}
      sm.showSnackBar(
        SnackBar(
          content: Text(
            tr('pe_req_edit_fail').replaceAll('{error}', e.toString()),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSectionHeader(String label) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black, width: 1),
          left: BorderSide(color: Colors.black, width: 1),
          right: BorderSide(color: Colors.black, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildBrutalistInput({
    required String prefix,
    required String initialValue,
    required FormFieldSetter<String> onSaved,
    ValueChanged<String>? onChanged,
    bool readOnly = false,
    bool isNumberOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Row(
        children: [
          if (prefix.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Text(
                prefix,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Expanded(
            child: TextFormField(
              initialValue: initialValue,
              readOnly: readOnly,
              keyboardType:
                  isNumberOnly ? TextInputType.number : TextInputType.text,
              inputFormatters:
                  isNumberOnly
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : null,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: onChanged,
              onSaved: onSaved,
              validator: (val) {
                if (val == null || val.isEmpty) return tr('pe_required_field');
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // 1. 카테고리 선택
                _buildSectionHeader(tr('pe_category_select')),
                _isLoadingCategories
                    ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      ),
                    )
                    : _categories.isEmpty
                    ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        '등록된 카테고리가 없습니다.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                    : Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                      child: Row(
                        children:
                            _categories.map((cat) {
                              final catId = cat['id'] as String;
                              final catName = cat['name'] as String;
                              final isSelected = _category == catId;
                              return Expanded(
                                child: InkWell(
                                  onTap:
                                      () => setState(() => _category = catId),
                                  child: Container(
                                    height: 40,
                                    color:
                                        isSelected
                                            ? Colors.black
                                            : Colors.white,
                                    alignment: Alignment.center,
                                    child: Text(
                                      catName,
                                      style: TextStyle(
                                        color:
                                            isSelected
                                                ? Colors.white
                                                : Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                const SizedBox(height: 20),

                // 2. 상품명
                _buildSectionHeader(tr('pe_product_name')),
                _buildBrutalistInput(
                  prefix: '',
                  initialValue: _productName,
                  readOnly: false,
                  onSaved: (val) => _productName = val ?? '',
                ),
                const SizedBox(height: 20),

                // 3. 과세 구분
                _buildSectionHeader(tr('pe_tax_classification')),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: Row(
                    children:
                        [
                          MapEntry('과세', tr('pe_taxable')),
                          MapEntry('면세', tr('pe_tax_exempt')),
                        ].map((entry) {
                          final tValue = entry.key;
                          final tDisplay = entry.value;
                          final isSelected = _taxType == tValue;
                          return Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _taxType = tValue),
                              child: Container(
                                height: 40,
                                color: isSelected ? Colors.black : Colors.white,
                                alignment: Alignment.center,
                                child: Text(
                                  tDisplay,
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // 4. 상품가격(배송비 미포함)
                _buildSectionHeader(tr('pe_product_price_excl')),
                _buildBrutalistInput(
                  prefix: '₩',
                  initialValue: _supplyPrice.toInt().toString(),
                  isNumberOnly: true,
                  onChanged: (val) {
                    setState(() {
                      _supplyPrice = double.tryParse(val) ?? 0.0;
                    });
                  },
                  onSaved:
                      (val) => _supplyPrice = double.tryParse(val ?? '') ?? 0.0,
                ),
                const SizedBox(height: 20),

                // 배송방식
                _buildSectionHeader(tr('pe_shipping_method')),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: Row(
                    children:
                        [
                          MapEntry('택배배송', tr('pe_parcel_delivery')),
                          MapEntry('지역배송', tr('pe_regional_delivery')),
                        ].map((entry) {
                          final mValue = entry.key;
                          final mDisplay = entry.value;
                          final isSelected = _shippingMethod == mValue;
                          return Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _shippingMethod = mValue;
                                  if (mValue == '택배배송') {
                                    _includedSigungu = [];
                                    _excludedEupmyeondong = [];
                                  }
                                });
                                if (mValue == '지역배송' &&
                                    _includedSigungu.isEmpty) {
                                  _addIncludedSigungu();
                                }
                              },
                              child: Container(
                                height: 40,
                                color: isSelected ? Colors.black : Colors.white,
                                alignment: Alignment.center,
                                child: Text(
                                  mDisplay,
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                if (_shippingMethod == '지역배송') ...[
                  _buildBrutalistSection(
                    title: '시, 군, 구 추가',
                    items: _includedSigungu,
                    onAdd: _addIncludedSigungu,
                    onDelete: (index) {
                      setState(() {
                        _includedSigungu.removeAt(index);
                      });
                    },
                    controller: _sigunguScrollController,
                  ),
                  const SizedBox(height: 20),
                  _buildBrutalistSection(
                    title: '읍, 면, 동 제거',
                    items: _excludedEupmyeondong,
                    onAdd: _addExcludedEupmyeondong,
                    onDelete: (index) {
                      setState(() {
                        _excludedEupmyeondong.removeAt(index);
                      });
                    },
                    isExclude: true,
                    controller: _eupmyeondongScrollController,
                  ),
                  const SizedBox(height: 20),
                ],

                // 5. 배송비 / 도서지역 추가 배송비 / 반품 배송비
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildSectionHeader(tr('pe_delivery_fee')),
                          _buildBrutalistInput(
                            prefix: '₩',
                            initialValue: _deliveryPrice.toInt().toString(),
                            isNumberOnly: true,
                            onChanged: (val) {
                              setState(() {
                                _deliveryPrice = double.tryParse(val) ?? 0.0;
                              });
                            },
                            onSaved:
                                (val) =>
                                    _deliveryPrice =
                                        double.tryParse(val ?? '') ?? 0.0,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          _buildSectionHeader(tr('pe_remote_island_fee')),
                          _buildBrutalistInput(
                            prefix: '₩',
                            initialValue: _shippingFee.toInt().toString(),
                            isNumberOnly: true,
                            onSaved:
                                (val) =>
                                    _shippingFee =
                                        double.tryParse(val ?? '') ?? 0.0,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          _buildSectionHeader(tr('pe_return_delivery_fee')),
                          _buildBrutalistInput(
                            prefix: '₩',
                            initialValue:
                                _returnDeliveryPrice.toInt().toString(),
                            isNumberOnly: true,
                            onSaved:
                                (val) =>
                                    _returnDeliveryPrice =
                                        double.tryParse(val ?? '') ?? 0.0,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 6. ~이상 구매 시 무료배송
                _buildSectionHeader(tr('pe_free_shipping_over')),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 12.0),
                              child: Text(
                                '₩',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextFormField(
                                initialValue:
                                    _freeShippingThreshold.toInt().toString(),
                                enabled: !_noFreeShipping,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _freeShippingThreshold =
                                        double.tryParse(val) ?? 0.0;
                                  });
                                },
                                onSaved:
                                    (val) =>
                                        _freeShippingThreshold =
                                            double.tryParse(val ?? '') ?? 0.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.black),
                      Expanded(
                        flex: 1,
                        child: InkWell(
                          onTap:
                              () => setState(
                                () => _noFreeShipping = !_noFreeShipping,
                              ),
                          child: Container(
                            height: 40,
                            color:
                                _noFreeShipping ? Colors.black : Colors.white,
                            alignment: Alignment.center,
                            child: Text(
                              tr('pe_no_free_shipping'),
                              style: TextStyle(
                                color:
                                    _noFreeShipping
                                        ? Colors.white
                                        : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 7. 1상자 최대 포장수량
                _buildSectionHeader(tr('pe_max_pkg_qty')),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: _maxPackagingQuantity.toString(),
                          enabled: !_isSingleQuantity,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val) ?? 1;
                            setState(() {
                              _maxPackagingQuantity = parsed;
                              for (var pt in _pricePoints) {
                                if (pt['isMax'] == true) {
                                  pt['quantity'] = parsed;
                                }
                              }
                              _pricePoints.removeWhere(
                                (pt) =>
                                    pt['isMax'] != true &&
                                    pt['quantity'] >= parsed,
                              );
                              while (_pricePoints.length > parsed &&
                                  _pricePoints.length > 1) {
                                _pricePoints.removeAt(_pricePoints.length - 2);
                              }
                              if (parsed <= 1) {
                                _pricePoints.removeWhere(
                                  (pt) => pt['isMax'] != true,
                                );
                              }
                            });
                          },
                          validator: (val) {
                            final parsed = int.tryParse(val ?? '') ?? 0;
                            if (parsed <= 0) {
                              return '1 이상';
                            }
                            return null;
                          },
                          onSaved: (val) {
                            final parsed = int.tryParse(val ?? '') ?? 1;
                            _maxPackagingQuantity = parsed;
                            for (var pt in _pricePoints) {
                              if (pt['isMax'] == true) {
                                pt['quantity'] = parsed;
                              }
                            }
                            _pricePoints.removeWhere(
                              (pt) =>
                                  pt['isMax'] != true &&
                                  pt['quantity'] >= parsed,
                            );
                            while (_pricePoints.length > parsed &&
                                _pricePoints.length > 1) {
                              _pricePoints.removeAt(_pricePoints.length - 2);
                            }
                            if (parsed <= 1) {
                              _pricePoints.removeWhere(
                                (pt) => pt['isMax'] != true,
                              );
                            }
                          },
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.black),
                      Expanded(
                        flex: 1,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _isSingleQuantity = !_isSingleQuantity;
                              if (_isSingleQuantity) {
                                _pricePoints = [
                                  {
                                    'quantity': 1,
                                    'price': 10000.0,
                                    'isMax': true,
                                  },
                                ];
                              } else {
                                _pricePoints = [
                                  {
                                    'quantity': _maxPackagingQuantity,
                                    'price': 10000.0,
                                    'isMax': true,
                                  },
                                ];
                              }
                            });
                          },
                          child: Container(
                            height: 40,
                            color:
                                _isSingleQuantity ? Colors.black : Colors.white,
                            alignment: Alignment.center,
                            child: Text(
                              tr('pe_single_qty'),
                              style: TextStyle(
                                color:
                                    _isSingleQuantity
                                        ? Colors.white
                                        : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 8. 수량 가격 옵션
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(2),
                      },
                      border: TableBorder.all(color: Colors.black, width: 1),
                      children: [
                        TableRow(
                          children: [
                            Container(
                              height: 40,
                              alignment: Alignment.center,
                              child: Text(
                                tr('pe_qty_direct_input'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Container(
                              height: 40,
                              alignment: Alignment.center,
                              child: Text(
                                tr('pe_product_price'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        ...List.generate(_pricePoints.length, (index) {
                          final pt = _pricePoints[index];
                          final bool isMaxRow =
                              pt['isMax'] == true || _isSingleQuantity;

                          // Calculate using formula: qty * supplyPrice + (isFreeShipping ? 0 : deliveryPrice)
                          final int qty = pt['quantity'] as int? ?? 1;
                          final bool isFreeShipping =
                              !_noFreeShipping &&
                              (qty * _supplyPrice >= _freeShippingThreshold);
                          final double calculatedPrice =
                              qty * _supplyPrice +
                              (isFreeShipping ? 0.0 : _deliveryPrice);

                          // Sync calculated price in memory list
                          _pricePoints[index]['price'] = calculatedPrice;

                          return TableRow(
                            children: [
                              TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: TextFormField(
                                  initialValue: pt['quantity'].toString(),
                                  key: ObjectKey(pt),
                                  textAlign: TextAlign.center,
                                  readOnly: isMaxRow,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    TextInputFormatter.withFunction((
                                      oldValue,
                                      newValue,
                                    ) {
                                      if (newValue.text.isEmpty) {
                                        return newValue;
                                      }
                                      final parsed = int.tryParse(
                                        newValue.text,
                                      );
                                      if (parsed == null) return oldValue;
                                      if (parsed >= _maxPackagingQuantity) {
                                        return oldValue;
                                      }
                                      return newValue;
                                    }),
                                  ],
                                  style: const TextStyle(fontSize: 13),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  onChanged: (val) {
                                    if (isMaxRow) return;
                                    final parsedQty = int.tryParse(val) ?? 1;
                                    setState(() {
                                      _pricePoints[index]['quantity'] =
                                          parsedQty;
                                    });
                                  },
                                  validator: (val) {
                                    if (isMaxRow) return null;
                                    final parsedQty =
                                        int.tryParse(val ?? '') ?? 0;
                                    if (parsedQty <= 0) return '1 이상';
                                    if (!_isSingleQuantity) {
                                      if (parsedQty >= _maxPackagingQuantity) {
                                        return '최대 ${_maxPackagingQuantity - 1}';
                                      }
                                    }
                                    // Check for duplicate quantities
                                    for (
                                      int i = 0;
                                      i < _pricePoints.length;
                                      i++
                                    ) {
                                      if (i != index &&
                                          _pricePoints[i]['quantity'] ==
                                              parsedQty) {
                                        return tr('pe_duplicate_qty_error');
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Row(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                      ),
                                      child: Text(
                                        '₩',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        calculatedPrice.toInt().toString(),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed:
                                          isMaxRow
                                              ? null
                                              : () => _removePricePoint(index),
                                      child: Text(
                                        isMaxRow
                                            ? (tr('pe_taxable') == '과세'
                                                ? '(삭제 불가)'
                                                : '(Cannot delete)')
                                            : (tr('pe_taxable') == '과세'
                                                ? '(삭제)'
                                                : '(Delete)'),
                                        style: TextStyle(
                                          color:
                                              isMaxRow
                                                  ? Colors.grey
                                                  : Colors.black,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed:
                          (_isSingleQuantity ||
                                  _maxPackagingQuantity <= 1 ||
                                  _pricePoints.length >= _maxPackagingQuantity)
                              ? null
                              : _addPricePoint,
                      icon: Icon(
                        Icons.add,
                        size: 16,
                        color:
                            (_isSingleQuantity ||
                                    _maxPackagingQuantity <= 1 ||
                                    _pricePoints.length >=
                                        _maxPackagingQuantity)
                                ? Colors.grey
                                : Colors.black,
                      ),
                      label: Text(
                        tr('pe_add_price_option'),
                        style: TextStyle(
                          color:
                              (_isSingleQuantity ||
                                      _maxPackagingQuantity <= 1 ||
                                      _pricePoints.length >=
                                          _maxPackagingQuantity)
                                  ? Colors.grey
                                  : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 9. 배송일
                _buildSectionHeader(tr('pe_delivery_days')),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '[',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        child: TextFormField(
                          initialValue: _deliveryMinDays.toString(),
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSaved:
                              (val) =>
                                  _deliveryMinDays =
                                      int.tryParse(val ?? '') ?? 1,
                        ),
                      ),
                      Text(
                        ']${tr('pe_days')}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          '~',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Text(
                        '[',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        child: TextFormField(
                          initialValue: _deliveryMaxDays.toString(),
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSaved:
                              (val) =>
                                  _deliveryMaxDays =
                                      int.tryParse(val ?? '') ?? 3,
                        ),
                      ),
                      Text(
                        ']${tr('pe_days')}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 10. 보관법 및 소비기한
                _buildSectionHeader(tr('pe_storage_info')),
                _buildBrutalistInput(
                  prefix: '',
                  initialValue: _storageInfo,
                  onSaved: (val) => _storageInfo = val ?? '',
                ),
                const SizedBox(height: 20),

                // 11. 제품 안내
                _buildSectionHeader(tr('pe_product_guide')),
                _buildBrutalistInput(
                  prefix: '',
                  initialValue: _instructions,
                  onSaved: (val) => _instructions = val ?? '',
                ),
                const SizedBox(height: 20),

                // 12. 이미지 업로드 슬롯
                _buildSectionHeader(tr('pe_image_list_title')),
                Table(
                  border: TableBorder.all(color: Colors.black, width: 1),
                  children: [
                    TableRow(
                      children:
                          [
                            tr('pe_main_image'),
                            tr('pe_add_image_1'),
                            tr('pe_add_image_2'),
                            tr('pe_add_image_3'),
                            tr('pe_add_image_4'),
                          ].map((imgHeader) {
                            return Container(
                              height: 36,
                              alignment: Alignment.center,
                              child: Text(
                                imgHeader,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    TableRow(
                      children: List.generate(5, (index) {
                        final isMain = index == 0;
                        final url =
                            isMain
                                ? _mainImageUrl
                                : _additionalImageUrls[index - 1];
                        final hasImage = url != null && url.isNotEmpty;
                        final isUploading = _isUploadingImage[index];

                        return InkWell(
                          onTap:
                              isUploading
                                  ? null
                                  : () {
                                    if (hasImage) {
                                      _showImageOptions(
                                        isMain ? 0 : index - 1,
                                        isMain,
                                      );
                                    } else {
                                      _pickAndUploadImage(
                                        isMain ? 0 : index - 1,
                                        isMain,
                                      );
                                    }
                                  },
                          child: Container(
                            height: 80,
                            alignment: Alignment.center,
                            child:
                                isUploading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                    : hasImage
                                    ? Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, o, s) {
                                        return const Icon(
                                          Icons.broken_image,
                                          size: 24,
                                          color: Colors.grey,
                                        );
                                      },
                                    )
                                    : const Icon(
                                      Icons.add,
                                      size: 20,
                                      color: Colors.black45,
                                    ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 13. 재고
                _buildSectionHeader(tr('pe_stock')),
                _buildBrutalistInput(
                  prefix: '',
                  initialValue: _stock.toString(),
                  isNumberOnly: true,
                  onSaved: (val) => _stock = int.tryParse(val ?? '') ?? 0,
                ),
                const SizedBox(height: 30),

                // Information guide box 1: 제품 및 서비스 입점 안내
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('pe_guide_proposal_title'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('pe_guide_proposal_1'),
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                      Text(
                        tr('pe_guide_proposal_2'),
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                      Text(
                        tr('pe_guide_proposal_3'),
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Information guide box 2: 정산일 및 결제 수수료 안내
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('pe_guide_settlement_title'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('pe_guide_settlement_1'),
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                      Text(
                        tr('pe_guide_settlement_2'),
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                      Text(
                        tr('pe_guide_settlement_3'),
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  tr('pe_prob_high_title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  tr('pe_prob_high_1'),
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
                Text(
                  tr('pe_prob_high_2'),
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
                Text(
                  tr('pe_prob_high_3'),
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),

                Text(
                  tr('pe_prob_reject_title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  tr('pe_prob_reject_1'),
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
                Text(
                  tr('pe_prob_reject_2'),
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
                Text(
                  tr('pe_prob_reject_3'),
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
                Text(
                  tr('pe_prob_reject_4'),
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 24),

                // Submit request button
                Center(
                  child: Column(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          fixedSize: const Size(300, 60),
                        ),
                        onPressed: _submitRequest,
                        child: Text(
                          tr('pe_request_edit'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('pe_review_desc'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
