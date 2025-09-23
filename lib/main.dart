import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_manager_interface/core/constants.dart';
import 'package:delivery_manager_interface/loading_dialog.dart';
import 'package:delivery_manager_interface/models/order_model.dart';
import 'package:delivery_manager_interface/models/product_model.dart';
import 'package:delivery_manager_interface/models/user_model.dart';
import 'package:delivery_manager_interface/widgets/manager_info.dart';
import 'package:delivery_manager_interface/widgets/orders_table_header.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return ScreenUtilInit(
      designSize: const Size(1512, 982),
      child: MaterialApp(
        title: '판매자',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.white,
        ),
        home: user != null ? DeliveryManagerInterface() : LoginScreen(),
      ),
    );
  }
}

class DeliveryManagerInterface extends StatefulWidget {
  final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  State<DeliveryManagerInterface> createState() =>
      _DeliveryManagerInterfaceState();
}

class _DeliveryManagerInterfaceState extends State<DeliveryManagerInterface> {
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();
  late final ScrollController _headerScrollController;
  late final ScrollController _bodyScrollController;
  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier<int>(0);
  final Map<String, TextEditingController> trackingControllers = {};
  final Map<String, TextEditingController> courierControllers = {};
  int _currentTabIndex = 0;
  final List<Map<String, String>> _orderStages = [
    {'label': '배송 준비중', 'status': 'Preparing for Shipment'},
    {'label': '배송중', 'status': 'In Transit'},
    {'label': '배송 완료', 'status': 'Completed'},
    {'label': '교환/반품 요청', 'status': 'exchange'}, // special case
  ];
  @override
  void initState() {
    super.initState();
    _headerScrollController = ScrollController();
    _bodyScrollController = ScrollController();
    _headerScrollController.addListener(() {
      if (_bodyScrollController.hasClients &&
          _bodyScrollController.offset != _headerScrollController.offset) {
        _bodyScrollController.jumpTo(_headerScrollController.offset);
      }
    });
    _bodyScrollController.addListener(() {
      if (_headerScrollController.hasClients &&
          _headerScrollController.offset != _bodyScrollController.offset) {
        _headerScrollController.jumpTo(_bodyScrollController.offset);
      }
    });
    // Update the notifier value when positions change
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
    _headerScrollController.dispose();
    _bodyScrollController.dispose();
    super.dispose();
  }

  Widget _buildProductsInfo() {
    return StreamBuilder(
      stream:
          FirebaseFirestore.instance
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
            padding: EdgeInsets.all(16.0),
            child: Text('제품이 없습니다'),
          );
        }

