import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:delivery_manager_interface/core/localization.dart';
import 'package:delivery_manager_interface/models/order_model.dart';
import 'package:delivery_manager_interface/models/product_model.dart';
import 'package:delivery_manager_interface/models/user_model.dart';
import 'package:delivery_manager_interface/loading_dialog.dart';
import 'package:delivery_manager_interface/login_screen.dart';
import 'package:delivery_manager_interface/widgets/manager_info.dart';
import 'package:delivery_manager_interface/widgets/customer_inquiries.dart';
import 'package:delivery_manager_interface/widgets/quick_stock_management.dart';
import 'package:delivery_manager_interface/widgets/product_proposal_form.dart';

enum OrderTableColumn {
  checkbox,
  orderDate,
  orderId,
  productName,
  quantity,
  recipientName,
  phone,
  address,
  deliveryRequest,
  carrier,
  trackingNumber,
  submitAction,
  settlementDate,
  productPrice,
  deliveryFee,
  islandDeliveryFee,
  settlementAmount,
  exchangeReason,
  exchangeStatus,
}

class OrdersManagementWidget extends StatefulWidget {
  final List<MyOrder> orders;
  final String uid;
  final Stream<int> chatCountsStream;

  const OrdersManagementWidget({
    super.key,
    required this.orders,
    required this.uid,
    required this.chatCountsStream,
  });

  @override
  State<OrdersManagementWidget> createState() => _OrdersManagementWidgetState();
}

class _OrdersManagementWidgetState extends State<OrdersManagementWidget> {
  late final ScrollController _headerScrollController;
  late final ScrollController _bodyScrollController;
  late final ScrollController _buttonsScrollController;
  final Map<String, TextEditingController> trackingControllers = {};
  final Map<String, TextEditingController> courierControllers = {};
  int _currentTabIndex = 0;

  final Set<String> _selectedOrderIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _selectedProductFilter = 'All';
  String _selectedDateFilter = 'All';
  final List<String> _productFilterOptions = ['All'];
  final List<String> _dateFilterOptions = ['All'];
  final Map<String, Product?> _productCache = {};
  final Map<String, MyUser?> _userCache = {};
  final Map<String, GlobalKey<FormState>> formKeys = {};

  final Map<String, Map<String, dynamic>> _exchangesCache = {};
  final Map<String, Map<String, dynamic>> _refundsCache = {};
  StreamSubscription? _exchangesSubscription;
  StreamSubscription? _refundsSubscription;

