import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:delivery_manager_interface/core/localization.dart';
import 'package:delivery_manager_interface/widgets/proposal_list_tab.dart';
import 'package:delivery_manager_interface/services/kakao_service.dart';
import 'package:delivery_manager_interface/widgets/address_search_dialog.dart';
import 'package:delivery_manager_interface/models/product_edit_request_model.dart';

class ProductProposalForm extends StatefulWidget {
  final String uid;

  const ProductProposalForm({super.key, required this.uid});

  @override
  State<ProductProposalForm> createState() => _ProductProposalFormState();
}

class _ProductProposalFormState extends State<ProductProposalForm> {
  final _formKey = GlobalKey<FormState>();

  String _marketLink = '';
  String _shippingMethod = '택배배송';
  String _category = '식품';
  String _productName = '';
  String _taxType = '과세';
  double _supplyPrice = 10000.0;
  double _deliveryPrice = 4000.0;
  double _shippingFee = 5000.0; // remote area delivery fee
  double _returnDeliveryPrice = 5000.0;
  double _freeShippingThreshold = 20000.0;
  bool _noFreeShipping = false;
  int _maxPackagingQuantity = 1;
  bool _isSingleQuantity = false;

  // Dynamic list of price options (Custom quantities)
  List<Map<String, dynamic>> _pricePoints = [
    {'quantity': 1, 'price': 14000.0, 'isMax': true},
  ];

  Map<String, dynamic>? _address;
  Map<String, dynamic>? _originalAddress;
  bool _removeEmdLimit = false;

  int _deliveryMinDays = 1;
  int _deliveryMaxDays = 3;
  String _storageInfo = '';
  String _instructions = '';
  int _stock = 0;

  // Image slots
  String? _mainImageUrl;
  List<String> _additionalImageUrls = ['', '', '', ''];
  final List<bool> _isUploadingImage = [false, false, false, false, false];

  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = true;
  int _proposalSubTabIndex = 1; // 0 for '제안 목록', 1 for '상품 입점 제안'

