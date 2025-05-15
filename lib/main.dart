import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_manager_interface/models/order_model.dart';
import 'package:delivery_manager_interface/models/product_model.dart';
import 'package:delivery_manager_interface/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        title: '배달 담당자 인터페이스',
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
  const DeliveryManagerInterface({super.key});

  @override
  State<DeliveryManagerInterface> createState() =>
      _DeliveryManagerInterfaceState();
}

class _DeliveryManagerInterfaceState extends State<DeliveryManagerInterface> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${FirebaseAuth.instance.currentUser?.displayName} 님 환영합니다',
              style: TextStyle(
                fontSize: 40.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 24.h),
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  _buildTableHeader('제품', 2),
                  _buildTableHeader('수량', 1),
                  _buildTableHeader('주문 ID', 1),
                  _buildTableHeader('수취인', 1),
                  _buildTableHeader('주소', 3),
                  _buildTableHeader('배송 요청사항', 1),
                  _buildTableHeader('택배사', 1),
                  _buildTableHeader('운송장 번호', 1),
                  _buildTableHeader('', 1),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('orders')
                        .where(
                          'deliveryManagerId',
                          isEqualTo: FirebaseAuth.instance.currentUser?.uid,
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
                  return ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = MyOrder.fromDocument(
                        orders[index].data() as Map<String, dynamic>,
                      );
                      return _buildOrderRow(order);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String title, int flex) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
        child: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildOrderRow(MyOrder order) {
    Future<Map<String, dynamic>> _registerTrackingManually(
      String carrierId,
      String trackingNumber,
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

        final trackingNumberController = TextEditingController();
        final deliveryAddressController = TextEditingController();
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      product.imgUrl != null
                          ? Image.network(
                            product.imgUrl!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          )
                          : Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey.shade300,
                          ),
                      SizedBox(width: 16),
                      Flexible(child: Text(product.productName)),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8,
                  ),
                  child: Text(
                    order.quantity.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              ),

              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8,
                  ),
                  child: Text(
                    order.orderId,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8,
                  ),
                  child: Text(
                    user.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8,
                  ),
                  child: Text(
                    order.deliveryAddress,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8,
                  ),
                  child: Text(
                    order.deliveryInstructions,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8,
                  ),
                  child: TextField(
                    controller: deliveryAddressController,

                    decoration: InputDecoration(
                      labelText: '택배사',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8,
                  ),
                  child: TextField(
                    controller: trackingNumberController,
                    decoration: InputDecoration(
                      labelText: '운송장 번호',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5.0),
                  child: ElevatedButton(
                    onPressed: () async {
                      print("pressed");
                      print(
                        await _registerTrackingManually(
                          deliveryAddressController.text,
                          trackingNumberController.text,
                        ),
                      );
                    },

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                      fixedSize: Size.fromWidth(110.w),
                    ),
                    child: Text('제출'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
