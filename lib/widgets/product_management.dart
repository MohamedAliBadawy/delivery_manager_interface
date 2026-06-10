import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:delivery_manager_interface/core/localization.dart';

class ProductManagementWidget extends StatefulWidget {
  final String uid;

  const ProductManagementWidget({super.key, required this.uid});

  @override
  State<ProductManagementWidget> createState() => _ProductManagementWidgetState();
}

class _ProductManagementWidgetState extends State<ProductManagementWidget> {
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();
  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    itemPositionsListener.itemPositions.addListener(() {
      final positions = itemPositionsListener.itemPositions.value;
      if (positions.isNotEmpty) {
        _currentIndexNotifier.value = positions.first.index;
      }
    });
  }

  @override
  void dispose() {
    _currentIndexNotifier.dispose();
    super.dispose();
  }

  void _scrollTo(int index) {
    itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _editCutoffTime(Map<String, dynamic> product) {
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        String meridiem = product['meridiem'] ?? 'AM';
        int baselineTime = product['baselineTime'] ?? 9;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(tr('product_edit')),
              content: SizedBox(
                width: 600,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: baselineTime.toString(),
                                      decoration: InputDecoration(
                                        labelText: tr('pm_cutoff_time'),
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return tr('cutoff_required');
                                        }
                                        return null;
                                      },
                                      onSaved: (value) {
                                        baselineTime = int.parse(value!);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  DropdownButton<String>(
                                    value: meridiem,
                                    items:
                                        ['AM', 'PM'].map((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          );
                                        }).toList(),
                                    onChanged: (String? newValue) {
                                      setDialogState(() {
                                        meridiem = newValue!;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: Text(tr('cancel')),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: Text(tr('save')),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    formKey.currentState!.save();
                    try {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder:
                            (context) => AlertDialog(
                              content: Row(
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(width: 16),
                                  Text(tr('updating_cutoff')),
                                ],
                              ),
                            ),
                      );

                      final productRef = FirebaseFirestore.instance
                          .collection('products')
                          .doc(product['product_id']);

                      final doc = await productRef.get();
                      if (!doc.exists) {
                        throw Exception('Product document not found');
                      }

                      await FirebaseFirestore.instance
                          .collection('products')
                          .doc(product['product_id'])
                          .update({
                            'meridiem': meridiem,
                            'baselineTime': baselineTime,
                          });

                      if (!context.mounted) return;
                      Navigator.of(context).pop(); // pop loading
                      Navigator.of(context).pop(); // pop dialog

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(tr('time_update_success')),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${tr('time_update_fail')}: ${e.toString()}'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editStock(Map<String, dynamic> product) {
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        int stock = product['stock'];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(tr('product_edit')),
              content: SizedBox(
                width: 600,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: stock.toString(),
                                decoration: InputDecoration(labelText: tr('stock_label')),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return tr('stock_required');
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  stock = int.parse(value!);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: Text(tr('cancel')),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: Text(tr('save')),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    formKey.currentState!.save();

                    try {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder:
                            (context) => AlertDialog(
                              content: Row(
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(width: 16),
                                  Text(tr('updating_stock')),
                                ],
                              ),
                            ),
                      );

                      final productRef = FirebaseFirestore.instance
                          .collection('products')
                          .doc(product['product_id']);

                      await productRef.update({'stock': stock});

                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(tr('stock_update_success')),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${tr('stock_update_fail')}: ${e.toString()}'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('deliveryManagerId', isEqualTo: widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(tr('pm_no_products')),
          );
        }

        final products = snapshot.data!.docs;
        return SizedBox(
          height: 300,
          child: Stack(
            children: [
              ScrollablePositionedList.builder(
                itemScrollController: itemScrollController,
                itemPositionsListener: itemPositionsListener,
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Row(
                    children: [
                      Container(
                        width: 300,
                        margin: const EdgeInsets.only(right: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                tr('pm_contract_info'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Table(
                                border: TableBorder.all(
                                  width: 2,
                                  color: Colors.black,
                                ),
                                children: [
                                  TableRow(
                                    children: [
                                      Center(child: Text(tr('pm_product_name'))),
                                      Center(
                                        child: Text(
                                          product['productName'] ?? 'N/A',
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Center(child: Text(tr('pm_supply_price'))),
                                      Center(
                                        child: Text(
                                          '₩${product['price']?.toString() ?? 'N/A'}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Center(child: Text(tr('pm_shipping_fee'))),
                                      Center(
                                        child: Text(
                                          '₩ ${product['deliveryPrice']?.toString() ?? 'N/A'}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Center(child: Text(tr('pm_remote_shipping'))),
                                      Center(
                                        child: Text(
                                          '₩ ${product['shippingFee']?.toString() ?? 'N/A'}',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 300,
                        margin: const EdgeInsets.only(right: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                tr('pm_cutoff_inventory'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Table(
                                border: TableBorder.all(
                                  width: 2,
                                  color: Colors.black,
                                ),
                                children: [
                                  TableRow(
                                    children: [
                                      Center(child: Text(tr('pm_cutoff_time'))),
                                      Center(
                                        child: Text(
                                          '${product['baselineTime']?.toString() ?? 'N/A'} ${product['meridiem'] ?? 'N/A'}',
                                        ),
                                      ),
                                      Center(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            _editCutoffTime(product.data());
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.black,
                                            foregroundColor: Colors.white,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.zero,
                                            ),
                                            fixedSize: Size.fromWidth(110),
                                          ),
                                          child: Text(
                                            tr('pm_change'),
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Center(child: Text(tr('pm_current_stock'))),
                                      Center(
                                        child: Text(
                                          product['stock']?.toString() ?? 'N/A',
                                        ),
                                      ),
                                      Center(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            _editStock(product.data());
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.black,
                                            foregroundColor: Colors.white,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.zero,
                                            ),
                                            fixedSize: Size.fromWidth(110),
                                          ),
                                          child: Text(
                                            tr('pm_change'),
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (products.length > 1) ...[
                ValueListenableBuilder<int>(
                  valueListenable: _currentIndexNotifier,
                  builder: (context, currentIndex, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 48,
                          alignment: Alignment.centerLeft,
                          child:
                              currentIndex > 0
                                  ? IconButton(
                                    icon: const Icon(Icons.arrow_back_ios),
                                    onPressed:
                                        () => _scrollTo(currentIndex - 1),
                                  )
                                  : const SizedBox(),
                        ),
                        Container(
                          width: 48,
                          alignment: Alignment.centerRight,
                          child:
                              currentIndex < products.length - 1
                                  ? IconButton(
                                    icon: const Icon(Icons.arrow_forward_ios),
                                    onPressed:
                                        () => _scrollTo(currentIndex + 1),
                                  )
                                  : const SizedBox(),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
