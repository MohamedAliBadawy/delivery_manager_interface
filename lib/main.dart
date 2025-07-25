import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_manager_interface/models/order_model.dart';
import 'package:delivery_manager_interface/models/product_model.dart';
import 'package:delivery_manager_interface/models/user_model.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
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
    return ScreenUtilInit(
      designSize: const Size(1512, 982),
      child: MaterialApp(
        title: '판매자',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.white,
        ),
        home: LoginScreen(),
      ),
    );
  }
}

class DeliveryManagerInterface extends StatefulWidget {
  const DeliveryManagerInterface({super.key, required this.phoneNumber});

  final String phoneNumber;

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

  Widget _buildManagerInfo() {
    return FutureBuilder(
      future:
          FirebaseFirestore.instance
              .collection('deliveryManagers')
              .where('phone', isEqualTo: widget.phoneNumber)
              .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Manager information not found'),
          );
        }

        final manager = snapshot.data!.docs.first.data();
        return Column(
          children: [
            Text(
              'Manage Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,

                border: TableBorder.all(width: 2.0, color: Colors.black),
                children: [
                  TableRow(
                    children: [
                      Center(child: Text('Name')),
                      Center(child: Text(manager['name'] ?? 'N/A')),
                    ],
                  ),
                  TableRow(
                    children: [
                      Center(child: Text('Phone number')),
                      Center(child: Text(manager['phone'] ?? 'N/A')),
                    ],
                  ),
                  TableRow(
                    children: [
                      Center(child: Text('Email')),
                      Center(child: Text(manager['email'] ?? 'N/A')),
                    ],
                  ),
                  TableRow(
                    children: [
                      Center(child: Text('Banking information')),
                      Center(child: Text(manager['bankInfo'] ?? 'N/A')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductsInfo() {
    return StreamBuilder(
      stream:
          FirebaseFirestore.instance
              .collection('products')
              .where('deliveryManagerId', isEqualTo: widget.phoneNumber)
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
            child: Text('No products found'),
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
                                'Contract Information',
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
                                      const Center(child: Text('Product Name')),
                                      Center(
                                        child: Text(
                                          product['productName'] ?? 'N/A',
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      const Center(child: Text('Supply price')),
                                      Center(
                                        child: Text(
                                          '₩${product['price']?.toString() ?? 'N/A'}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      const Center(
                                        child: Text('Delivery price'),
                                      ),
                                      Center(
                                        child: Text(
                                          '₩ ${product['deliveryPrice']?.toString() ?? 'N/A'}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      const Center(
                                        child: Text(
                                          'Additional shipping fee for remote',
                                        ),
                                      ),
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
                                'Order cut-off time/ Stock Management',
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
                                      const Center(
                                        child: Text('Order cut-off time'),
                                      ),
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
                                      const Center(
                                        child: Text('Current stock'),
                                      ),
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
            .where('deliveryManagerId', isEqualTo: widget.phoneNumber)
            .get();

    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    // Header row
    sheet.appendRow([
      TextCellValue('주문 ID'),
      TextCellValue('수취인'),
      TextCellValue('Phone'),
      TextCellValue('주소'),
      TextCellValue('배송 요청사항'),
      TextCellValue('제품'),
      TextCellValue('수량'),
      TextCellValue('Supply price'),
      TextCellValue('Delivery price'),
      TextCellValue('Shipping fee'),
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
        TextCellValue(order.orderId),
        TextCellValue(user?.name ?? ''),
        TextCellValue(order.phoneNo),
        TextCellValue(order.deliveryAddress),
        TextCellValue(order.deliveryInstructions),
        TextCellValue(product?.productName ?? ''),
        TextCellValue(order.quantity.toString()),
        TextCellValue(product?.supplyPrice?.toString() ?? ''),
        TextCellValue(product?.deliveryPrice?.toString() ?? ''),
        TextCellValue(product?.shippingFee?.toString() ?? ''),
        TextCellValue(order.courier),
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
      final trackingNumber = row[11]?.value?.toString();
      final courierId = row[10]?.value?.toString();

      if (orderId != null) {
        if (trackingNumber != null) {
          trackingControllers[orderId]?.text = trackingNumber;
        }
        if (courierId != null) {
          courierControllers[orderId]?.text = courierId;
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tracking numbers loaded into fields!')),
    );
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
        return {'success': true};
      } else {
        final errorMessage =
            responseData['errors'] != null
                ? responseData['errors'][0]['message']
                : 'Failed to register tracking webhook';
        return {'success': false, 'error': errorMessage};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  final Map<int, TableColumnWidth> _columnWidths = {
    0: FlexColumnWidth(1), // Order ID
    1: FlexColumnWidth(1), // Recipient
    2: FlexColumnWidth(1), // Phone
    3: FlexColumnWidth(1), // Address
    4: FlexColumnWidth(1), // Delivery Note
    5: FlexColumnWidth(1), // Product
    6: FlexColumnWidth(1), // Quantity
    7: FlexColumnWidth(1), // Supply price
    8: FlexColumnWidth(1), // Delivery price
    9: FlexColumnWidth(1), // Shipping fee
    /*     10: FlexColumnWidth(1), // Estimated settlement
 */
    10: FlexColumnWidth(1), // Courier
    11: FlexColumnWidth(1), // Tracking Number
    12: FlexColumnWidth(1.5), // Submit Button (wider)
  };
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
                            _buildManagerInfo(),
                            SizedBox(height: 20),
                            // Products Information
                            _buildProductsInfo(),
                          ],
                        )
                        : Row(
                          children: [
                            Flexible(flex: 1, child: _buildManagerInfo()),
                            Flexible(flex: 3, child: _buildProductsInfo()),
                          ],
                        ),
              ),
              SizedBox(height: 24.h),
              Row(
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
                    child: Text('Download Orders as Excel'),
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
                    child: Text(
                      'Upload Courier id and Tracking numbers from excel',
                    ),
                  ),
                ],
              ),
              SizedBox(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _headerScrollController,
                  child: Container(
                    width: 1600,

                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Table(
                      border: TableBorder.all(color: Colors.black),
                      columnWidths: _columnWidths,
                      children: [
                        TableRow(
                          children: [
                            _buildTableHeader('주문 ID'),
                            _buildTableHeader('수취인'),
                            _buildTableHeader('Phone'),
                            _buildTableHeader('주소'),
                            _buildTableHeader('배송 요청사항'),
                            _buildTableHeader('제품'),
                            _buildTableHeader('수량'),
                            _buildTableHeader('Supply price'),
                            _buildTableHeader('Delivery price'),
                            _buildTableHeader('Shipping fee'),
                            /*  _buildTableHeader('Estimated settlement'), */
                            _buildTableHeader('택배사'),
                            _buildTableHeader('운송장 번호'),
                            _buildTableHeader(''),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(
                height: 400, // adjust as needed for table body

                child: StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('orders')
                          .where(
                            'deliveryManagerId',
                            isEqualTo: widget.phoneNumber,
                          )
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    // 3. Check for null data
                    if (!snapshot.hasData || snapshot.data == null) {
                      return Center(child: Text('주문이 없습니다'));
                    }
                    final orders = snapshot.data!.docs;

                    if (orders.isEmpty) {
                      return Center(child: Text('주문이 없습니다'));
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollTo(int index) {
    itemScrollController.scrollTo(
      index: index,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildOrderRow(MyOrder order) {
    return FutureBuilder(
      future: Future.wait([
        FirebaseFirestore.instance.collection('users').doc(order.userId).get(),
        FirebaseFirestore.instance
            .collection('products')
            .doc(order.productId)
            .get(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
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
        final courierIdController = courierControllers.putIfAbsent(
          order.orderId,
          () => TextEditingController(),
        );

        return Table(
          border: TableBorder.all(color: Colors.black),
          columnWidths: _columnWidths,
          children: [
            TableRow(
              children: [
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                  child: TextField(
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
                  child: TextField(
                    controller: trackingNumberController,
                    decoration: InputDecoration(
                      labelText: '운송장 번호',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                ),

                // Submit Button Column
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5.0,
                    vertical: 8,
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      print(
                        await registerTrackingManually(
                          courierIdController.text,
                          trackingNumberController.text,
                          order,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                      minimumSize: Size(110.w, 40),
                    ),
                    child: Text('제출', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
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

  Widget _buildEditableInfoRow(
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
            icon: const Text('Change', style: TextStyle(color: Colors.blue)),
            onPressed: onPressed,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

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
              title: Text('Edit Product'),
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
                                  Text("Updating cutoff time..."),
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
                        throw Exception('Product document not found');
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
                          content: Text('Cutoff time updated successfully'),
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
                          content: Text(
                            'Failed to update cutoff time: ${e.toString()}',
                          ),
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
              title: Text('Edit Product'),
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
                                  Text("Updating stock..."),
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
                          content: Text('Stock updated successfully'),
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
                          content: Text(
                            'Failed to update stock: ${e.toString()}',
                          ),
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