        final products = snapshot.data!.docs;
        return SizedBox(
          height: 300, // Adjust based on your needs
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
                        width: 300, // Fixed width for each product card
                        margin: const EdgeInsets.only(right: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                '계약 정보',
                                style: TextStyle(
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
                                      const Center(child: Text('제품명')),
                                      Center(
                                        child: Text(
                                          product['productName'] ?? 'N/A',
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      const Center(child: Text('공급가')),
                                      Center(
                                        child: Text(
                                          '₩${product['price']?.toString() ?? 'N/A'}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      const Center(child: Text('배송비')),
                                      Center(
                                        child: Text(
                                          '₩ ${product['deliveryPrice']?.toString() ?? 'N/A'}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      const Center(child: Text('도서산간 추가 배송비')),
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
                        width: 300, // Fixed width for each product card
                        margin: const EdgeInsets.only(right: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                '주문 마감 시간/재고 관리',
                                style: TextStyle(
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
                                      const Center(child: Text('주문 마감 시간')),
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
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(0),
                                            ),
                                            fixedSize: Size.fromWidth(110.w),
                                          ),
                                          child: Text(
                                            '변경',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      const Center(child: Text('현재 재고')),
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
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(0),
                                            ),
                                            fixedSize: Size.fromWidth(110.w),
                                          ),
                                          child: Text(
                                            '변경',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  /* TableRow(
                                    children: [
                                      const Center(
                                        child: Text('Estimated settlement'),
                                      ),
                                      Center(
                                        child: Text(
                                          '₩ ${product['estimatedSettlement']?.toString() ?? 'N/A'}',
                                        ),
                                      ),
                                      Center(child: Text('')),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      const Center(
                                        child: Text(
                                          'Estimated settlement date',
                                        ),
                                      ),
                                      Center(
                                        child: Text(
                                          product['estimatedSettlementDate']
                                                  ?.toString() ??
                                              'N/A',
                                        ),
                                      ),
                                      Center(child: Text('')),
                                    ],
                                  ), */
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
                // Left scroll button
                ValueListenableBuilder<int>(
                  valueListenable: _currentIndexNotifier,
                  builder: (context, currentIndex, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left button
                        Container(
                          width: 48,
                          alignment: Alignment.centerLeft,
                          child:
                              currentIndex > 0
                                  ? IconButton(
                                    icon: Icon(Icons.arrow_back_ios),
                                    onPressed:
                                        () => _scrollTo(currentIndex - 1),
                                  )
                                  : SizedBox(),
                        ),

                        // Right button
                        Container(
                          width: 48,
                          alignment: Alignment.centerRight,
                          child:
                              currentIndex < products.length - 1
                                  ? IconButton(
                                    icon: Icon(Icons.arrow_forward_ios),
                                    onPressed:
                                        () => _scrollTo(currentIndex + 1),
                                  )
                                  : SizedBox(),
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

  Future<void> _downloadOrdersAsExcel() async {
    final querySnapshot =
        await FirebaseFirestore.instance
            .collection('orders')
            .where('deliveryManagerId', isEqualTo: widget.uid)
            .where('confirmed', isEqualTo: true)
            .get();

    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    // Header row
    sheet.appendRow([
      TextCellValue('날짜'),
      TextCellValue('주문 ID'),
      TextCellValue('수취인'),
      TextCellValue('전화번호'),
      TextCellValue('주소'),
      TextCellValue('상세주소'),
      TextCellValue('배송 요청사항'),
      TextCellValue('제품'),
      TextCellValue('수량'),
      TextCellValue('가격'),
      TextCellValue('공급가'),
      TextCellValue('배송비'),
      TextCellValue('도서산간 추가 배송비'),
      TextCellValue('택배사'),
      TextCellValue('운송장 번호'),
    ]);

    for (var doc in querySnapshot.docs) {
      final order = MyOrder.fromDocument(doc.data());

      // Fetch user and product info
      final userSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(order.userId)
              .get();
      final user =
          userSnapshot.exists
              ? MyUser.fromDocument(userSnapshot.data() as Map<String, dynamic>)
              : null;

      final productSnapshot =
          await FirebaseFirestore.instance
              .collection('products')
              .doc(order.productId)
              .get();
      final product =
          productSnapshot.exists
              ? Product.fromMap(productSnapshot.data() as Map<String, dynamic>)
              : null;

      sheet.appendRow([
        TextCellValue(
          DateTime.parse(order.orderDate).toLocal().toString().split('.')[0],
        ),
        TextCellValue(order.orderId),
        TextCellValue(user?.name ?? ''),
        TextCellValue(order.phoneNo),
        TextCellValue(order.deliveryAddress),
        TextCellValue(order.deliveryAddressDetail),
        TextCellValue(order.deliveryInstructions),
        TextCellValue(product?.productName ?? ''),
        TextCellValue(order.quantity.toString()),
        TextCellValue(order.totalPrice.toString()),
        TextCellValue(product?.supplyPrice?.toString() ?? ''),
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
      final orderId = row[0]?.value?.toString();
      final trackingNumber = row[14]?.value?.toString();
      final courierId = row[13]?.value?.toString();

      if (orderId != null) {
        // Check if order is confirmed before updating controllers
        final orderDoc =
            await FirebaseFirestore.instance
                .collection('orders')
                .doc(orderId)
                .get();
        if (orderDoc.exists && (orderDoc.data()?['confirmed'] == true)) {
          if (trackingNumber != null) {
            trackingControllers[orderId]?.text = trackingNumber;
          }
          if (courierId != null) {
            courierControllers[orderId]?.text = courierId;
          }
        }
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('운송장 번호가 필드에 로드되었습니다')));
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

      // Parse the response
      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && !responseData.containsKey('errors')) {
        print(responseData);

        // ✅ Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('주문이 업데이트되었습니다'), // "Order confirmed"
            backgroundColor: Colors.green,
          ),
        );

        return {'success': true};
      } else {
        final errorMessage =
            responseData['errors'] != null
                ? responseData['errors'][0]['message']
                : 'Failed to register tracking webhook';
        // ❌ Show error feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류 발생: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
        return {'success': false, 'error': errorMessage};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IntrinsicHeight(
                child:
                    MediaQuery.of(context).size.width < 800
                        ? Column(
                          children: [
                            // Manager Information
                            buildManagerInfo(widget.uid),
                            SizedBox(height: 20),
                            // Products Information
                            _buildProductsInfo(),
                          ],
                        )
                        : Row(
                          children: [
                            Flexible(
                              flex: 1,
                              child: buildManagerInfo(widget.uid),
                            ),
                            Flexible(flex: 3, child: _buildProductsInfo()),
                          ],
                        ),
              ),
              SizedBox(height: 24.h),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,

                child: SizedBox(
                  width: 600,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0),
                          ),
                          minimumSize: Size(110.w, 40),
                        ),
                        onPressed: _downloadOrdersAsExcel,
                        child: Text('주문 엑셀 다운로드'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0),
                          ),
                          minimumSize: Size(110.w, 40),
                        ),
                        onPressed: _uploadTrackingExcel,
                        child: Text('엑셀에서 택배사 및 운송장 번호 업로드'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0),
                          ),
                          minimumSize: Size(110.w, 40),
                        ),
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        child: Text('로그아웃'),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              // Tabs for order stages
              StatefulBuilder(
                builder: (context, setLocalState) {
                  return Column(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,

                        child: SizedBox(
                          width: 1600,

                          child: DefaultTabController(
                            length: 5,
                            child: TabBar(
                              labelColor: Colors.black,
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: Colors.transparent,
                              tabs: const [
                                Tab(text: '신규주문'),
                                Tab(text: '배송준비중'),
                                Tab(text: '배송중'),
                                Tab(text: '배송완료'),
                                Tab(text: '교환 반품요청'),
                              ],
                              onTap: (index) {
                                setLocalState(() {
                                  _currentTabIndex = index;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      ordersTableHeader(_headerScrollController),
                      SizedBox(
                        height: 400, // adjust as needed for table body

                        child: StreamBuilder<QuerySnapshot>(
                          stream:
                              FirebaseFirestore.instance
                                  .collection('orders')
                                  .where(
                                    'deliveryManagerId',
                                    isEqualTo: widget.uid,
                                  )
                                  .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            }
                            // 3. Check for null data
                            if (!snapshot.hasData || snapshot.data == null) {
                              return Center(child: Text('주문이 없습니다'));
                            }
                            final orders = snapshot.data!.docs;

                            if (orders.isEmpty) {
                              return Center(child: Text('주문이 없습니다'));
                            }
                            return _buildOrderTableForStatus(
                              _currentTabIndex,
                            ); /* SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              controller: _bodyScrollController,
                              child: SizedBox(
                                width: 1600,

                                child: ListView.builder(
                                  itemCount: orders.length,
                                  itemBuilder: (context, index) {
                                    final order = MyOrder.fromDocument(
                                      orders[index].data()
                                          as Map<String, dynamic>,
                                    );
                                    return _buildOrderRow(order);
                                  },
                                ),
                              ),
                            ); */
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTableForStatus(int status) {
    late Stream<QuerySnapshot> stream;
    switch (status) {
      case 0:
        stream =
            FirebaseFirestore.instance
                .collection('orders')
                .where('deliveryManagerId', isEqualTo: widget.uid)
                .where('orderStatus', isEqualTo: 'orderComplete')
                .where('confirmed', isEqualTo: false)
                .snapshots();
        break;
      case 1:
        stream =
            FirebaseFirestore.instance
                .collection('orders')
                .where('deliveryManagerId', isEqualTo: widget.uid)
                .where('orderStatus', isEqualTo: 'orderComplete')
                .where('confirmed', isEqualTo: true)
                .snapshots();
        break;
      case 2:
        stream =
            FirebaseFirestore.instance
                .collection('orders')
                .where('deliveryManagerId', isEqualTo: widget.uid)
                .where('orderStatus', isEqualTo: 'IN_TRANSIT')
                .snapshots();
        break;
      case 3:
        stream =
            FirebaseFirestore.instance
                .collection('orders')
                .where('deliveryManagerId', isEqualTo: widget.uid)
                .where('orderStatus', isEqualTo: 'DELIVERED')
                .snapshots();
      case 4:
        stream =
            FirebaseFirestore.instance
                .collection('orders')
                .where('deliveryManagerId', isEqualTo: widget.uid)
                .where('orderStatus', isEqualTo: status)
                .snapshots();
    }
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Text('주문이 없습니다');
        }
        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return Text('주문이 없습니다');
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _bodyScrollController,
          child: SizedBox(
            width: 1600,
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = MyOrder.fromDocument(
                  orders[index].data() as Map<String, dynamic>,
                );
                return _buildOrderRow(order);
              },
            ),
          ),
        );
      },
    );
  }

  void _scrollTo(int index) {
    itemScrollController.scrollTo(
      index: index,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  final Map<String, GlobalKey<FormState>> formKeys = {};

  Widget _buildOrderRow(MyOrder order) {
    final formKey = formKeys.putIfAbsent(
      order.orderId,
      () => GlobalKey<FormState>(),
    );

    return FutureBuilder(
      future: Future.wait([
        FirebaseFirestore.instance.collection('users').doc(order.userId).get(),
        FirebaseFirestore.instance
            .collection('products')
            .doc(order.productId)
            .get(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return Center(child: Text('사용자가 없습니다'));
        }

        final userSnapshot = snapshot.data![0] as DocumentSnapshot;
        final user = MyUser.fromDocument(
          userSnapshot.data() as Map<String, dynamic>,
        );

        final productSnapshot = snapshot.data![1] as DocumentSnapshot;
        final product = Product.fromMap(
          productSnapshot.data() as Map<String, dynamic>,
        );

        // Use or create controllers for this order
        final trackingNumberController = trackingControllers.putIfAbsent(
          order.orderId,
          () => TextEditingController(),
        );
        trackingNumberController.text =
            order.trackingNumber ?? trackingNumberController.text;
        final courierIdController = courierControllers.putIfAbsent(
          order.orderId,
          () => TextEditingController(),
        );
        courierIdController.text = order.carrierId ?? courierIdController.text;
        return Form(
          key: formKey,
          child: Table(
            border: TableBorder.all(color: Colors.black),
            columnWidths: columnWidths,
            children: [
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8,
                    ),
                    child: Text(
                      DateTime.parse(
                        order.orderDate,
                      ).toLocal().toString().split('.')[0],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Order ID Column
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8,
                    ),
                    child: Text(
                      order.orderId,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Recipient Column
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8,
                    ),
                    child: Text(
                      user.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8,
                    ),
                    child: Text(
                      order.phoneNo,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Address Column
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8,
                    ),
                    child: Text(
                      order.deliveryAddress,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8,
                    ),
                    child: Text(
                      order.deliveryAddressDetail,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  // Delivery Instructions Column
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8,
                    ),
                    child: Text(
                      order.deliveryInstructions,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Product Column
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8,
                    ),
                    child: Text(
                      product.productName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Quantity Column
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8,
                    ),
                    child: Text(
                      order.quantity.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8,
                    ),
                    child: Text(
                      "₩ ${order.totalPrice.toString()}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8,
                    ),
                    child: Text(
                      "₩ ${product.price.toString()}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8,
                    ),
                    child: Text(
                      "₩ ${product.deliveryPrice.toString()}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8,
                    ),
                    child: Text(
                      "₩ ${product.shippingFee.toString()}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  /*                 Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8,
                    ),
                    child: Text(
                      "₩ ${product.estimatedSettlement.toString()}",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ), */
                  // Courier Input Column
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8,
                    ),
                    child: TextFormField(
                      enabled:
                          (order.carrierId == '' &&
                              order.trackingNumber == '') &&
                          order.confirmed,
                      controller: courierIdController,
                      decoration: InputDecoration(
                        labelText: '택배사',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ),

                  // Tracking Number Input Column
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8,
                    ),
                    child: TextFormField(
                      enabled:
                          (order.carrierId == '' &&
                              order.trackingNumber == '') &&
                          order.confirmed,
                      controller: trackingNumberController,
                      decoration: InputDecoration(
                        labelText: '운송장 번호',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '운송장 번호를 입력하세요'; // "Please enter tracking number"
                        }
                        return null;
                      },
                    ),
                  ),

                  // Submit Button Column
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5.0,
                      vertical: 8,
                    ),
                    child: ElevatedButton(
                      onPressed:
                          order.confirmed &&
                                  (order.carrierId == '' &&
                                      order.trackingNumber == '')
                              ? () async {
                                if (!formKey.currentState!.validate()) return;
                                formKey.currentState!.save();
                                showLoadingDialog(context);

                                await registerTrackingManually(
                                  courierIdController.text,
                                  trackingNumberController.text,
                                  order,
                                );

                                Navigator.pop(context);
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            order.confirmed &&
                                    (order.carrierId == '' &&
                                        order.trackingNumber == '')
                                ? Colors.black
                                : Colors.white,
                        foregroundColor:
                            order.confirmed &&
                                    (order.carrierId == '' &&
                                        order.trackingNumber == '')
                                ? Colors.white
                                : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
                        ),
                        minimumSize: Size(110.w, 40),
                      ),
                      child: Text('제출', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5.0,
                      vertical: 8,
                    ),
                    child: ElevatedButton(
                      onPressed:
                          order.confirmed
                              ? null
                              : () async {
                                showLoadingDialog(context);
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('orders')
                                      .doc(order.orderId)
                                      .update({'confirmed': true});

                                  Navigator.pop(
                                    context,
                                  ); // close loading dialog

                                  //  Show success feedback
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '주문이 확인되었습니다',
                                      ), // "Order confirmed"
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  Navigator.pop(
                                    context,
                                  ); // close loading dialog

                                  //  Show error feedback
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('오류 발생: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
                        ),
                      ),
                      child: Text(
                        order.confirmed ? '확인됨' : '확인',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /*   Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Text(': '),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
 */
  /*   Widget _buildEditableInfoRow(
    String label,
    String value, {
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Text(': '),
          Expanded(child: Text(value)),
          IconButton(
            icon: const Text('변경', style: TextStyle(color: Colors.blue)),
            onPressed: onPressed,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  } */

  void _editCutoffTime(Map<String, dynamic> product) {
    final _formKey = GlobalKey<FormState>();

    int baselineTime = product['baselineTime'];
    String meridiem = product['meridiem'];

    // Actually show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('제품 수정'),
              content: Container(
                width: 600,
                child: Form(
                  key: _formKey,
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
                                        labelText: '기준 시간',
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return '기준 시간을 입력하세요';
                                        }
                                        return null;
                                      },
                                      onSaved: (value) {
                                        baselineTime = int.parse(value!);
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 8),
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
                  child: Text('취소'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: Text('저장'),
                  onPressed: () async {
                    // Validate and save form first
                    if (!_formKey.currentState!.validate()) return;
                    _formKey.currentState!.save();
                    try {
                      // Show loading dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder:
                            (context) => AlertDialog(
                              content: Row(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(width: 16),
                                  Text("기준 시간 업데이트 중..."),
                                ],
                              ),
                            ),
                      );

                      // Debug output
                      print(
                        "Updating product with ID: ${product['product_id']}",
                      );
                      print(
                        "New values - meridiem: $meridiem, baselineTime: $baselineTime",
                      );

                      final productRef = FirebaseFirestore.instance
                          .collection('products')
                          .doc(product['product_id']);

                      // Verify document exists
                      final doc = await productRef.get();
                      if (!doc.exists) {
                        throw Exception('제품 문서를 찾을 수 없습니다');
                      }

                      // Debug output
                      print("Document exists, current data: ${doc.data()}");

                      // Update in Firestore with explicit completion handling
                      await FirebaseFirestore.instance
                          .collection('products')
                          .doc(product['product_id'])
                          .update({
                            'meridiem': meridiem,
                            'baselineTime': baselineTime,
                          })
                          .then((_) {
                            print("Update completed successfully");
                          })
                          .catchError((error) {
                            print("Update failed with error: $error");
                            throw error; // Re-throw to be caught by the outer catch
                          });

                      // Close loading dialog
                      Navigator.of(context).pop();

                      // Close edit dialog
                      Navigator.of(context).pop();

                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('기준 시간이 성공적으로 업데이트됨'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } catch (e) {
                      print("Error in update process: ${e.toString()}");

                      // Close loading dialog if it's open
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      }

                      // Show detailed error message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('기준 시간 업데이트 실패: ${e.toString()}'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 5),
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
    final _formKey = GlobalKey<FormState>();

    // Actually show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Initialize stock inside the dialog
        int stock = product['stock'];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('제품 수정'),
              content: Container(
                width: 600,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: stock.toString(),
                                decoration: InputDecoration(labelText: '재고'),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '재고를 입력하세요';
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
                  child: Text('취소'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: Text('저장'),
                  onPressed: () async {
                    // Validate and save form first
                    if (!_formKey.currentState!.validate()) return;
                    _formKey.currentState!.save();

                    try {
                      // Show loading dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder:
                            (context) => AlertDialog(
                              content: Row(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(width: 16),
                                  Text("재고 업데이트 중..."),
                                ],
                              ),
                            ),
                      );

                      print(
                        "Updating product with ID: ${product['product_id']}",
                      );
                      print("New values - stock: $stock");

                      final productRef = FirebaseFirestore.instance
                          .collection('products')
                          .doc(product['product_id']);

                      // Update in Firestore
                      await productRef
                          .update({'stock': stock})
                          .then((_) {
                            print("Update completed successfully");
                          })
                          .catchError((error) {
                            print("Update failed with error: $error");
                            throw error;
                          });

                      // Close loading dialog
                      Navigator.of(context).pop();

                      // Close edit dialog
                      Navigator.of(context).pop();

                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('재고가 성공적으로 업데이트됨'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } catch (e) {
                      print("Error in update process: ${e.toString()}");

                      // Close loading dialog if it's open
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('재고 업데이트 실패: ${e.toString()}'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 5),
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
}
