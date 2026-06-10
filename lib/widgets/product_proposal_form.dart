import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_manager_interface/core/localization.dart';

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
  int _maxPackagingQuantity = 50;
  bool _isSingleQuantity = false;

  // Dynamic list of price options (Custom quantities)
  List<Map<String, dynamic>> _pricePoints = [
    {'quantity': 1, 'price': 14000.0},
    {'quantity': 2, 'price': 24000.0},
    {'quantity': 3, 'price': 34000.0},
    {'quantity': 50, 'price': 54000.0, 'isMax': true},
  ];

  int _deliveryMinDays = 1;
  int _deliveryMaxDays = 3;
  String _storageInfo = '';
  String _instructions = '';
  int _stock = 0;

  // Image slots
  String? _mainImageUrl;
  List<String> _additionalImageUrls = ['', '', '', ''];

  void _addPricePoint() {
    if (_pricePoints.length >= 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('pe_option_limit_error'))));
      return;
    }
    if (_isSingleQuantity) return; // cannot add options in single quantity mode
    int defaultQty = 1;
    final maxAllowedQty = _maxPackagingQuantity - 1;
    while (_pricePoints.any((pt) => pt['quantity'] == defaultQty) ||
        defaultQty >= _maxPackagingQuantity) {
      defaultQty++;
    }
    if (defaultQty > maxAllowedQty) {
      int foundSlot = -1;
      for (int q = 1; q <= maxAllowedQty; q++) {
        if (!_pricePoints.any((pt) => pt['quantity'] == q)) {
          foundSlot = q;
          break;
        }
      }
      if (foundSlot != -1) {
        defaultQty = foundSlot;
      } else {
        return;
      }
    }
    setState(() {
      // Insert before the last item (which is the max packaging quantity row)
      _pricePoints.insert(_pricePoints.length - 1, {'quantity': defaultQty, 'price': 10000.0});
    });
  }

  void _removePricePoint(int index) {
    if (_pricePoints[index]['isMax'] == true || _pricePoints.length <= 1) return;
    setState(() {
      _pricePoints.removeAt(index);
    });
  }

  void _showImageUrlDialog(int slotIndex, bool isMain) {
    final controller = TextEditingController(
      text: isMain ? _mainImageUrl : _additionalImageUrls[slotIndex],
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            isMain
                ? tr('pe_enter_main_image_url')
                : tr(
                  'pe_enter_add_image_url',
                ).replaceAll('{index}', '${slotIndex + 1}'),
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'https://example.com/image.png',
              border: OutlineInputBorder(borderRadius: BorderRadius.zero),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                tr('cancel'),
                style: const TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onPressed: () {
                setState(() {
                  if (isMain) {
                    _mainImageUrl = controller.text.trim();
                  } else {
                    _additionalImageUrls[slotIndex] = controller.text.trim();
                  }
                });
                Navigator.pop(context);
              },
              child: Text(tr('pe_taxable') == '과세' ? '적용' : 'Apply'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitProposal() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

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

      final proposalData = {
        'product_id': '', // empty for a brand new product
        'isNewProduct': true,
        'sellerUid': widget.uid,
        'requested_by': widget.uid,
        'marketLink': _marketLink,
        'shippingMethod': _shippingMethod,
        'category': _category,
        'productName': _productName,
        'taxType': _taxType,
        'supplyPrice': _supplyPrice,
        'deliveryPrice': _deliveryPrice,
        'shippingFee': _shippingFee,
        'returnDeliveryPrice': _returnDeliveryPrice,
        'freeShippingThreshold': _freeShippingThreshold,
        'noFreeShipping': _noFreeShipping,
        'maxPackagingQuantity': _maxPackagingQuantity,
        'isSingleQuantity': _isSingleQuantity,
        'pricePoints': finalPricePoints,
        'deliveryMinDays': _deliveryMinDays,
        'deliveryMaxDays': _deliveryMaxDays,
        'storageInfo': _storageInfo,
        'instructions': _instructions,
        'stock': _stock,
        'imgUrl': _mainImageUrl ?? '',
        'imgUrls': _additionalImageUrls.where((url) => url.isNotEmpty).toList(),
        'requested_at': FieldValue.serverTimestamp(),
        'status': 'pending',
      };

      await FirebaseFirestore.instance
          .collection('product_edit_requests')
          .add(proposalData);

      nav.pop(); // pop loading dialog

      sm.showSnackBar(SnackBar(content: Text(tr('pe_propose_success'))));

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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: Colors.black, thickness: 1),
            const SizedBox(height: 16),

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
                          onTap: () => setState(() => _shippingMethod = mValue),
                          child: Container(
                            height: 40,
                            color: isSelected ? Colors.black : Colors.white,
                            alignment: Alignment.center,
                            child: Text(
                              mDisplay,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
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

            // 3. 카테고리 선택
            _buildSectionHeader(tr('pe_category_select')),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: Row(
                children:
                    [
                      MapEntry('식품', tr('pe_food')),
                      MapEntry('생활', tr('pe_life')),
                      MapEntry('기타', tr('pe_other')),
                    ].map((entry) {
                      final catValue = entry.key;
                      final catDisplay = entry.value;
                      final isSelected = _category == catValue;
                      return Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _category = catValue),
                          child: Container(
                            height: 40,
                            color: isSelected ? Colors.black : Colors.white,
                            alignment: Alignment.center,
                            child: Text(
                              catDisplay,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
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
                          onTap: () => setState(() => _taxType = tValue),
                          child: Container(
                            height: 40,
                            color: isSelected ? Colors.black : Colors.white,
                            alignment: Alignment.center,
                            child: Text(
                              tDisplay,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
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
                  (val) => _supplyPrice = double.tryParse(val ?? '') ?? 0.0,
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
                        initialValue: _returnDeliveryPrice.toInt().toString(),
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
                        color: _noFreeShipping ? Colors.black : Colors.white,
                        alignment: Alignment.center,
                        child: Text(
                          tr('pe_no_free_shipping'),
                          style: TextStyle(
                            color:
                                _noFreeShipping ? Colors.white : Colors.black,
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                        final parsed = int.tryParse(val) ?? 50;
                        setState(() {
                          _maxPackagingQuantity = parsed;
                          for (var pt in _pricePoints) {
                            if (pt['isMax'] == true) {
                              pt['quantity'] = parsed;
                            }
                          }
                        });
                      },
                      onSaved: (val) {
                        final parsed = int.tryParse(val ?? '') ?? 50;
                        _maxPackagingQuantity = parsed;
                        for (var pt in _pricePoints) {
                          if (pt['isMax'] == true) {
                            pt['quantity'] = parsed;
                          }
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
                            // remove everything else and make it quantity 1
                            _pricePoints = [
                              {'quantity': 1, 'price': 10000.0, 'isMax': true}
                            ];
                          } else {
                            // make it the max quantity again
                            _pricePoints = [
                              {'quantity': _maxPackagingQuantity, 'price': 10000.0, 'isMax': true}
                            ];
                          }
                        });
                      },
                      child: Container(
                        height: 40,
                        color: _isSingleQuantity ? Colors.black : Colors.white,
                        alignment: Alignment.center,
                        child: Text(
                          tr('pe_single_qty'),
                          style: TextStyle(
                            color:
                                _isSingleQuantity ? Colors.white : Colors.black,
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
                      final int qty = pt['quantity'] as int? ?? 1;
                      final bool isMaxRow = pt['isMax'] == true || _isSingleQuantity;
                      final bool isFreeShipping =
                          !_noFreeShipping &&
                          (qty * _supplyPrice >= _freeShippingThreshold);
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
                              key: ValueKey('qty_${pt['isMax']}_$qty'),
                              textAlign: TextAlign.center,
                              readOnly: isMaxRow,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
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
                                  _pricePoints[index]['quantity'] = parsedQty;
                                });
                              },
                              validator: (val) {
                                final parsedQty = int.tryParse(val ?? '') ?? 0;
                                if (parsedQty <= 0) return '1 이상';
                                if (!_isSingleQuantity) {
                                  if (parsedQty >= _maxPackagingQuantity) {
                                    return '최대 ${_maxPackagingQuantity - 1}';
                                  }
                                }
                                for (int i = 0; i < _pricePoints.length; i++) {
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
                                  onPressed: isMaxRow
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
                                      color: isMaxRow
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
                  onPressed: _addPricePoint,
                  icon: const Icon(Icons.add, size: 16, color: Colors.black),
                  label: Text(
                    tr('pe_add_price_option'),
                    style: const TextStyle(
                      color: Colors.black,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text(
                    tr('pe_enter_number_hint'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  SizedBox(
                    width: 50,
                    child: TextFormField(
                      initialValue: _deliveryMinDays.toString(),
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                      ),
                      onSaved:
                          (val) =>
                              _deliveryMinDays = int.tryParse(val ?? '') ?? 1,
                    ),
                  ),
                  const Text(
                    ' ~ ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    tr('pe_enter_number_hint'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  SizedBox(
                    width: 50,
                    child: TextFormField(
                      initialValue: _deliveryMaxDays.toString(),
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                      ),
                      onSaved:
                          (val) =>
                              _deliveryMaxDays = int.tryParse(val ?? '') ?? 3,
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

                    return InkWell(
                      onTap:
                          () => _showImageUrlDialog(
                            isMain ? 0 : index - 1,
                            isMain,
                          ),
                      child: Container(
                        height: 80,
                        alignment: Alignment.center,
                        child:
                            hasImage
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
