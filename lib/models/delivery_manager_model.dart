class DeliveryManagerModel {
  final String uid;
  final String email;
  final String mailOrderNumber;
  final String repName;
  final String businessNumber;
  final String companyName;
  final String businessAddress;
  final String emailAddress;
  final String name;
  final String jobTitle;
  final String phoneNumber;
  final String accountNumber;
  final String brandName;

  DeliveryManagerModel({
    required this.uid,
    required this.email,
    required this.mailOrderNumber,
    required this.repName,
    required this.businessNumber,
    required this.companyName,
    required this.businessAddress,
    required this.emailAddress,
    required this.name,
    required this.jobTitle,
    required this.phoneNumber,
    required this.accountNumber,
    required this.brandName,
  });

  factory DeliveryManagerModel.fromMap(Map<String, dynamic> map) {
    return DeliveryManagerModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      mailOrderNumber: map['mailOrderNumber'] ?? '',
      repName: map['repName'] ?? '',
      businessNumber: map['businessNumber'] ?? '',
      companyName: map['companyName'] ?? '',
      businessAddress: map['businessAddress'] ?? '',
      emailAddress: map['emailAddress'] ?? '',
      name: map['name'] ?? '',
      jobTitle: map['jobTitle'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      brandName: map['brandName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'mailOrderNumber': mailOrderNumber,
      'repName': repName,
      'businessNumber': businessNumber,
      'companyName': companyName,
      'businessAddress': businessAddress,
      'emailAddress': emailAddress,
      'name': name,
      'jobTitle': jobTitle,
      'phoneNumber': phoneNumber,
      'accountNumber': accountNumber,
      'brandName': brandName,
    };
  }
}
