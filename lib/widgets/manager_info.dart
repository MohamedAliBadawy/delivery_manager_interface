import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

Widget buildManagerInfo(String uid) {
  return FutureBuilder(
    future:
        FirebaseFirestore.instance
            .collection('deliveryManagers')
            .where('userId', isEqualTo: uid)
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
          child: Text('관리자 정보를 찾을 수 없습니다'),
        );
      }

      final manager = snapshot.data!.docs.first.data();
      return Column(
        children: [
          Text(
            '관리자 정보',
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
                    Center(child: Text('이름')),
                    Center(child: Text(manager['name'] ?? 'N/A')),
                  ],
                ),
                TableRow(
                  children: [
                    Center(child: Text('전화번호')),
                    Center(child: Text(manager['phone'] ?? 'N/A')),
                  ],
                ),
                TableRow(
                  children: [
                    Center(child: Text('이메일')),
                    Center(child: Text(manager['email'] ?? 'N/A')),
                  ],
                ),
                TableRow(
                  children: [
                    Center(child: Text('은행 정보')),
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