  bool _hasPendingExchangeOrRefund(String orderId) {
    if (_exchangesCache.containsKey(orderId)) {
      final status = _exchangesCache[orderId]?['status'];
      if (status == '대기중' || status == null) return true;
    }
    if (_refundsCache.containsKey(orderId)) {
      final status = _refundsCache[orderId]?['status'];
      if (status == '대기중' || status == null) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _exchangesSubscription = FirebaseFirestore.instance
        .collection('exchanges')
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _exchangesCache.clear();
              for (final doc in snapshot.docs) {
                final data = doc.data();
                final orderId = data['orderId'] as String?;
                if (orderId != null) {
                  _exchangesCache[orderId] = data;
                }
              }
            });
          }
        });

    _refundsSubscription = FirebaseFirestore.instance
        .collection('refunds')
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _refundsCache.clear();
              for (final doc in snapshot.docs) {
                final data = doc.data();
                final orderId = data['orderId'] as String?;
                if (orderId != null) {
                  _refundsCache[orderId] = data;
                }
              }
            });
          }
        });

    _headerScrollController = ScrollController();
    _bodyScrollController = ScrollController();
    _buttonsScrollController = ScrollController();
    _headerScrollController.addListener(() {
      if (_bodyScrollController.hasClients &&
          _bodyScrollController.offset != _headerScrollController.offset) {
        _bodyScrollController.jumpTo(_headerScrollController.offset);
      }
      if (_buttonsScrollController.hasClients &&
          _buttonsScrollController.offset != _headerScrollController.offset) {
        _buttonsScrollController.jumpTo(_headerScrollController.offset);
      }
    });
    _bodyScrollController.addListener(() {
      if (_headerScrollController.hasClients &&
          _headerScrollController.offset != _bodyScrollController.offset) {
        _headerScrollController.jumpTo(_bodyScrollController.offset);
      }
      if (_buttonsScrollController.hasClients &&
          _buttonsScrollController.offset != _bodyScrollController.offset) {
        _buttonsScrollController.jumpTo(_bodyScrollController.offset);
      }
    });
    _buttonsScrollController.addListener(() {
      if (_headerScrollController.hasClients &&
          _headerScrollController.offset != _buttonsScrollController.offset) {
        _headerScrollController.jumpTo(_buttonsScrollController.offset);
      }
      if (_bodyScrollController.hasClients &&
          _bodyScrollController.offset != _buttonsScrollController.offset) {
        _bodyScrollController.jumpTo(_buttonsScrollController.offset);
      }
    });
  }

  @override
  void dispose() {
    _exchangesSubscription?.cancel();
    _refundsSubscription?.cancel();
    _headerScrollController.dispose();
    _bodyScrollController.dispose();
    _buttonsScrollController.dispose();
    _searchController.dispose();
    for (var c in trackingControllers.values) {
      c.dispose();
    }
    for (var c in courierControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // --- DYNAMIC COLUMNS SYSTEM ---
  List<OrderTableColumn> _getColumnsForTab(int tabIndex) {
    switch (tabIndex) {
      case 0: // 신규 주문
        return [
          OrderTableColumn.checkbox,
          OrderTableColumn.orderDate,
          OrderTableColumn.orderId,
          OrderTableColumn.productName,
          OrderTableColumn.quantity,
          OrderTableColumn.recipientName,
          OrderTableColumn.phone,
          OrderTableColumn.address,
          OrderTableColumn.deliveryRequest,
        ];
      case 1: // 준비중
        return [
          OrderTableColumn.checkbox,
          OrderTableColumn.orderDate,
          OrderTableColumn.orderId,
          OrderTableColumn.productName,
          OrderTableColumn.quantity,
          OrderTableColumn.recipientName,
          OrderTableColumn.phone,
          OrderTableColumn.address,
          OrderTableColumn.deliveryRequest,
          OrderTableColumn.carrier,
          OrderTableColumn.trackingNumber,
          OrderTableColumn.submitAction,
        ];
      case 2: // 배송중
        return [
          OrderTableColumn.checkbox,
          OrderTableColumn.orderDate,
          OrderTableColumn.orderId,
          OrderTableColumn.productName,
          OrderTableColumn.quantity,
          OrderTableColumn.recipientName,
          OrderTableColumn.phone,
          OrderTableColumn.address,
          OrderTableColumn.deliveryRequest,
          OrderTableColumn.carrier,
          OrderTableColumn.trackingNumber,
          OrderTableColumn.submitAction,
        ];
      case 3: // 배송완료 및 정산
        return [
          OrderTableColumn.orderDate,
          OrderTableColumn.orderId,
          OrderTableColumn.productName,
          OrderTableColumn.quantity,
          OrderTableColumn.recipientName,
          OrderTableColumn.phone,
          OrderTableColumn.address,
          OrderTableColumn.deliveryRequest,
          OrderTableColumn.carrier,
          OrderTableColumn.trackingNumber,
          OrderTableColumn.settlementDate,
          OrderTableColumn.productPrice,
          OrderTableColumn.deliveryFee,
          OrderTableColumn.islandDeliveryFee,
          OrderTableColumn.settlementAmount,
        ];
      case 4: // 교환·반품 요청
        return [
          OrderTableColumn.checkbox,
          OrderTableColumn.orderDate,
          OrderTableColumn.orderId,
          OrderTableColumn.productName,
          OrderTableColumn.quantity,
          OrderTableColumn.recipientName,
          OrderTableColumn.phone,
          OrderTableColumn.address,
          OrderTableColumn.deliveryRequest,
          OrderTableColumn.carrier,
          OrderTableColumn.trackingNumber,
          OrderTableColumn.exchangeReason,
          OrderTableColumn.exchangeStatus,
        ];
      case 6: // 선물대기
        return [
          OrderTableColumn.checkbox,
          OrderTableColumn.orderDate,
          OrderTableColumn.orderId,
          OrderTableColumn.productName,
          OrderTableColumn.quantity,
          OrderTableColumn.recipientName,
          OrderTableColumn.phone,
          OrderTableColumn.address,
          OrderTableColumn.deliveryRequest,
        ];
      default:
        return [];
    }
  }

  String _formatCurrency(double? value) {
    if (value == null) return '-';
    final int val = value.round();
    final String str = val.toString();
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  double _getColumnWidth(OrderTableColumn col) {
    switch (col) {
      case OrderTableColumn.checkbox:
        return 110;
      case OrderTableColumn.orderDate:
        return 140;
      case OrderTableColumn.orderId:
        return 150;
      case OrderTableColumn.productName:
        return 180;
      case OrderTableColumn.quantity:
        return 70;
      case OrderTableColumn.recipientName:
        return 100;
      case OrderTableColumn.phone:
        return 140;
      case OrderTableColumn.address:
        return 320;
      case OrderTableColumn.deliveryRequest:
        return 180;
      case OrderTableColumn.carrier:
        return 140;
      case OrderTableColumn.trackingNumber:
        return 180;
      case OrderTableColumn.submitAction:
        return 100;
      case OrderTableColumn.settlementDate:
        return 140;
      case OrderTableColumn.productPrice:
        return 120;
      case OrderTableColumn.deliveryFee:
        return 100;
      case OrderTableColumn.islandDeliveryFee:
        return 150;
      case OrderTableColumn.settlementAmount:
        return 120;
      case OrderTableColumn.exchangeReason:
        return 180;
      case OrderTableColumn.exchangeStatus:
        return 120;
    }
  }

  String _getColumnTitle(OrderTableColumn col) {
    switch (col) {
      case OrderTableColumn.checkbox:
        return tr('col_select_all');
      case OrderTableColumn.orderDate:
        return tr('col_date');
      case OrderTableColumn.orderId:
        return tr('col_id');
      case OrderTableColumn.productName:
        return tr('col_product');
      case OrderTableColumn.quantity:
        return tr('col_qty');
      case OrderTableColumn.recipientName:
        return tr('col_recipient');
      case OrderTableColumn.phone:
        return tr('col_phone');
      case OrderTableColumn.address:
        return tr('col_address');
      case OrderTableColumn.deliveryRequest:
        return tr('col_instructions');
      case OrderTableColumn.carrier:
        return tr('col_courier');
      case OrderTableColumn.trackingNumber:
        return tr('col_tracking');
      case OrderTableColumn.submitAction:
        return tr('col_action');
      case OrderTableColumn.settlementDate:
        return tr('col_settlement_date');
      case OrderTableColumn.productPrice:
        return tr('col_product_price');
      case OrderTableColumn.deliveryFee:
        return tr('col_delivery_fee');
      case OrderTableColumn.islandDeliveryFee:
        return tr('col_island_fee');
      case OrderTableColumn.settlementAmount:
        return tr('col_settlement_amount');
      case OrderTableColumn.exchangeReason:
        return tr('col_exchange_reason');
      case OrderTableColumn.exchangeStatus:
        return tr('col_exchange_status');
    }
  }

  // --- PRELOAD AND CACHE LOGIC ---
  Future<void> _preloadOrderData(List<MyOrder> orders) async {
    bool updated = false;
    for (final order in orders) {
      if (!_productCache.containsKey(order.productId)) {
        final doc =
            await FirebaseFirestore.instance
                .collection('products')
                .doc(order.productId)
                .get();
        if (doc.exists) {
          _productCache[order.productId] = Product.fromMap(
            doc.data() as Map<String, dynamic>,
          );
        } else {
          _productCache[order.productId] = null;
        }
        updated = true;
      }
      if (!_userCache.containsKey(order.userId)) {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(order.userId)
                .get();
        if (doc.exists) {
          _userCache[order.userId] = MyUser.fromDocument(
            doc.data() as Map<String, dynamic>,
          );
        } else {
          _userCache[order.userId] = null;
        }
        updated = true;
      }
    }
    if (updated && mounted) {
      setState(() {});
    }
  }

  void _updateFilterOptions(List<MyOrder> orders) {
    final Set<String> productNames = {'All'};
    for (final order in orders) {
      final productName = _productCache[order.productId]?.productName;
      if (productName != null) {
        productNames.add(productName);
      }
    }

    final Set<String> dates = {'All'};
    for (final order in orders) {
      if (order.orderDate.isNotEmpty) {
        final date = order.orderDate.split('T')[0];
        dates.add(date);
      }
    }

    bool optionsChanged = false;
    if (_productFilterOptions.length != productNames.length) {
      optionsChanged = true;
    } else {
      for (final p in productNames) {
        if (!_productFilterOptions.contains(p)) {
          optionsChanged = true;
          break;
        }
      }
    }

    if (_dateFilterOptions.length != dates.length) {
      optionsChanged = true;
    } else {
      for (final d in dates) {
        if (!_dateFilterOptions.contains(d)) {
          optionsChanged = true;
          break;
        }
      }
    }

    if (optionsChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _productFilterOptions.clear();
            _productFilterOptions.addAll(productNames);
            _dateFilterOptions.clear();
            _dateFilterOptions.addAll(dates);

            if (!_productFilterOptions.contains(_selectedProductFilter)) {
              _selectedProductFilter = 'All';
            }
            if (!_dateFilterOptions.contains(_selectedDateFilter)) {
              _selectedDateFilter = 'All';
            }
          });
        }
      });
    }
  }

  // --- BULK ACTIONS ---
  Future<void> _approveSelectedExchanges() async {
    showLoadingDialog(context);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in _selectedOrderIds) {
        final docRef = FirebaseFirestore.instance.collection('orders').doc(id);
        batch.update(docRef, {
          'exchangeStatus': '승인됨',
          'orderStatus': 'orderComplete',
          'confirmed': true,
          'trackingNumber': '',
          'carrierId': '',
        });
        if (_exchangesCache.containsKey(id)) {
          final exchangeId = _exchangesCache[id]?['exchangeId'];
          if (exchangeId != null) {
            final exRef = FirebaseFirestore.instance
                .collection('exchanges')
                .doc(exchangeId);
            batch.update(exRef, {'status': '승인됨'});
          }
        }
        if (_refundsCache.containsKey(id)) {
          final refundId = _refundsCache[id]?['refundId'];
          if (refundId != null) {
            final refRef = FirebaseFirestore.instance
                .collection('refunds')
                .doc(refundId);
            batch.update(refRef, {'status': '승인됨'});
          }
        }
      }
      await batch.commit();

      if (!mounted) return;
      setState(() {
        _selectedOrderIds.clear();
      });

      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('exchange_approved')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('error_occurred')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectSelectedExchanges(String reason) async {
    showLoadingDialog(context);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in _selectedOrderIds) {
        final docRef = FirebaseFirestore.instance.collection('orders').doc(id);
        batch.update(docRef, {
          'exchangeStatus': '거절됨',
          'exchangeReason': reason,
        });
        if (_exchangesCache.containsKey(id)) {
          final exchangeId = _exchangesCache[id]?['exchangeId'];
          if (exchangeId != null) {
            final exRef = FirebaseFirestore.instance
                .collection('exchanges')
                .doc(exchangeId);
            batch.update(exRef, {'status': '거절됨'});
          }
        }
        if (_refundsCache.containsKey(id)) {
          final refundId = _refundsCache[id]?['refundId'];
          if (refundId != null) {
            final refRef = FirebaseFirestore.instance
                .collection('refunds')
                .doc(refundId);
            batch.update(refRef, {'status': '거절됨'});
          }
        }
      }
      await batch.commit();

      if (!mounted) return;
      setState(() {
        _selectedOrderIds.clear();
      });

      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('exchange_rejected')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('error_occurred')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showRejectReasonDialog() async {
    String? selectedReason = 'reason_product_damage';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              title: Text(
                tr('btn_reject_request'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    tileColor:
                        selectedReason == 'reason_product_damage'
                            ? const Color(0xFFF5F5F5)
                            : null,
                    title: Text(
                      tr('reason_product_damage'),
                      style: TextStyle(
                        fontWeight:
                            selectedReason == 'reason_product_damage'
                                ? FontWeight.bold
                                : FontWeight.normal,
                        color: Colors.black,
                      ),
                    ),
                    trailing:
                        selectedReason == 'reason_product_damage'
                            ? const Icon(Icons.check, color: Colors.black)
                            : null,
                    onTap: () {
                      setStateDialog(() {
                        selectedReason = 'reason_product_damage';
                      });
                    },
                  ),
                  ListTile(
                    tileColor:
                        selectedReason == 'reason_traces_of_use'
                            ? const Color(0xFFF5F5F5)
                            : null,
                    title: Text(
                      tr('reason_traces_of_use'),
                      style: TextStyle(
                        fontWeight:
                            selectedReason == 'reason_traces_of_use'
                                ? FontWeight.bold
                                : FontWeight.normal,
                        color: Colors.black,
                      ),
                    ),
                    trailing:
                        selectedReason == 'reason_traces_of_use'
                            ? const Icon(Icons.check, color: Colors.black)
                            : null,
                    onTap: () {
                      setStateDialog(() {
                        selectedReason = 'reason_traces_of_use';
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    tr('btn_cancel'),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (selectedReason != null) {
                      _rejectSelectedExchanges(tr(selectedReason!));
                    }
                  },
                  child: Text(
                    tr('btn_confirm'),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmSelectedOrders() async {
    showLoadingDialog(context);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in _selectedOrderIds) {
        final docRef = FirebaseFirestore.instance.collection('orders').doc(id);
        batch.update(docRef, {'confirmed': true});
      }
      await batch.commit();

      if (!mounted) return;
      setState(() {
        _selectedOrderIds.clear();
      });

      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('confirm_success')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('confirm_fail').replaceFirst('{error}', e.toString()),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelSelectedOrders() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(tr('cancel_dialog_title')),
          content: Text(
            tr(
              'cancel_dialog_confirm',
            ).replaceFirst('{count}', _selectedOrderIds.length.toString()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                tr('cancel'),
                style: const TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                tr('btn_cancel'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    if (!mounted) return;
    showLoadingDialog(context);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in _selectedOrderIds) {
        final docRef = FirebaseFirestore.instance.collection('orders').doc(id);
        batch.update(docRef, {
          'orderStatus': 'cancelled',
          'cancelReason': '고객요청',
        });
      }
      await batch.commit();

      if (!mounted) return;
      setState(() {
        _selectedOrderIds.clear();
      });

      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('cancel_success')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('cancel_fail').replaceFirst('{error}', e.toString()),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _directDeliverySelectedOrders() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(tr('direct_delivery_title')),
          content: Text(
            tr(
              'direct_delivery_confirm',
            ).replaceFirst('{count}', _selectedOrderIds.length.toString()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                tr('cancel'),
                style: const TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                tr('btn_confirm'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    if (!mounted) return;
    showLoadingDialog(context);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in _selectedOrderIds) {
        final docRef = FirebaseFirestore.instance.collection('orders').doc(id);
        batch.update(docRef, {
          'orderStatus': 'IN_TRANSIT',
          'carrierId': '직접배송',
          'trackingNumber': '직접배송',
        });
      }
      await batch.commit();

      if (!mounted) return;
      setState(() {
        _selectedOrderIds.clear();
      });

      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('direct_delivery_success')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('direct_delivery_fail').replaceFirst('{error}', e.toString()),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeSelectedDeliveries() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(tr('delivery_complete_dialog_title')),
          content: Text(
            tr(
              'delivery_complete_dialog_confirm',
            ).replaceFirst('{count}', _selectedOrderIds.length.toString()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                tr('cancel'),
                style: const TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                tr('btn_confirm'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    if (!mounted) return;
    showLoadingDialog(context);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in _selectedOrderIds) {
        final docRef = FirebaseFirestore.instance.collection('orders').doc(id);
        batch.update(docRef, {'orderStatus': 'DELIVERED'});
      }
      await batch.commit();

      if (!mounted) return;
      setState(() {
        _selectedOrderIds.clear();
      });

      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('delivery_complete_success')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('delivery_complete_fail').replaceFirst('{error}', e.toString()),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeSingleDelivery(MyOrder order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(tr('delivery_complete_dialog_title')),
          content: Text(
            tr('delivery_complete_dialog_confirm').replaceFirst('{count}', '1'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                tr('cancel'),
                style: const TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                tr('btn_confirm'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    if (!mounted) return;
    showLoadingDialog(context);
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.orderId)
          .update({'orderStatus': 'DELIVERED'});

      if (!mounted) return;
      setState(() {
        _selectedOrderIds.remove(order.orderId);
      });

      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('delivery_complete_success')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('delivery_complete_fail').replaceFirst('{error}', e.toString()),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- SUB WIDGET BUILDERS ---
  Widget _buildTabCard(int index, String label, String count, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTabIndex = index;
          _selectedOrderIds.clear(); // clear selections when switching tabs
        });
      },
      child: Container(
        width: 160,
        margin: EdgeInsets.zero,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFFD9D9D9),
          borderRadius: BorderRadius.zero,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(height: 6),
            Text(
              count,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? Colors.black : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow(List<MyOrder> orders) {
    return Row(
      children: [
        if (_currentTabIndex == 0) ...[
          // 주문확인 (Confirm)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9D9D9),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed:
                _selectedOrderIds.isEmpty ? null : _confirmSelectedOrders,
            child: Text(
              tr('btn_confirm'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          // 주문취소 (Cancel)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9D9D9),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: _selectedOrderIds.isEmpty ? null : _cancelSelectedOrders,
            child: Text(
              tr('btn_cancel'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ] else if (_currentTabIndex == 1) ...[
          // 직접배송처리 (Direct Delivery)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9D9D9),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed:
                _selectedOrderIds.isEmpty
                    ? null
                    : _directDeliverySelectedOrders,
            child: Text(
              tr('btn_direct_delivery'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          // 주문취소 (Cancel)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9D9D9),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: _selectedOrderIds.isEmpty ? null : _cancelSelectedOrders,
            child: Text(
              tr('btn_cancel'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ] else if (_currentTabIndex == 2) ...[
          // 배송완료 (Delivery Complete)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9D9D9),
              foregroundColor: Colors.black,
              elevation: 0,
              side: BorderSide.none,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed:
                _selectedOrderIds.isEmpty ? null : _completeSelectedDeliveries,
            child: Text(
              tr('btn_delivery_complete'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          // 주문취소 (Cancel)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9D9D9),
              foregroundColor: Colors.black,
              elevation: 0,
              side: BorderSide.none,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: _selectedOrderIds.isEmpty ? null : _cancelSelectedOrders,
            child: Text(
              tr('btn_cancel'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ] else if (_currentTabIndex == 4) ...[
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9D9D9),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed:
                _selectedOrderIds.isEmpty ? null : _approveSelectedExchanges,
            child: Text(
              tr('btn_approve_request'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9D9D9),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed:
                _selectedOrderIds.isEmpty ? null : _showRejectReasonDialog,
            child: Text(
              tr('btn_reject_request'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ] else if (_currentTabIndex == 6) ...[
          // 주문취소 (Cancel gift order)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9D9D9),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: _selectedOrderIds.isEmpty ? null : _cancelSelectedOrders,
            child: Text(
              tr('btn_cancel'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
        const Spacer(),
        // Search Box
        SizedBox(
          width: 230,
          height: 36,
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() {}),
            decoration: InputDecoration(
              hintText: tr('search_placeholder'),
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: Color(0xFFD9D9D9)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: Colors.black),
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        // Product Filter
        Container(
          width: 140,
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD9D9D9)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedProductFilter,
              onChanged: (val) {
                setState(() {
                  _selectedProductFilter = val!;
                });
              },
              items:
                  _productFilterOptions.map((String opt) {
                    return DropdownMenuItem<String>(
                      value: opt,
                      child: Text(
                        opt == 'All' ? tr('filter_product') : opt,
                        style: TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
        SizedBox(width: 12),
        // Date Filter
        Container(
          width: 140,
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD9D9D9)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedDateFilter,
              onChanged: (val) {
                setState(() {
                  _selectedDateFilter = val!;
                });
              },
              items:
                  _dateFilterOptions.map((String opt) {
                    return DropdownMenuItem<String>(
                      value: opt,
                      child: Text(
                        opt == 'All' ? tr('filter_date') : opt,
                        style: TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeaderRow(
    List<OrderTableColumn> columns,
    List<MyOrder> visibleOrders,
  ) {
    final bool isAllSelected =
        visibleOrders.isNotEmpty &&
        visibleOrders.every((o) => _selectedOrderIds.contains(o.orderId));

    return Container(
      color: Colors.white,
      child: Row(
        children:
            columns.map((col) {
              final width = _getColumnWidth(col);
              final isLast = col == columns.last;

              Widget cellChild;
              if (col == OrderTableColumn.checkbox) {
                cellChild = Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tr('col_select_all'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: isAllSelected,
                        activeColor: Colors.black,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedOrderIds.addAll(
                                visibleOrders.map((o) => o.orderId),
                              );
                            } else {
                              _selectedOrderIds.removeAll(
                                visibleOrders.map((o) => o.orderId),
                              );
                            }
                          });
                        },
                      ),
                    ),
                  ],
                );
              } else if (col == OrderTableColumn.submitAction) {
                cellChild = const SizedBox.shrink();
              } else {
                cellChild = Text(
                  _getColumnTitle(col),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                );
              }

              final bool isBorderLast =
                  isLast ||
                  (col == columns[columns.length - 2] &&
                      columns.last == OrderTableColumn.submitAction);

              return Container(
                width: width,
                height: 54,
                alignment: Alignment.center,
                decoration:
                    col == OrderTableColumn.checkbox ||
                            col == OrderTableColumn.submitAction
                        ? const BoxDecoration(color: Colors.transparent)
                        : BoxDecoration(
                          border: Border(
                            top: const BorderSide(color: Colors.black),
                            left: const BorderSide(color: Colors.black),
                            bottom: const BorderSide(color: Colors.black),
                            right:
                                isBorderLast
                                    ? const BorderSide(color: Colors.black)
                                    : BorderSide.none,
                          ),
                        ),
                child: cellChild,
              );
            }).toList(),
      ),
    );
  }

  Widget _buildButtonsHeaderRow(List<OrderTableColumn> columns) {
    return Row(
      children:
          columns.map((col) {
            final width = _getColumnWidth(col);
            if (col == OrderTableColumn.carrier) {
              return SizedBox(
                width: width,
                height: 38,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    side: const BorderSide(color: Colors.black, width: 1),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: _downloadOrdersAsExcel,
                  child: Text(
                    tr('btn_excel_download'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              );
            } else if (col == OrderTableColumn.trackingNumber) {
              return SizedBox(
                width: width,
                height: 38,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    side: const BorderSide(color: Colors.black, width: 1),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: _uploadTrackingExcel,
                  child: Text(
                    tr('btn_tracking_upload'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              );
            } else {
              return SizedBox(width: width, height: 38);
            }
          }).toList(),
    );
  }

  Widget _buildOrderRowItem(MyOrder order, List<OrderTableColumn> columns) {
    final isSelected = _selectedOrderIds.contains(order.orderId);
    final product = _productCache[order.productId];
    final user = _userCache[order.userId];
    final formKey = formKeys.putIfAbsent(
      order.orderId,
      () => GlobalKey<FormState>(),
    );

    final trackingNumberController = trackingControllers.putIfAbsent(
      order.orderId,
      () => TextEditingController(text: order.trackingNumber),
    );
    final courierIdController = courierControllers.putIfAbsent(
      order.orderId,
      () => TextEditingController(text: order.carrierId),
    );

    return Form(
      key: formKey,
      child: Row(
        children:
            columns.map((col) {
              final bool isDirectDelivery =
                  (order.carrierId == '직접배송' ||
                      order.trackingNumber == '직접배송') &&
                  (_currentTabIndex == 2 || _currentTabIndex == 3);
              if (col == OrderTableColumn.trackingNumber && isDirectDelivery) {
                return const SizedBox.shrink();
              }
              final width =
                  col == OrderTableColumn.carrier && isDirectDelivery
                      ? _getColumnWidth(col) +
                          _getColumnWidth(OrderTableColumn.trackingNumber)
                      : _getColumnWidth(col);
              final isLast = col == columns.last;

              Widget cellChild;
              Alignment alignment = Alignment.center;
              EdgeInsets padding = EdgeInsets.symmetric(horizontal: 8);

              switch (col) {
                case OrderTableColumn.checkbox:
                  padding = EdgeInsets.zero;
                  alignment = Alignment.center;
                  cellChild = Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Visibility(
                        visible: false,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: Text(
                          tr('col_select_all'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: isSelected,
                          activeColor: Colors.black,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedOrderIds.add(order.orderId);
                              } else {
                                _selectedOrderIds.remove(order.orderId);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  );
                  break;
                case OrderTableColumn.orderDate:
                  String formattedDate = '';
                  try {
                    formattedDate =
                        DateTime.parse(
                          order.orderDate,
                        ).toLocal().toString().split('.')[0];
                  } catch (_) {
                    formattedDate = order.orderDate;
                  }
                  alignment = Alignment.center;
                  cellChild = Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  );
                  break;
                case OrderTableColumn.orderId:
                  alignment = Alignment.center;
                  cellChild = Text(
                    order.orderId,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  );
                  break;
                case OrderTableColumn.productName:
                  alignment = Alignment.center;
                  final String text;
                  if (!_productCache.containsKey(order.productId)) {
                    text = tr('loading');
                  } else {
                    text = product?.productName ?? tr('deleted_product');
                  }
                  cellChild = Text(
                    text,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  );
                  break;
                case OrderTableColumn.quantity:
                  alignment = Alignment.center;
                  cellChild = Text(
                    order.quantity.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  );
                  break;
                case OrderTableColumn.recipientName:
                  alignment = Alignment.center;
                  final String text;
                  if (!_userCache.containsKey(order.userId)) {
                    text = tr('loading');
                  } else {
                    text = user?.name ?? tr('deleted_user');
                  }
                  cellChild = Text(
                    text,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  );
                  break;
                case OrderTableColumn.phone:
                  alignment = Alignment.center;
                  cellChild = Text(
                    order.phoneNo,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  );
                  break;
                case OrderTableColumn.address:
                  final fullAddress =
                      "${order.deliveryAddress} ${order.deliveryAddressDetail}";
                  alignment = Alignment.center;
                  cellChild = Text(
                    fullAddress,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  );
                  break;
                case OrderTableColumn.deliveryRequest:
                  alignment = Alignment.center;
                  cellChild = Text(
                    order.deliveryInstructions.isEmpty
                        ? '-'
                        : order.deliveryInstructions,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  );
                  break;
                case OrderTableColumn.carrier:
                  padding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
                  alignment = Alignment.center;
                  if (_currentTabIndex == 2 ||
                      _currentTabIndex == 3 ||
                      _currentTabIndex == 4) {
                    cellChild = Text(
                      isDirectDelivery
                          ? tr('direct_delivery_label')
                          : (order.carrierId.isEmpty ? '-' : order.carrierId),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    );
                  } else {
                    final bool enabled = order.confirmed;
                    cellChild = TextFormField(
                      enabled: enabled,
                      controller: courierIdController,
                      decoration: InputDecoration(
                        hintText: tr('col_courier'),
                        hintStyle: TextStyle(fontSize: 11),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }
                  break;
                case OrderTableColumn.trackingNumber:
                  padding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
                  alignment = Alignment.center;
                  if (_currentTabIndex == 2 ||
                      _currentTabIndex == 3 ||
                      _currentTabIndex == 4) {
                    cellChild = Text(
                      order.trackingNumber.isEmpty ? '-' : order.trackingNumber,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    );
                  } else {
                    final bool enabled = order.confirmed;
                    cellChild = TextFormField(
                      enabled: enabled,
                      controller: trackingNumberController,
                      decoration: InputDecoration(
                        hintText: tr('col_tracking'),
                        hintStyle: TextStyle(fontSize: 11),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return tr('input_needed');
                        }
                        return null;
                      },
                    );
                  }
                  break;
                case OrderTableColumn.submitAction:
                  padding = EdgeInsets.zero;
                  alignment = Alignment.center;
                  if (_currentTabIndex == 2) {
                    final isDirect =
                        order.carrierId == '직접배송' &&
                        order.trackingNumber == '직접배송';
                    cellChild = ElevatedButton(
                      onPressed: () async {
                        if (isDirect) {
                          await _completeSingleDelivery(order);
                        } else {
                          final url = Uri.parse(
                            'https://tracker.delivery/#/${order.carrierId}/${order.trackingNumber}',
                          );
                          if (await canLaunchUrl(url)) {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      child: Text(
                        isDirect
                            ? tr('btn_delivery_complete')
                            : tr('btn_track'),
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  } else {
                    final bool canSubmit = order.confirmed;
                    cellChild = ElevatedButton(
                      onPressed:
                          canSubmit
                              ? () async {
                                if (!formKey.currentState!.validate()) return;
                                formKey.currentState!.save();
                                showLoadingDialog(context);
                                await registerTrackingManually(
                                  courierIdController.text,
                                  trackingNumberController.text,
                                  order,
                                );
                                if (!mounted) return;
                                Navigator.pop(context);
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            canSubmit ? Colors.black : const Color(0xFFD9D9D9),
                        foregroundColor:
                            canSubmit ? Colors.white : Colors.black54,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        side: BorderSide.none,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      child: Text(
                        tr('btn_submit'),
                        style: TextStyle(fontSize: 11),
                      ),
                    );
                  }
                  break;
                case OrderTableColumn.settlementDate:
                  padding = const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  );
                  alignment = Alignment.center;
                  cellChild = Text(
                    product?.estimatedSettlementDate != null &&
                            product!.estimatedSettlementDate!.isNotEmpty
                        ? product.estimatedSettlementDate!
                        : '-',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  );
                  break;
                case OrderTableColumn.productPrice:
                  padding = const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  );
                  alignment = Alignment.center;
                  final double pPrice =
                      product?.price ??
                      (order.quantity > 0
                          ? order.totalPrice / order.quantity
                          : 0);
                  cellChild = Text(
                    _formatCurrency(pPrice),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  );
                  break;
                case OrderTableColumn.deliveryFee:
                  padding = const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  );
                  alignment = Alignment.center;
                  final double? dFee =
                      product?.shippingFee ?? product?.deliveryPrice;
                  cellChild = Text(
                    _formatCurrency(dFee),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  );
                  break;
                case OrderTableColumn.islandDeliveryFee:
                  padding = const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  );
                  alignment = Alignment.center;
                  cellChild = Text(
                    _formatCurrency(0.0),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  );
                  break;
                case OrderTableColumn.settlementAmount:
                  padding = const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  );
                  alignment = Alignment.center;
                  final double settlementAmt =
                      product?.estimatedSettlement ??
                      (product != null
                          ? (product.supplyPrice * order.quantity +
                              (product.deliveryPrice ?? 0.0))
                          : 0.0);
                  cellChild = Text(
                    _formatCurrency(settlementAmt),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  );
                  break;
                case OrderTableColumn.exchangeReason:
                  padding = const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  );
                  alignment = Alignment.center;
                  String displayReason = '-';
                  if (_exchangesCache.containsKey(order.orderId)) {
                    displayReason =
                        _exchangesCache[order.orderId]?['reason'] ?? '교환';
                  } else if (_refundsCache.containsKey(order.orderId)) {
                    displayReason =
                        _refundsCache[order.orderId]?['reason'] ?? '환불';
                  } else {
                    displayReason = order.exchangeReason ?? '-';
                  }
                  cellChild = Text(
                    tr(displayReason),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  );
                  break;
                case OrderTableColumn.exchangeStatus:
                  padding = const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  );
                  alignment = Alignment.center;
                  String displayStatus = '-';
                  if (order.exchangeStatus != null) {
                    displayStatus = order.exchangeStatus!;
                  } else if (_exchangesCache.containsKey(order.orderId)) {
                    displayStatus =
                        _exchangesCache[order.orderId]?['status'] ?? '대기중';
                  } else if (_refundsCache.containsKey(order.orderId)) {
                    displayStatus =
                        _refundsCache[order.orderId]?['status'] ?? '대기중';
                  } else {
                    displayStatus = order.exchangeStatus ?? '-';
                  }
                  cellChild = Text(
                    tr(displayStatus),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  );
                  break;
              }

              final bool isBorderLast =
                  isLast ||
                  (col == columns[columns.length - 2] &&
                      columns.last == OrderTableColumn.submitAction) ||
                  (col == OrderTableColumn.carrier &&
                      isDirectDelivery &&
                      columns.last == OrderTableColumn.submitAction);

              return Container(
                width: width,
                height: 54,
                alignment: alignment,
                padding: padding,
                decoration:
                    col == OrderTableColumn.checkbox ||
                            col == OrderTableColumn.submitAction
                        ? const BoxDecoration(color: Colors.transparent)
                        : BoxDecoration(
                          color:
                              isSelected
                                  ? const Color(0xFFF9F9F9)
                                  : Colors.white,
                          border: Border(
                            left: const BorderSide(color: Colors.black),
                            bottom: const BorderSide(color: Colors.black),
                            right:
                                isBorderLast
                                    ? const BorderSide(color: Colors.black)
                                    : BorderSide.none,
                          ),
                        ),
                child: cellChild,
              );
            }).toList(),
      ),
    );
  }

  Widget _buildFilteredOrdersTable(List<MyOrder> orders) {
    // 1. Filter by selected tab index
    final List<MyOrder> stageOrders =
        orders.where((order) {
          switch (_currentTabIndex) {
            case 0: // 신규 주문
              return order.orderStatus == 'orderComplete' &&
                  !order.confirmed &&
                  !_hasPendingExchangeOrRefund(order.orderId);
            case 1: // 준비중
              return order.orderStatus == 'orderComplete' &&
                  order.confirmed &&
                  !_hasPendingExchangeOrRefund(order.orderId);
            case 2: // 배송중
              return order.orderStatus == 'IN_TRANSIT' &&
                  !_hasPendingExchangeOrRefund(order.orderId);
            case 3: // 배송완료 및 정산
              return order.orderStatus == 'DELIVERED' &&
                  !_hasPendingExchangeOrRefund(order.orderId);
            case 4: // 교환·반품 요청
              return _hasPendingExchangeOrRefund(order.orderId);
            case 6: // 선물대기
              return order.orderStatus == 'giftPending' &&
                  !_hasPendingExchangeOrRefund(order.orderId);
            default:
              return false;
          }
        }).toList();

    // 2. Search query and filters
    final query = _searchController.text.toLowerCase();
    final List<MyOrder> visibleOrders =
        stageOrders.where((order) {
          final product = _productCache[order.productId];
          final user = _userCache[order.userId];
          final productName = product?.productName ?? '';
          final userName = user?.name ?? '';
          final address =
              "${order.deliveryAddress} ${order.deliveryAddressDetail}";

          final matchesQuery =
              query.isEmpty ||
              productName.toLowerCase().contains(query) ||
              userName.toLowerCase().contains(query) ||
              address.toLowerCase().contains(query) ||
              order.orderId.toLowerCase().contains(query);

          final matchesProduct =
              _selectedProductFilter == 'All' ||
              productName == _selectedProductFilter;

          final matchesDate =
              _selectedDateFilter == 'All' ||
              order.orderDate.startsWith(_selectedDateFilter);

          return matchesQuery && matchesProduct && matchesDate;
        }).toList();

    if (visibleOrders.isEmpty) {
      return Center(
        child: Text(
          tr('no_orders'),
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final columns = _getColumnsForTab(_currentTabIndex);
    final double totalTableWidth = columns.fold(
      0.0,
      (total, col) => total + _getColumnWidth(col),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentTabIndex == 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _buttonsScrollController,
            child: SizedBox(
              width: totalTableWidth,
              child: _buildButtonsHeaderRow(columns),
            ),
          ),
          const SizedBox(height: 4),
        ],
        // Header
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _headerScrollController,
          child: SizedBox(
            width: totalTableWidth,
            child: _buildTableHeaderRow(columns, visibleOrders),
          ),
        ),
        // Body
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _bodyScrollController,
            child: SizedBox(
              width: totalTableWidth,
              child: ListView.builder(
                itemCount: visibleOrders.length,
                itemBuilder: (context, index) {
                  return _buildOrderRowItem(visibleOrders[index], columns);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<MyOrder> _getFilteredOrders() {
    final List<MyOrder> stageOrders =
        widget.orders.where((order) {
          switch (_currentTabIndex) {
            case 0: // 신규 주문
              return order.orderStatus == 'orderComplete' &&
                  !order.confirmed &&
                  !_hasPendingExchangeOrRefund(order.orderId);
            case 1: // 준비중
              return order.orderStatus == 'orderComplete' &&
                  order.confirmed &&
                  !_hasPendingExchangeOrRefund(order.orderId);
            case 2: // 배송중
              return order.orderStatus == 'IN_TRANSIT' &&
                  !_hasPendingExchangeOrRefund(order.orderId);
            case 3: // 배송완료 및 정산
              return order.orderStatus == 'DELIVERED' &&
                  !_hasPendingExchangeOrRefund(order.orderId);
            case 4: // 교환·반품 요청
              return _hasPendingExchangeOrRefund(order.orderId);
            case 6: // 선물대기
              return order.orderStatus == 'giftPending' &&
                  !_hasPendingExchangeOrRefund(order.orderId);
            default:
              return false;
          }
        }).toList();

    final query = _searchController.text.toLowerCase();
    return stageOrders.where((order) {
      final product = _productCache[order.productId];
      final user = _userCache[order.userId];
      final productName =
          product?.productName ??
          (_productCache.containsKey(order.productId)
              ? tr('deleted_product')
              : '');
      final userName =
          user?.name ??
          (_userCache.containsKey(order.userId) ? tr('deleted_user') : '');
      final address = "${order.deliveryAddress} ${order.deliveryAddressDetail}";

      final matchesQuery =
          query.isEmpty ||
          productName.toLowerCase().contains(query) ||
          userName.toLowerCase().contains(query) ||
          address.toLowerCase().contains(query) ||
          order.orderId.toLowerCase().contains(query);

      final matchesProduct =
          _selectedProductFilter == 'All' ||
          productName == _selectedProductFilter;

      final matchesDate =
          _selectedDateFilter == 'All' ||
          order.orderDate.startsWith(_selectedDateFilter);

      return matchesQuery && matchesProduct && matchesDate;
    }).toList();
  }

  Future<void> _downloadOrdersAsExcel() async {
    final visibleOrders = _getFilteredOrders();
    if (visibleOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('no_orders')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    // Header row
    sheet.appendRow([
      TextCellValue(tr('xls_date')),
      TextCellValue(tr('xls_id')),
      TextCellValue(tr('xls_recipient')),
      TextCellValue(tr('xls_phone')),
      TextCellValue(tr('xls_address')),
      TextCellValue(tr('xls_detail_address')),
      TextCellValue(tr('xls_instructions')),
      TextCellValue(tr('xls_product')),
      TextCellValue(tr('xls_qty')),
      TextCellValue(tr('xls_price')),
      TextCellValue(tr('xls_supply_price')),
      TextCellValue(tr('xls_shipping')),
      TextCellValue(tr('xls_additional_shipping')),
      TextCellValue(tr('xls_courier')),
      TextCellValue(tr('xls_tracking')),
    ]);

    for (var order in visibleOrders) {
      final user = _userCache[order.userId];
      final product = _productCache[order.productId];

      final userName =
          user?.name ??
          (_userCache.containsKey(order.userId)
              ? tr('deleted_user')
              : tr('loading'));
      final productName =
          product?.productName ??
          (_productCache.containsKey(order.productId)
              ? tr('deleted_product')
              : tr('loading'));

      sheet.appendRow([
        TextCellValue(
          DateTime.parse(order.orderDate).toLocal().toString().split('.')[0],
        ),
        TextCellValue(order.orderId),
        TextCellValue(userName),
        TextCellValue(order.phoneNo),
        TextCellValue(order.deliveryAddress),
        TextCellValue(order.deliveryAddressDetail),
        TextCellValue(order.deliveryInstructions),
        TextCellValue(productName),
        TextCellValue(order.quantity.toString()),
        TextCellValue(order.totalPrice.toString()),
        TextCellValue(product?.supplyPrice.toString() ?? ''),
        TextCellValue(product?.deliveryPrice?.toString() ?? ''),
        TextCellValue(product?.shippingFee?.toString() ?? ''),
        TextCellValue(order.carrierId),
        TextCellValue(order.trackingNumber),
      ]);
    }

    final fileBytes = excel.encode();
    if (fileBytes != null) {
      await FileSaver.instance.saveFile(
        name: 'orders.xlsx',
        bytes: Uint8List.fromList(fileBytes),
      );
    }
  }

  Future<void> _uploadTrackingExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    final excel = Excel.decodeBytes(bytes);
    final sheet = excel['Sheet1'];

    for (var row in sheet.rows.skip(1)) {
      if (row.length <= 14) continue;
      final orderId = row[1]?.value?.toString(); // Index 1 is orderId
      final trackingNumber =
          row[14]?.value?.toString(); // Index 14 is trackingNumber
      final courierId = row[13]?.value?.toString(); // Index 13 is courierId

      if (orderId != null && orderId.isNotEmpty) {
        // Look up the order in local memory list
        MyOrder? localOrder;
        for (final o in widget.orders) {
          if (o.orderId == orderId) {
            localOrder = o;
            break;
          }
        }

        if (localOrder != null && localOrder.confirmed) {
          if (trackingNumber != null && trackingNumber.isNotEmpty) {
            trackingControllers[orderId]?.text = trackingNumber;
          }
          if (courierId != null && courierId.isNotEmpty) {
            courierControllers[orderId]?.text = courierId;
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {}); // Rebuild to display loaded values in table text fields
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('tracking_loaded'))));
  }

  Future<Map<String, dynamic>> registerTrackingManually(
    String carrierId,
    String trackingNumber,
    MyOrder order,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.orderId)
          .update({'trackingNumber': trackingNumber, 'carrierId': carrierId});
      final callbackUrl = 'https://trackingwebhook-nlc5xkd7oa-uc.a.run.app/';
      final expirationTime =
          DateTime.now().add(Duration(hours: 48)).toUtc().toIso8601String();

      final response = await http.post(
        Uri.parse('https://apis.tracker.delivery/graphql'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'TRACKQL-API-KEY 6fvqe192p5v5ik6p5aev1ntud4:1eh63r90t9mms8be76r2npve71fcoeqi70e5pud3ve2vfvtdietd',
        },
        body: json.encode({
          "query":
              "mutation RegisterTrackWebhook(\$input: RegisterTrackWebhookInput!) { registerTrackWebhook(input: \$input) }",
          "variables": {
            "input": {
              "carrierId": carrierId,
              "trackingNumber": trackingNumber,
              "callbackUrl": callbackUrl,
              "expirationTime": expirationTime,
            },
          },
        }),
      );

      final responseData = json.decode(response.body);

      if (!mounted) return {'success': false};

      if (response.statusCode == 200 && !responseData.containsKey('errors')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('order_updated')),
            backgroundColor: Colors.green,
          ),
        );
        return {'success': true};
      } else {
        final errorMessage =
            responseData['errors'] != null
                ? responseData['errors'][0]['message']
                : 'Failed to register tracking webhook';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('error_occurred')}: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
        return {'success': false, 'error': errorMessage};
      }
    } catch (e) {
      if (!mounted) return {'success': false, 'error': e.toString()};
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('error_occurred')}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = widget.orders;

    // Preload users and products in the background
    _preloadOrderData(orders);

    // Populate filters options
    _updateFilterOptions(orders);

    // Calculate counts
    final newCount =
        orders
            .where(
              (o) =>
                  o.orderStatus == 'orderComplete' &&
                  !o.confirmed &&
                  !_hasPendingExchangeOrRefund(o.orderId),
            )
            .length
            .toString();
    final preparingCount =
        orders
            .where(
              (o) =>
                  o.orderStatus == 'orderComplete' &&
                  o.confirmed &&
                  !_hasPendingExchangeOrRefund(o.orderId),
            )
            .length
            .toString();
    final inTransitCount =
        orders
            .where(
              (o) =>
                  o.orderStatus == 'IN_TRANSIT' &&
                  !_hasPendingExchangeOrRefund(o.orderId),
            )
            .length
            .toString();
    final settledCount =
        orders
            .where(
              (o) =>
                  o.orderStatus == 'DELIVERED' &&
                  !_hasPendingExchangeOrRefund(o.orderId),
            )
            .length
            .toString();
    final exchangeCount =
        orders
            .where(
              (o) =>
                  _hasPendingExchangeOrRefund(o.orderId),
            )
            .length
            .toString();
    final giftCount =
        orders
            .where(
              (o) =>
                  o.orderStatus == 'giftPending' &&
                  !_hasPendingExchangeOrRefund(o.orderId),
            )
            .length
            .toString();

    return StreamBuilder<int>(
      stream: widget.chatCountsStream,
      builder: (context, chatSnapshot) {
        final chatCount = (chatSnapshot.data ?? 0).toString();

        return Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Section: Tabs and User Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Two rows of tabs
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildTabCard(
                              0,
                              tr('tab_new'),
                              newCount,
                              _currentTabIndex == 0,
                            ),
                            _buildTabCard(
                              1,
                              tr('tab_preparing'),
                              preparingCount,
                              _currentTabIndex == 1,
                            ),
                            _buildTabCard(
                              2,
                              tr('tab_shipping'),
                              inTransitCount,
                              _currentTabIndex == 2,
                            ),
                            _buildTabCard(
                              3,
                              tr('tab_completed'),
                              settledCount,
                              _currentTabIndex == 3,
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            _buildTabCard(
                              4,
                              tr('tab_exchange'),
                              exchangeCount,
                              _currentTabIndex == 4,
                            ),
                            _buildTabCard(
                              5,
                              tr('tab_chat'),
                              chatCount,
                              _currentTabIndex == 5,
                            ),
                            _buildTabCard(
                              6,
                              tr('tab_gift'),
                              giftCount,
                              _currentTabIndex == 6,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Right: Menu Card & Language Switcher / Logout
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9D9D9),
                          border: Border.all(color: const Color(0xFFD9D9D9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildMenuItem(
                              tr('menu_products'),
                              _currentTabIndex == 7,
                              () {
                                setState(() {
                                  _currentTabIndex = 7;
                                });
                              },
                            ),
                            _buildMenuItem(
                              tr('menu_proposals'),
                              _currentTabIndex == 9,
                              () {
                                setState(() {
                                  _currentTabIndex = 9;
                                });
                              },
                            ),
                            _buildMenuItem(
                              tr('menu_profile'),
                              _currentTabIndex == 8,
                              () {
                                setState(() {
                                  _currentTabIndex = 8;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (showLanguageSelector)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => languageNotifier.value = 'ko',
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size(40, 30),
                                  ),
                                  child: Text(
                                    'KO',
                                    style: TextStyle(
                                      color:
                                          languageNotifier.value == 'ko'
                                              ? Colors.black
                                              : Colors.grey,
                                      fontWeight:
                                          languageNotifier.value == 'ko'
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  '|',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => languageNotifier.value = 'en',
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size(40, 30),
                                  ),
                                  child: Text(
                                    'EN',
                                    style: TextStyle(
                                      color:
                                          languageNotifier.value == 'en'
                                              ? Colors.black
                                              : Colors.grey,
                                      fontWeight:
                                          languageNotifier.value == 'en'
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (showLanguageSelector) SizedBox(height: 10),
                          TextButton(
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              if (!context.mounted) return;
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            },
                            child: Text(
                              tr('logout'),
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 24),

              // 2. Action row (hidden for chat tab 5, product tab 7, and profile tab 8)
              if (_currentTabIndex != 5 &&
                  _currentTabIndex != 7 &&
                  _currentTabIndex != 8 &&
                  _currentTabIndex != 9) ...[
                _buildActionRow(orders),
                SizedBox(height: 16),
              ],

              // 3. Table, Chat, or Product View
              Expanded(
                child:
                    _currentTabIndex == 5
                        ? CustomerInquiriesWidget(
                          uid: widget.uid,
                          orders: orders,
                        )
                        : _currentTabIndex == 7
                        ? QuickStockManagementWidget(uid: widget.uid)
                        : _currentTabIndex == 8
                        ? buildManagerInfo(widget.uid)
                        : _currentTabIndex == 9
                        ? ProductProposalForm(uid: widget.uid)
                        : _buildFilteredOrdersTable(orders),
              ),
            ],
          ),
        );
      },
    );
  }
}
