import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_manager_interface/main.dart';
import 'package:delivery_manager_interface/core/localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delivery_manager_interface/models/delivery_manager_model.dart';
import 'package:delivery_manager_interface/models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isSignUpTab = false; // Toggle between Login and Sign Up
  bool _isLoading = false;
  String? _errorMessage;

  // Login Controllers
  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();

  // Sign Up Controllers
  final TextEditingController _mailOrderNumberController = TextEditingController();
  final TextEditingController _repNameController = TextEditingController();
  final TextEditingController _businessNumberController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _businessAddressController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _brandNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _agreeToTerms = false;
  final _signUpFormKey = GlobalKey<FormState>();
  final _loginFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _loginIdController.dispose();
    _loginPasswordController.dispose();
    _mailOrderNumberController.dispose();
    _repNameController.dispose();
    _businessNumberController.dispose();
    _companyNameController.dispose();
    _businessAddressController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _jobTitleController.dispose();
    _phoneNumberController.dispose();
    _accountNumberController.dispose();
    _brandNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final inputId = _loginIdController.text.trim();
      final password = _loginPasswordController.text.trim();

      String targetEmail = inputId;
      // Try treating input as business number first
      final query = await _firestore
          .collection('deliveryManagers')
          .where('businessNumber', isEqualTo: inputId)
          .get();
      if (query.docs.isNotEmpty) {
        targetEmail = query.docs.first.data()['email'] ?? inputId;
      } else {
        // If no match found, fallback to using input directly as email
        targetEmail = inputId;
      }

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: targetEmail,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Maintain consistency check in Firestore
      final dmDoc = await _firestore.collection('deliveryManagers').doc(uid).get();
      if (!dmDoc.exists) {
        await _auth.signOut();
        throw Exception(tr('pe_taxable') == '과세' ? '판매자 정보가 존재하지 않습니다. 관리자에게 문의하세요.' : 'Seller information not found. Please contact support.');
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DeliveryManagerInterface()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUp() async {
    if (!_signUpFormKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('pe_taxable') == '과세' ? '이용 약관에 동의하셔야 가입이 가능합니다.' : 'You must agree to the Terms of Service.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Create Authentication User
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      // Save user to deliveryManagers Firestore collection using model
      final manager = DeliveryManagerModel(
        uid: uid,
        email: email,
        mailOrderNumber: _mailOrderNumberController.text.trim(),
        repName: _repNameController.text.trim(),
        businessNumber: _businessNumberController.text.trim(),
        companyName: _companyNameController.text.trim(),
        businessAddress: _businessAddressController.text.trim(),
        emailAddress: email,
        name: _nameController.text.trim(),
        jobTitle: _jobTitleController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        brandName: _brandNameController.text.trim(),
      );
      await _firestore.collection('deliveryManagers').doc(uid).set(manager.toMap());

      // Save user to users Firestore collection to maintain consistency (for chats, etc.) using model
      final myUser = MyUser(
        userId: uid,
        email: email,
        name: _nameController.text.trim(),
        url: 'https://i.ibb.co/mrVrHy7z/avatar.png',
        phoneNumber: _phoneNumberController.text.trim(),
        bio: '',
        type: 'deliveryManager',
        lastSeen: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(myUser.toDocument());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('auth_signup_success'))),
      );

      // Switch to Login Tab and prefill Business Number
      setState(() {
        _isSignUpTab = false;
        _loginIdController.text = _businessNumberController.text.trim();
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            tr('auth_reset_password'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: emailController,
            decoration: InputDecoration(
              hintText: tr('email_label'),
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
                final email = emailController.text.trim();
                if (email.isEmpty) return;
                Navigator.pop(context);

                final sm = ScaffoldMessenger.of(context);
                try {
                  await _auth.sendPasswordResetEmail(email: email);
                  sm.showSnackBar(SnackBar(content: Text(tr('auth_reset_success'))));
                } catch (e) {
                  sm.showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text(tr('pe_taxable') == '과세' ? '보내기' : 'Send'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchTermsUrl() async {
    final url = Uri.parse('https://flowery-tub-f11.notion.site/26238af9230b809abec6fca9519854d3?pvs=74');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Widget _buildGuideBlock({required String title, required List<String> guidelines}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
            ),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: guidelines.map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  line,
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrutalistInput({
    required String label,
    required TextEditingController controller,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 32,
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
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Colors.black, width: 1),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
          child: SizedBox(
            width: 480,
            child: ValueListenableBuilder<String>(
              valueListenable: languageNotifier,
              builder: (context, lang, _) {
                return Column(
                  children: [
                    // Language Switcher Row
                    if (showLanguageSelector)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => languageNotifier.value = 'ko',
                            child: Text(
                              '한국어',
                              style: TextStyle(
                                color: lang == 'ko' ? Colors.black : Colors.grey,
                                fontWeight: lang == 'ko' ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          const Text('|', style: TextStyle(color: Colors.grey)),
                          TextButton(
                            onPressed: () => languageNotifier.value = 'en',
                            child: Text(
                              'English',
                              style: TextStyle(
                                color: lang == 'en' ? Colors.black : Colors.grey,
                                fontWeight: lang == 'en' ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (showLanguageSelector) const SizedBox(height: 16),

                    // Main Container Card
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Column(
                        children: [
                          // Tab headers (회원가입 / 로그인)
                          Row(
                            children: [
                              // 회원가입 Tab
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() {
                                    _isSignUpTab = true;
                                    _errorMessage = null;
                                  }),
                                  child: Container(
                                    height: 48,
                                    color: _isSignUpTab ? Colors.black : Colors.grey[300],
                                    alignment: Alignment.center,
                                    child: Text(
                                      tr('auth_signup'),
                                      style: TextStyle(
                                        color: _isSignUpTab ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(width: 1, height: 48, color: Colors.black),
                              // 로그인 Tab
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() {
                                    _isSignUpTab = false;
                                    _errorMessage = null;
                                  }),
                                  child: Container(
                                    height: 48,
                                    color: !_isSignUpTab ? Colors.black : Colors.grey[300],
                                    alignment: Alignment.center,
                                    child: Text(
                                      tr('auth_login'),
                                      style: TextStyle(
                                        color: !_isSignUpTab ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Container(height: 2, color: Colors.black),

                          // Form content area
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: _isSignUpTab
                                ? _buildSignUpForm()
                                : _buildLoginForm(),
                          ),
                        ],
                      ),
                    ),
                    
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 사업자번호 (Login ID)
          _buildBrutalistInput(
            label: tr('pe_taxable') == '과세' ? '사업자번호' : 'Business Number',
            controller: _loginIdController,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return tr('pe_required_field');
              }
              return null;
            },
          ),

          // 2. 비밀번호 (Password)
          _buildBrutalistInput(
            label: tr('pe_taxable') == '과세' ? '비밀번호' : 'Password',
            controller: _loginPasswordController,
            obscureText: true,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return tr('pe_required_field');
              }
              return null;
            },
          ),
          const SizedBox(height: 8),

          // Log In Button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      tr('auth_login'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Reset Password text link
          TextButton(
            onPressed: _resetPassword,
            child: Text(
              tr('auth_reset_password'),
              style: const TextStyle(
                color: Colors.black,
                decoration: TextDecoration.underline,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Form(
      key: _signUpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 제품 및 서비스 입점 안내 Guide Block
          _buildGuideBlock(
            title: tr('pe_guide_proposal_title'),
            guidelines: [
              tr('pe_guide_proposal_1'),
              tr('pe_guide_proposal_2'),
              tr('pe_guide_proposal_3'),
            ],
          ),

          // 2. 정산일 및 결제 수수료 안내 Guide Block
          _buildGuideBlock(
            title: tr('pe_guide_settlement_title'),
            guidelines: [
              tr('pe_guide_settlement_1'),
              tr('pe_guide_settlement_2'),
              tr('pe_guide_settlement_3'),
            ],
          ),

          // Inputs
          _buildBrutalistInput(
            label: tr('auth_mail_order_no'),
            controller: _mailOrderNumberController,
            validator: (val) => val!.trim().isEmpty ? tr('pe_required_field') : null,
          ),
          _buildBrutalistInput(
            label: tr('auth_rep_name'),
            controller: _repNameController,
            validator: (val) => val!.trim().isEmpty ? tr('pe_required_field') : null,
          ),
          _buildBrutalistInput(
            label: tr('pe_taxable') == '과세' ? '사업자 번호' : 'Business Registration No.',
            controller: _businessNumberController,
            validator: (val) => val!.trim().isEmpty ? tr('pe_required_field') : null,
          ),
          _buildBrutalistInput(
            label: tr('auth_company_name'),
            controller: _companyNameController,
            validator: (val) => val!.trim().isEmpty ? tr('pe_required_field') : null,
          ),
          _buildBrutalistInput(
            label: tr('auth_business_address'),
            controller: _businessAddressController,
            validator: (val) => val!.trim().isEmpty ? tr('pe_required_field') : null,
          ),
          _buildBrutalistInput(
            label: tr('email_label'),
            controller: _emailController,
            validator: (val) => val!.trim().isEmpty ? tr('pe_required_field') : null,
          ),

          // Manager Row: Manager Name & Position/Job Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildBrutalistInput(
                  label: tr('mi_manager_name'),
                  controller: _nameController,
                  validator: (val) => val!.trim().isEmpty ? tr('pe_required_field') : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBrutalistInput(
                  label: tr('auth_job_title'),
                  controller: _jobTitleController,
                  validator: (val) => val!.trim().isEmpty ? tr('pe_required_field') : null,
                ),
              ),
            ],
          ),

          _buildBrutalistInput(
            label: tr('mi_contact'),
            controller: _phoneNumberController,
            validator: (val) => val!.trim().isEmpty ? tr('pe_required_field') : null,
          ),
          _buildBrutalistInput(
            label: tr('mi_settlement_account'),
            controller: _accountNumberController,
            validator: (val) => val!.trim().isEmpty ? tr('pe_required_field') : null,
          ),
          _buildBrutalistInput(
            label: tr('auth_brand_name'),
            controller: _brandNameController,
            validator: (val) => val!.trim().isEmpty ? tr('pe_required_field') : null,
          ),
          _buildBrutalistInput(
            label: tr('password_label'),
            controller: _passwordController,
            obscureText: true,
            validator: (val) => val!.trim().isEmpty ? tr('pe_required_field') : null,
          ),

          // Terms agreement Row
          Row(
            children: [
              Checkbox(
                value: _agreeToTerms,
                activeColor: Colors.black,
                onChanged: (val) => setState(() => _agreeToTerms = val ?? false),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      const TextSpan(text: '판매자 센터 가입 '),
                      TextSpan(
                        text: '이용 약관',
                        style: const TextStyle(decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()..onTap = _launchTermsUrl,
                      ),
                      const TextSpan(text: '을 읽었으며 해당내용에 동의합니다'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Sign Up Button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: _isLoading ? null : _signUp,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      tr('auth_signup'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