  @override
  void initState() {
    super.initState();
    _loadCategories();
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
            final names = _categories.map((c) => c['name'] as String).toList();
            if (!names.contains(_category)) {
              _category = names.first;
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

  void searchAddress() async {
    final kakaoService = KakaoApiService(
      apiKey: '772742afea4cfac8c58ed62cfa7d1777',
    );

    final result = await showDialog(
      context: context,
      builder: (context) => AddressSearchDialog(kakaoService: kakaoService),
    );

    if (!mounted) return;

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _originalAddress = Map<String, dynamic>.from(result);
        _address = Map<String, dynamic>.from(result);
        if (_removeEmdLimit) {
          final name = _address!['address_name']?.toString() ?? '';
          final parts = name.split(' ');
          if (parts.length > 2) {
            _address!['address_name'] = parts.take(2).join(' ');
          }
        }
      });
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
      // Insert before the last item (which is the max packaging quantity row)
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
          'prod_${widget.uid}_${DateTime.now().millisecondsSinceEpoch}_$overallIndex.jpg';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('pe_upload_failed').replaceAll('{error}', e.toString()),
            ),
          ),
        );
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
                title: Text(tr('pe_change_image')),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(slotIndex, isMain);
                },
              ),
              if (hasImage)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    tr('pe_delete_image'),
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

  Future<void> _submitProposal() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_shippingMethod == '지역배송' && _address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('pe_no_regions_selected')),
        ),
      );
      return;
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
                  Text(tr('pe_proposing')),
                ],
              ),
            ),
      );

      // Sort price points before constructing finalPricePoints
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

      // Construct final price points list (including the fixed max pack quantity row if not single quantity)
      final List<Map<String, dynamic>> finalPricePoints = [];
      for (final pt in _pricePoints) {
        finalPricePoints.add({
          'quantity': pt['quantity'],
          'price': pt['price'],
        });
      }

      if (!_isSingleQuantity &&
          !finalPricePoints.any(
            (pt) => pt['quantity'] == _maxPackagingQuantity,
          )) {
        final bool isFreeShipping =
            !_noFreeShipping &&
            (_maxPackagingQuantity * _supplyPrice >= _freeShippingThreshold);
        final double maxQtyPrice =
            _maxPackagingQuantity * _supplyPrice +
            (isFreeShipping ? 0.0 : _deliveryPrice);
        finalPricePoints.add({
          'quantity': _maxPackagingQuantity,
          'price': maxQtyPrice,
        });
      }

      final proposal = ProductEditRequestModel(
        id: '',
        productId: '',
        isNewProduct: true,
        sellerUid: widget.uid,
        requestedBy: widget.uid,
        marketLink: _marketLink,
        shippingMethod: _shippingMethod,
        address: _shippingMethod == '지역배송' ? _address : null,
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
        pricePoints: finalPricePoints,
        deliveryMinDays: _deliveryMinDays,
        deliveryMaxDays: _deliveryMaxDays,
        storageInfo: _storageInfo,
        instructions: _instructions,
        stock: _stock,
        imgUrl: _mainImageUrl ?? '',
        imgUrls: _additionalImageUrls.where((url) => url.isNotEmpty).toList(),
        requestedAt: FieldValue.serverTimestamp(),
        status: 'pending',
      );

      await FirebaseFirestore.instance
          .collection('product_edit_requests')
          .add(proposal.toMap());

      nav.pop(); // pop loading dialog

      showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            title: Text(
              tr('pe_proposal_success_title'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(tr('pe_proposal_success_desc')),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _proposalSubTabIndex = 0; // Redirect to 제안 목록
                  });
                },
                child: Text(tr('pe_confirm')),
              ),
            ],
          );
        },
      );

      // Reset form on success
      setState(() {
        _marketLink = '';
        _productName = '';
        _storageInfo = '';
        _instructions = '';
        _stock = 0;
        _mainImageUrl = null;
        _additionalImageUrls = ['', '', '', ''];
        _pricePoints = [
          {'quantity': 1, 'price': 14000.0},
          {'quantity': 2, 'price': 24000.0},
          {'quantity': 3, 'price': 34000.0},
          {'quantity': 4, 'price': 44000.0},
        ];
      });
    } catch (e) {
      try {
        nav.pop();
      } catch (_) {}
      sm.showSnackBar(
        SnackBar(
          content: Text(
            tr('pe_propose_fail').replaceAll('{error}', e.toString()),
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
    String? hintText,
    bool isOptional = false,
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
              key: initialValue.isEmpty ? null : ValueKey(initialValue),
              readOnly: readOnly,
              keyboardType:
                  isNumberOnly ? TextInputType.number : TextInputType.text,
              inputFormatters:
                  isNumberOnly
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : null,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: InputBorder.none,
                isDense: true,
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              onChanged: onChanged,
              onSaved: onSaved,
              validator: (val) {
                if (isOptional) return null;
                if (val == null || val.isEmpty) {
                  return tr('pe_required_field');
                }
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _proposalSubTabIndex = 0),
                  child: Container(
                    height: 45,
                    width: 90,

                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          _proposalSubTabIndex == 0
                              ? Colors.black
                              : Colors.white,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: Text(
                      tr('pe_tab_proposal_list'),
                      style: TextStyle(
                        color:
                            _proposalSubTabIndex == 0
                                ? Colors.white
                                : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _proposalSubTabIndex = 1),
                  child: Container(
                    height: 45,
                    width: 90,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          _proposalSubTabIndex == 1
                              ? Colors.black
                              : Colors.white,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: Text(
                      tr('pe_tab_proposal_form'),
                      style: TextStyle(
                        color:
                            _proposalSubTabIndex == 1
                                ? Colors.white
                                : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_proposalSubTabIndex == 0)
              ProposalListTab(uid: widget.uid)
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. 오픈마켓 판매링크(선택)
                      _buildSectionHeader(tr('pe_market_link')),
                      _buildBrutalistInput(
                        prefix: '',
                        initialValue: _marketLink,
                        hintText: 'https://smartstore.naver.com/...',
                        isOptional: true,
                        onSaved: (val) => _marketLink = val ?? '',
                      ),
                      const SizedBox(height: 20),

                      // 2. 배송방식
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
                                          _address = null;
                                          _originalAddress = null;
                                        }
                                      });
                                      if (mValue == '지역배송' && _address == null) {
                                        searchAddress();
                                      }
                                    },
                                    child: Container(
                                      height: 40,
                                      color:
                                          isSelected
                                              ? Colors.black
                                              : Colors.white,
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
                        _buildSectionHeader(tr('pe_delivery_region')),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_address == null)
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    tr('pe_no_regions_selected'),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              else ...[
                                Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _address!['address_name'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            _address = null;
                                            _originalAddress = null;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          activeColor: Colors.black,
                                          value: _removeEmdLimit,
                                          onChanged: (val) {
                                            setState(() {
                                              _removeEmdLimit = val ?? false;
                                              if (_removeEmdLimit && _originalAddress != null) {
                                                final name = _originalAddress!['address_name']?.toString() ?? '';
                                                final parts = name.split(' ');
                                                if (parts.length > 2) {
                                                  _address!['address_name'] = parts.take(2).join(' ');
                                                }
                                              } else if (!_removeEmdLimit && _originalAddress != null) {
                                                _address = Map<String, dynamic>.from(_originalAddress!);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        '읍/면/동 제한 해제 (시/군/구 단위 배송)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              Container(
                                width: double.infinity,
                                height: 1,
                                color: Colors.black,
                              ),
                              InkWell(
                                onTap: searchAddress,
                                child: Container(
                                  height: 40,
                                  color: Colors.black,
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _address == null ? Icons.add : Icons.edit,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _address == null
                                            ? tr('pe_add_region')
                                            : tr('pe_change_region'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 3. 카테고리 선택
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
                          ? Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              tr('pe_no_categories'),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                          : Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 1),
                            ),
                            child: Row(
                              children:
                                  _categories.map((cat) {
                                    final catValue = cat['name'] as String;
                                    final isSelected = _category == catValue;
                                    return Expanded(
                                      child: InkWell(
                                        onTap:
                                            () => setState(
                                              () => _category = catValue,
                                            ),
                                        child: Container(
                                          height: 40,
                                          color:
                                              isSelected
                                                  ? Colors.black
                                                  : Colors.white,
                                          alignment: Alignment.center,
                                          child: Text(
                                            catValue,
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

                      // 4. 상품명
                      _buildSectionHeader(tr('pe_product_name')),
                      _buildBrutalistInput(
                        prefix: '',
                        initialValue: _productName,
                        onSaved: (val) => _productName = val ?? '',
                      ),
                      const SizedBox(height: 20),

                      // 5. 과세 구분
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
                                    onTap:
                                        () => setState(() => _taxType = tValue),
                                    child: Container(
                                      height: 40,
                                      color:
                                          isSelected
                                              ? Colors.black
                                              : Colors.white,
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

                      // 6. 상품가격(배송비 미포함)
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
                            (val) =>
                                _supplyPrice =
                                    double.tryParse(val ?? '') ?? 0.0,
                      ),
                      const SizedBox(height: 20),

                      // 7. 배송비 / 도서지역 추가 배송비 / 반품 배송비
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _buildSectionHeader(tr('pe_delivery_fee')),
                                _buildBrutalistInput(
                                  prefix: '₩',
                                  initialValue:
                                      _deliveryPrice.toInt().toString(),
                                  isNumberOnly: true,
                                  onChanged: (val) {
                                    setState(() {
                                      _deliveryPrice =
                                          double.tryParse(val) ?? 0.0;
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
                                _buildSectionHeader(
                                  tr('pe_return_delivery_fee'),
                                ),
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

                      // 8. ~이상 구매 시 무료배송
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
                                          _freeShippingThreshold
                                              .toInt()
                                              .toString(),
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
                                                  double.tryParse(val ?? '') ??
                                                  0.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.black,
                            ),
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
                                      _noFreeShipping
                                          ? Colors.black
                                          : Colors.white,
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

                      // 9. 1상자 최대 포장수량
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
                                      _pricePoints.removeAt(
                                        _pricePoints.length - 2,
                                      );
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
                                    return tr('pe_val_one_or_more');
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
                                    _pricePoints.removeAt(
                                      _pricePoints.length - 2,
                                    );
                                  }
                                  if (parsed <= 1) {
                                    _pricePoints.removeWhere(
                                      (pt) => pt['isMax'] != true,
                                    );
                                  }
                                },
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.black,
                            ),
                            Expanded(
                              flex: 1,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _isSingleQuantity = !_isSingleQuantity;
                                    if (_isSingleQuantity) {
                                      // remove everything else and make it quantity 1
                                      _pricePoints = [
                                        {
                                          'quantity': 1,
                                          'price': 10000.0,
                                          'isMax': true,
                                        },
                                      ];
                                    } else {
                                      // make it the max quantity again
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
                                      _isSingleQuantity
                                          ? Colors.black
                                          : Colors.white,
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

                      // 10. 수량 가격 옵션
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Table(
                            columnWidths: const {
                              0: FlexColumnWidth(1),
                              1: FlexColumnWidth(2),
                            },
                            border: TableBorder.all(
                              color: Colors.black,
                              width: 1,
                            ),
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
                                final int qty = pt['quantity'] as int? ?? 1;
                                final bool isMaxRow =
                                    pt['isMax'] == true || _isSingleQuantity;
                                final bool isFreeShipping =
                                    !_noFreeShipping &&
                                    (qty * _supplyPrice >=
                                        _freeShippingThreshold);
                                final double calculatedPrice =
                                    qty * _supplyPrice +
                                    (isFreeShipping ? 0.0 : _deliveryPrice);

                                _pricePoints[index]['price'] = calculatedPrice;

                                return TableRow(
                                  children: [
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: TextFormField(
                                        initialValue: pt['quantity'].toString(),
                                        key: ValueKey(
                                          'qty_${pt['isMax']}_$qty',
                                        ),
                                        textAlign: TextAlign.center,
                                        readOnly: isMaxRow,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
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
                                            if (parsed >=
                                                _maxPackagingQuantity) {
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
                                          final parsedQty =
                                              int.tryParse(val) ?? 1;
                                          setState(() {
                                            _pricePoints[index]['quantity'] =
                                                parsedQty;
                                          });
                                        },
                                        validator: (val) {
                                          if (isMaxRow) return null;
                                          final parsedQty =
                                              int.tryParse(val ?? '') ?? 0;
                                          if (parsedQty <= 0)
                                            return tr('pe_val_one_or_more');
                                          if (!_isSingleQuantity) {
                                            if (parsedQty >=
                                                _maxPackagingQuantity) {
                                              return tr(
                                                'pe_val_max',
                                              ).replaceAll(
                                                '{max}',
                                                (_maxPackagingQuantity - 1)
                                                    .toString(),
                                              );
                                            }
                                          }
                                          for (
                                            int i = 0;
                                            i < _pricePoints.length;
                                            i++
                                          ) {
                                            if (i != index &&
                                                _pricePoints[i]['quantity'] ==
                                                    parsedQty) {
                                              return tr(
                                                'pe_duplicate_qty_error',
                                              );
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
                                              calculatedPrice
                                                  .toInt()
                                                  .toString(),
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
                                                    : () => _removePricePoint(
                                                      index,
                                                    ),
                                            child: Text(
                                              isMaxRow
                                                  ? tr('pe_cannot_delete')
                                                  : tr('pe_delete_label'),
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
                                        _pricePoints.length >=
                                            _maxPackagingQuantity)
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

                      // 11. 배송일
                      _buildSectionHeader(tr('pe_delivery_days')),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Text(
                              tr('pe_enter_number_hint'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(
                              width: 50,
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
                                ),
                                onSaved:
                                    (val) =>
                                        _deliveryMinDays =
                                            int.tryParse(val ?? '') ?? 1,
                              ),
                            ),
                            const Text(
                              ' ~ ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              tr('pe_enter_number_hint'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(
                              width: 50,
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
                                ),
                                onSaved:
                                    (val) =>
                                        _deliveryMaxDays =
                                            int.tryParse(val ?? '') ?? 3,
                              ),
                            ),
                            Text(
                              tr('pe_days'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 12. 보관법 및 소비기한
                      _buildSectionHeader(tr('pe_storage_info')),
                      _buildBrutalistInput(
                        prefix: '',
                        initialValue: _storageInfo,
                        onSaved: (val) => _storageInfo = val ?? '',
                      ),
                      const SizedBox(height: 20),

                      // 13. 제품 안내
                      _buildSectionHeader(tr('pe_product_guide')),
                      _buildBrutalistInput(
                        prefix: '',
                        initialValue: _instructions,
                        onSaved: (val) => _instructions = val ?? '',
                      ),
                      const SizedBox(height: 20),

                      // 14. 이미지 업로드 슬롯
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

                      // 15. 재고
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

                      // Submit proposal button
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
                              onPressed: _submitProposal,
                              child: Text(
                                tr('pe_propose_button'),
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
          ],
        ),
      ),
    );
  }


}
