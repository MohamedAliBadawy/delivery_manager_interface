import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:delivery_manager_interface/core/localization.dart';
import 'package:delivery_manager_interface/models/order_model.dart';
import 'package:delivery_manager_interface/widgets/orders_management.dart';
import 'firebase_options.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseAuth.instance.tenantId = 'Sellers-rrml8';
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, _) {
        return MaterialApp(
          title: lang == 'en' ? 'Delivery Manager' : '판매자',
          theme: ThemeData(
            primaryColor: Colors.black,
            scaffoldBackgroundColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              secondary: Colors.black,
              onSecondary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Colors.black,
              selectionColor: Colors.grey,
              selectionHandleColor: Colors.black,
            ),
            focusColor: Colors.black,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
            ),
          ),
          home: user != null ? DeliveryManagerInterface() : const LoginScreen(),
        );
      },
    );
  }
}

class DeliveryManagerInterface extends StatefulWidget {
  final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  DeliveryManagerInterface({super.key});

  @override
  State<DeliveryManagerInterface> createState() =>
      _DeliveryManagerInterfaceState();
}

class _DeliveryManagerInterfaceState extends State<DeliveryManagerInterface> {
  late Stream<List<MyOrder>> _ordersStream;
  late Stream<int> _chatCountsStream;

  @override
  void initState() {
    super.initState();
    _ordersStream = _getOrdersStream();
    _chatCountsStream = _getChatCountsStream();
  }

  Stream<List<MyOrder>> _getOrdersStream() {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('deliveryManagerId', isEqualTo: widget.uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => MyOrder.fromDocument(doc.data()))
                  .toList(),
        );
  }

  Stream<int> _getChatCountsStream() {
    return FirebaseFirestore.instance
        .collection('chatRooms')
        .where('participants', arrayContains: widget.uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'ongoing';
        final deletedBy = data['deletedBy'] as List?;
        final isDeleted = deletedBy != null && deletedBy.contains(widget.uid);
        return status != 'completed' && !isDeleted;
      }).length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final realWidth = mediaQuery.size.width;
    final realHeight = mediaQuery.size.height;

    const targetMinWidth = 1400.0;
    const targetMinHeight = 900.0;

    final bool needsHorizontalScroll = realWidth < targetMinWidth;
    final bool needsVerticalScroll = realHeight < targetMinHeight;

    final double layoutWidth = needsHorizontalScroll ? targetMinWidth : realWidth;
    final double layoutHeight = needsVerticalScroll ? targetMinHeight : realHeight;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<List<MyOrder>>(
          stream: _ordersStream,
          builder: (context, ordersSnapshot) {
            if (ordersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (ordersSnapshot.hasError) {
              return Center(child: Text('Error: ${ordersSnapshot.error}'));
            }

            final orders = ordersSnapshot.data ?? [];

            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              physics: needsVerticalScroll ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: needsHorizontalScroll ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: layoutWidth,
                  height: layoutHeight,
                  child: OrdersManagementWidget(
                    orders: orders,
                    uid: widget.uid,
                    chatCountsStream: _chatCountsStream,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
