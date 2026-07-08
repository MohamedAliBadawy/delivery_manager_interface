import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_manager_interface/core/localization.dart';
import 'package:delivery_manager_interface/widgets/product_edit_form.dart';
import 'package:delivery_manager_interface/models/product_model.dart';

class QuickStockManagementWidget extends StatefulWidget {
  final String uid;

  const QuickStockManagementWidget({super.key, required this.uid});

  @override
  State<QuickStockManagementWidget> createState() => _QuickStockManagementWidgetState();
}

class _QuickStockManagementWidgetState extends State<QuickStockManagementWidget> {
  Product? _selectedProduct;

  void _editStock(Product product) {
    final formKey = GlobalKey<FormState>();
    int newStock = product.stock;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            tr('product_edit'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: TextFormField(
                initialValue: newStock.toString(),
                decoration: InputDecoration(
                  labelText: tr('stock_label'),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: Colors.black),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return tr('stock_required');
                  }
                  if (int.tryParse(value) == null) {
                    return '숫자만 입력 가능합니다.';
                  }
                  return null;
                },
                onSaved: (value) {
                  newStock = int.parse(value!);
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: Text(tr('cancel')),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: Text(tr('save')),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                formKey.currentState!.save();

                try {
                  // Show updating dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      content: Row(
                        children: [
                          const CircularProgressIndicator(color: Colors.black),
                          const SizedBox(width: 16),
                          Text(tr('updating_stock')),
                        ],
                      ),
                    ),
                  );

                  final productRef = FirebaseFirestore.instance
                      .collection('products')
                      .doc(product.product_id);

                  await productRef.update({'stock': newStock});

                  if (!context.mounted) return;
                  Navigator.of(context).pop(); // pop loading
                  Navigator.of(context).pop(); // pop edit dialog

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tr('stock_update_success')),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  Navigator.of(context).pop(); // pop loading if visible
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${tr('stock_update_fail')}: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '빠른 재고 관리',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('deliveryManagerId', isEqualTo: widget.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Text(tr('pm_no_products'));
                }

                final products = snapshot.data!.docs
                    .map((doc) => Product.fromMap(doc.data() as Map<String, dynamic>))
                    .toList();

                // Sync the selected product data if it changes in firestore stream
                if (_selectedProduct != null) {
                  Product? foundData;
                  for (final product in products) {
                    if (product.product_id == _selectedProduct!.product_id) {
                      foundData = product;
                      break;
                    }
                  }
                  if (foundData != null) {
                    _selectedProduct = foundData;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      children: [
                        // Column 1: Product Name Header
                        Container(
                          width: 240,
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black, width: 1),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '상품명',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        // Column 2: Stock Header
                        Container(
                          width: 120,
                          height: 40,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.black, width: 1),
                              bottom: BorderSide(color: Colors.black, width: 1),
                              right: BorderSide(color: Colors.black, width: 1),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '재고',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        // Column 3 has NO header cell above the edit button
                        const SizedBox(width: 140, height: 40),
                      ],
                    ),
                    // Data Rows
                    ...products.map((product) {
                      final String productId = product.product_id;
                      final String productName = product.productName;
                      final int stock = product.stock;
                      final isSelected = _selectedProduct != null &&
                          _selectedProduct!.product_id == productId;

                      return Row(
                        children: [
                          // Column 1: Product Name Cell
                          Container(
                            width: 240,
                            height: 48,
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(color: Colors.black, width: 1),
                                right: BorderSide(color: Colors.black, width: 1),
                                bottom: BorderSide(color: Colors.black, width: 1),
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedProduct = product;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.black : Colors.transparent,
                                  border: isSelected
                                      ? Border.all(color: Colors.black, width: 2) // highlighted in black
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  productName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Column 2: Stock Cell
                          Container(
                            width: 120,
                            height: 48,
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.black, width: 1),
                                bottom: BorderSide(color: Colors.black, width: 1),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              stock.toString(),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          // Column 3: Change Button Cell
                          Container(
                            width: 140,
                            height: 48,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 8.0),
                            child: ElevatedButton(
                              onPressed: () => _editStock(product),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                                fixedSize: const Size(132, 48),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text(
                                '변경',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                );
              },
            ),
            if (_selectedProduct != null) ...[
              const SizedBox(height: 24),
              ProductEditFormWidget(
                product: _selectedProduct!,
                onCancel: () {
                  setState(() {
                    _selectedProduct = null;
                  });
                },
                onSuccess: () {
                  setState(() {
                    _selectedProduct = null;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
