import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MyUser {
  String userId;

  String email;

  String name;

  String url;
  List? blocked = [];

  Timestamp? createdAt;

  bool isSub;

  MyUser({
    required this.userId,
    required this.email,
    required this.name,
    required this.url,
    this.blocked,
    this.createdAt,
    required this.isSub,
  });

  Map<String, Object?> toDocument() {
    return {
      'userId': userId,
      'email': email,
      'name': name,
      'url': url,
      'blocked': blocked,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'isSub': isSub,
    };
  }

  static MyUser fromDocument(Map<String, dynamic> doc) {
    return MyUser(
      userId: doc['userId'],
      email: doc['email'],
      name: doc['name'],
      url: doc['url'],
      blocked: doc['blocked'] ?? [],
      createdAt: doc['createdAt'],
      isSub: doc['isSub'],
    );
  }

  String get formattedCreatedAt {
    if (createdAt == null) return 'Not available';

    final dateTime = createdAt!.toDate();
    final formatter = DateFormat(
      'MM/dd/yyyy, hh:mm a',
    ); // Customize format as needed
    return formatter.format(dateTime);
  }
}
