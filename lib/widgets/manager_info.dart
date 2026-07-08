import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:delivery_manager_interface/core/localization.dart';
import 'package:delivery_manager_interface/models/delivery_manager_model.dart';

Widget buildManagerInfo(String uid) {
  return ManagerInfoWidget(uid: uid);
}

class ManagerInfoWidget extends StatefulWidget {
  final String uid;

  const ManagerInfoWidget({super.key, required this.uid});

  @override
  State<ManagerInfoWidget> createState() => _ManagerInfoWidgetState();
}

class _ManagerInfoWidgetState extends State<ManagerInfoWidget> {
  late Future<DocumentSnapshot> _managerFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _managerFuture = FirebaseFirestore.instance
          .collection('deliveryManagers')
          .doc(widget.uid)
          .get()
          .then((doc) async {
            if (!doc.exists) {
              // Fallback query by userId
              final query = await FirebaseFirestore.instance
                  .collection('deliveryManagers')
                  .where('userId', isEqualTo: widget.uid)
                  .get();
              if (query.docs.isNotEmpty) {
                return query.docs.first;
              }
            }
            return doc;
          });
    });
  }

  Future<void> _updateField(String docId, String fieldKey, String newValue) async {
    final sm = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('deliveryManagers')
          .doc(docId)
          .update({fieldKey: newValue});

      sm.showSnackBar(
        SnackBar(content: Text(tr('mi_save_success'))),
      );
      _refreshData();
    } catch (e) {
      sm.showSnackBar(
        SnackBar(
          content: Text(tr('mi_save_fail').replaceAll('{error}', e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditDialog(String docId, String title, String fieldKey, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            '$title ${tr('mi_change')}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.zero),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('cancel'), style: const TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: () {
                final val = controller.text.trim();
                Navigator.pop(context);
                _updateField(docId, fieldKey, val);
              },
              child: Text(tr('pe_taxable') == '과세' ? '적용' : 'Apply'),
            ),
          ],
        );
      },
    );
  }

  void _showPasswordDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            tr('mi_change_password'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(
              hintText: tr('mi_new_password'),
              border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('cancel'), style: const TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: () async {
                final newPassword = controller.text.trim();
                if (newPassword.isEmpty) return;
                Navigator.pop(context);

                final sm = ScaffoldMessenger.of(context);
                try {
                  await FirebaseAuth.instance.currentUser?.updatePassword(newPassword);
                  sm.showSnackBar(
                    SnackBar(content: Text(tr('mi_password_change_success'))),
                  );
                } catch (e) {
                  sm.showSnackBar(
                    SnackBar(
                      content: Text(tr('mi_save_fail').replaceAll('{error}', e.toString())),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(tr('pe_taxable') == '과세' ? '적용' : 'Apply'),
            ),
          ],
        );
      },
    );
  }

  void _showEmailChangeDialog(String docId, String currentEmail) {
    final controller = TextEditingController(text: currentEmail);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            '${tr('mi_email')} ${tr('mi_change')}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.zero),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('cancel'), style: const TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: () async {
                final newEmail = controller.text.trim();
                if (newEmail.isEmpty) return;
                Navigator.pop(context);

                final sm = ScaffoldMessenger.of(context);
                try {
                  // Update only the contact emailAddress in Firestore
                  await FirebaseFirestore.instance
                      .collection('deliveryManagers')
                      .doc(docId)
                      .update({
                        'emailAddress': newEmail,
                      });

                  sm.showSnackBar(
                    SnackBar(content: Text(tr('mi_save_success'))),
                  );
                  _refreshData();
                } catch (e) {
                  sm.showSnackBar(
                    SnackBar(
                      content: Text(tr('mi_save_fail').replaceAll('{error}', e.toString())),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(tr('pe_taxable') == '과세' ? '적용' : 'Apply'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBrutalistField({
    required String title,
    required String value,
    required bool hasChangeButton,
    required VoidCallback? onChange,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title block
        Container(
          width: 360,
          height: 36,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.black, width: 1),
              left: BorderSide(color: Colors.black, width: 1),
              right: BorderSide(color: Colors.black, width: 1),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        // Value/Button Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 360,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: value.startsWith('***')
                  ? Text(
                      value,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        color: Colors.blueGrey,
                      ),
                    )
                  : Text(
                      value,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
            ),
            if (hasChangeButton) ...[
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onChange,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  fixedSize: const Size(132, 48),
                ),
                child: Text(
                  tr('mi_change'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _managerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.black));
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          // If no delivery manager document found in DB, let's allow editing default local values
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(tr('pe_taxable') == '과세' ? '관리자 정보를 찾을 수 없습니다' : 'Manager info not found.'),
          );
        }

        final doc = snapshot.data!;
        final manager = DeliveryManagerModel.fromMap(doc.data() as Map<String, dynamic>);
        final docId = doc.id;

        final brandName = manager.brandName;
        final repName = manager.name;
        final repContact = manager.phoneNumber;
        final idEmail = manager.email;
        final settlementAcc = manager.accountNumber;
        final bizNumber = manager.businessNumber;
        final compName = manager.companyName;
        final emailAddress = manager.emailAddress.isEmpty ? idEmail : manager.emailAddress;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('mi_title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // 1. 브랜드명
              _buildBrutalistField(
                title: tr('mi_brand_name'),
                value: brandName,
                hasChangeButton: true,
                onChange: () => _showEditDialog(docId, tr('mi_brand_name'), 'brandName', brandName),
              ),

              // 2. 담당자명
              _buildBrutalistField(
                title: tr('mi_manager_name'),
                value: repName,
                hasChangeButton: true,
                onChange: () => _showEditDialog(docId, tr('mi_manager_name'), 'name', repName),
              ),

              // 3. 담당자 연락처
              _buildBrutalistField(
                title: tr('mi_contact'),
                value: repContact,
                hasChangeButton: true,
                onChange: () => _showEditDialog(docId, tr('mi_contact'), 'phoneNumber', repContact),
              ),

              // 4. 아이디(이메일) - Read-only
              _buildBrutalistField(
                title: tr('mi_id_email'),
                value: idEmail,
                hasChangeButton: false,
                onChange: null,
              ),

              // 5. 비밀번호
              _buildBrutalistField(
                title: tr('mi_password'),
                value: '******',
                hasChangeButton: true,
                onChange: _showPasswordDialog,
              ),

              // 6. 정산계좌
              _buildBrutalistField(
                title: tr('mi_settlement_account'),
                value: settlementAcc,
                hasChangeButton: true,
                onChange: () => _showEditDialog(docId, tr('mi_settlement_account'), 'accountNumber', settlementAcc),
              ),

              // 7. 사업자 번호 - Read-only
              _buildBrutalistField(
                title: tr('mi_business_number'),
                value: bizNumber,
                hasChangeButton: false,
                onChange: null,
              ),

              // 8. 상호 - Read-only
              _buildBrutalistField(
                title: tr('mi_company_name'),
                value: compName,
                hasChangeButton: false,
                onChange: null,
              ),

              // 9. 이메일
              _buildBrutalistField(
                title: tr('mi_email'),
                value: emailAddress,
                hasChangeButton: true,
                onChange: () => _showEmailChangeDialog(docId, emailAddress),
              ),
            ],
          ),
        );
      },
    );
  }
}
