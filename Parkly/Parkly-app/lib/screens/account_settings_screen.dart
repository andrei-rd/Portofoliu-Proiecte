import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'package:parkly/services/language_service.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen>
    with WidgetsBindingObserver {
  final _auth = AuthService();
  final _db = DatabaseService();
  final _lang = LanguageService();
  User? _user;
  final _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _surnameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  File? _imageFile;
  String? _photoUrl;

  String _selectedCountryCode = '+40';
  final List<Map<String, String>> _europeanCountries = [
    {'name': 'România', 'code': '+40', 'flag': '🇷🇴'},
    {'name': 'Germania', 'code': '+49', 'flag': '🇩🇪'},
    {'name': 'Franța', 'code': '+33', 'flag': '🇫🇷'},
    {'name': 'Italia', 'code': '+39', 'flag': '🇮🇹'},
    {'name': 'Spania', 'code': '+34', 'flag': '🇪🇸'},
    {'name': 'Marea Britanie', 'code': '+44', 'flag': '🇬🇧'},
    {'name': 'Olanda', 'code': '+31', 'flag': '🇳🇱'},
    {'name': 'Austria', 'code': '+43', 'flag': '🇦🇹'},
    {'name': 'Belgia', 'code': '+32', 'flag': '🇧🇪'},
    {'name': 'Grecia', 'code': '+30', 'flag': '🇬🇷'},
    {'name': 'Ungaria', 'code': '+36', 'flag': '🇭🇺'},
    {'name': 'Polonia', 'code': '+48', 'flag': '🇵🇱'},
    {'name': 'Portugalia', 'code': '+351', 'flag': '🇵🇹'},
    {'name': 'Cehia', 'code': '+420', 'flag': '🇨🇿'},
    {'name': 'Suedia', 'code': '+46', 'flag': '🇸🇪'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nameController = TextEditingController();
    _surnameController = TextEditingController();
    _emailController = TextEditingController(text: _user?.email ?? '');
    _phoneController = TextEditingController();
    _loadUserData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh user data when returning to the app (e.g., from email app)
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    await FirebaseAuth.instance.currentUser?.reload();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists) {
      final data = doc.data()!;

      if (mounted) {
        setState(() {
          _user = user;
          _emailController.text = user.email ?? '';
          final displayName = data['displayName'] ?? '';
          final names = displayName.split(' ');
          _nameController.text = names.isNotEmpty ? names[0] : '';
          _surnameController.text =
              names.length > 1 ? names.sublist(1).join(' ') : '';
          
          String fullPhone = data['phoneNumber'] ?? '';
          if (fullPhone.startsWith('+')) {
            // Sort countries by code length descending to match longest prefix first (e.g. +351 before +35)
            var sortedCountries = List<Map<String, String>>.from(_europeanCountries);
            sortedCountries.sort((a, b) => b['code']!.length.compareTo(a['code']!.length));
            
            bool found = false;
            for (var country in sortedCountries) {
              if (fullPhone.startsWith(country['code']!)) {
                _selectedCountryCode = country['code']!;
                _phoneController.text = fullPhone.substring(country['code']!.length);
                found = true;
                break;
              }
            }
            if (!found) {
              _phoneController.text = fullPhone;
            }
          } else {
            _phoneController.text = fullPhone;
          }

          _photoUrl = data['photoURL'];
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    final user = _user;
    if (pickedFile != null && mounted && user != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _isLoading = true;
      });
      try {
        final url = await _db.uploadProfileImage(user.uid, _imageFile!);
        setState(() {
          _photoUrl = url;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_lang.translate('profile_pic_updated'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_lang.translate('upload_error')} $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteImage() async {
    setState(() {
      _imageFile = null;
      _photoUrl = null;
    });
    final user = _user;
    if (user != null) {
      await _db.updateUserProfile(user.uid, {'photoURL': null});
    }
  }

  Future<void> _sendEmailVerification() async {
    try {
      await _auth.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Email-ul de verificare a fost trimis!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    final user = _user;
    if (_formKey.currentState!.validate() && user != null) {
      setState(() => _isLoading = true);
      try {
        final fullName =
            "${_nameController.text} ${_surnameController.text}".trim();
        
        final String phoneBody = _phoneController.text.trim();
        final String sanitizedPhone = phoneBody.startsWith('0') ? phoneBody.substring(1) : phoneBody;
        final String fullPhoneNumber = "$_selectedCountryCode$sanitizedPhone";
        
        await _db.updateUserProfile(user.uid, {
          'displayName': fullName,
          'phoneNumber': fullPhoneNumber,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_lang.translate('profile_updated'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_lang.translate('error')}: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changePassword() async {
    if (_passwordFormKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await _auth.reauthenticate(_currentPasswordController.text);
        await _auth.updatePassword(_newPasswordController.text);
        if (mounted) {
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_lang.translate('password_changed'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_lang.translate('error_password')} $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _confirmDeactivate() {
    final user = _user;
    if (user == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_lang.translate('deactivate_title')),
        content: Text(_lang.translate('deactivate_desc')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_lang.translate('cancel'))),
          ElevatedButton(
            onPressed: () async {
              await _db.deactivateAccount(user.uid);
              await _auth.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(_lang.translate('deactivate_account'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    final user = _user;
    if (user == null) return;
    final passwordController = TextEditingController();
    bool isButtonEnabled = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_lang.translate('delete_title'),
              style: const TextStyle(color: Colors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_lang.translate('delete_desc')),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _lang.translate('current_password'),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (val) {
                  setDialogState(() => isButtonEnabled = val.isNotEmpty);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_lang.translate('cancel'))),
            ElevatedButton(
              onPressed: isButtonEnabled
                  ? () async {
                      try {
                        await _auth.reauthenticate(passwordController.text);
                        await _db.deleteUserData(user.uid);
                        await _auth.deleteAccount();
                        if (context.mounted) {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    '${_lang.translate('error_password')} $e')),
                          );
                        }
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(_lang.translate('delete').toUpperCase(),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: _lang,
        builder: (context, child) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FB),
            appBar: AppBar(
              title: Text(_lang.translate('account_security'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              centerTitle: false,
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Avatar Section
                        _buildSectionTitle(_lang.translate('profile_pic')),
                        const SizedBox(height: 16),
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: _imageFile != null
                                    ? FileImage(_imageFile!)
                                    : (_photoUrl != null
                                        ? NetworkImage(_photoUrl!)
                                        : null) as ImageProvider?,
                                child: (_imageFile == null && _photoUrl == null)
                                    ? const Icon(Icons.person,
                                        size: 50, color: Colors.grey)
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton.icon(
                                    onPressed: _pickImage,
                                    icon: const Icon(Icons.upload, size: 18),
                                    label: Text(_lang.translate('upload')),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: _deleteImage,
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: Colors.red),
                                    label: Text(_lang.translate('delete'),
                                        style:
                                            const TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // 2. Personal Details Form
                        _buildSectionTitle(_lang.translate('personal_details')),
                        const SizedBox(height: 16),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTextField(
                                  _nameController,
                                  _lang.translate('name'),
                                  Icons.person_outline),
                              const SizedBox(height: 16),
                              _buildTextField(
                                  _surnameController,
                                  _lang.translate('surname'),
                                  Icons.person_outline),

                              const SizedBox(height: 32),

                              // 3. Contact Details (Moved inside Form for validation)
                              _buildSectionTitle(_lang.translate('contact_details')),
                              const SizedBox(height: 16),
                              _buildTextField(
                                _emailController,
                                _lang.translate('email'),
                                Icons.email_outlined,
                                enabled: false,
                                suffix: (_user?.emailVerified ?? false)
                                    ? const Padding(
                                        padding: EdgeInsets.only(right: 12),
                                        child: Icon(Icons.check_circle,
                                            color: Colors.green, size: 20),
                                      )
                                    : null,
                              ),
                              if (!(_user?.emailVerified ?? false))
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: InkWell(
                                    onTap: _isLoading
                                        ? null
                                        : _sendEmailVerification,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.orange
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.mark_email_unread_outlined,
                                              color: Colors.orange,
                                              size: 18),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Verifică adresa de email acum',
                                            style: TextStyle(
                                                color: Color(0xFF7C2D12),
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              _buildPhoneField(),

                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _saveProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: Text(_lang.translate('save_changes'),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 48),

                        // 4. Password Section
                        _buildSectionTitle(_lang.translate('change_password')),
                        const SizedBox(height: 16),
                        Form(
                          key: _passwordFormKey,
                          child: Column(
                            children: [
                              _buildPasswordField(
                                  _currentPasswordController,
                                  _lang.translate('current_password'),
                                  _obscureCurrent,
                                  () => setState(() =>
                                      _obscureCurrent = !_obscureCurrent)),
                              const SizedBox(height: 16),
                              _buildPasswordField(
                                  _newPasswordController,
                                  _lang.translate('new_password'),
                                  _obscureNew,
                                  () => setState(
                                      () => _obscureNew = !_obscureNew)),
                              const SizedBox(height: 16),
                              _buildPasswordField(
                                  _confirmPasswordController,
                                  _lang.translate('confirm_new_password'),
                                  _obscureConfirm,
                                  () => setState(
                                      () => _obscureConfirm = !_obscureConfirm),
                                  isConfirm: true),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OutlinedButton(
                                  onPressed: _changePassword,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: Color(0xFF2563EB), width: 1.5),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: Text(
                                      _lang.translate('update_password_btn'),
                                      style: const TextStyle(
                                          color: Color(0xFF2563EB),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 60),

                        // Account Management
                        const Divider(),
                        const SizedBox(height: 16),
                        _buildSimpleTile(_lang.translate('deactivate_account'),
                            Icons.pause_circle_outline, _confirmDeactivate,
                            color: Colors.orange),
                        _buildSimpleTile(_lang.translate('delete_account_perm'),
                            Icons.delete_forever_outlined, _confirmDelete,
                            color: Colors.red),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          );
        });
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B)));
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_lang.translate('phone_number'),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCountryCode,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                  items: _europeanCountries.map((c) {
                    return DropdownMenuItem<String>(
                      value: c['code'],
                      child: Text("${c['flag']} ${c['code']}",
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCountryCode = val);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                decoration: InputDecoration(
                  hintText: "7xx xxx xxx",
                  prefixIcon: const Icon(Icons.phone_outlined,
                      color: Color(0xFF2563EB), size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty)
                    return _lang.translate('required_field');
                  if (val.length != 9)
                    return "Numărul trebuie să aibă fix 9 cifre";
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool enabled = true, Widget? suffix}) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2563EB), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
      validator: (val) =>
          val == null || val.isEmpty ? _lang.translate('required_field') : null,
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String label,
      bool obscure, VoidCallback onToggle,
      {bool isConfirm = false}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            const Icon(Icons.lock_outline, color: Color(0xFF2563EB), size: 20),
        suffixIcon: IconButton(
          icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
      validator: (val) {
        if (val == null || val.isEmpty)
          return _lang.translate('required_field');
        if (isConfirm && val != _newPasswordController.text)
          return _lang.translate('passwords_dont_match');
        return null;
      },
    );
  }

  Widget _buildSimpleTile(String label, IconData icon, VoidCallback onTap,
      {required Color color}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color, size: 22),
      title: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w500, fontSize: 15)),
      trailing: Icon(Icons.chevron_right,
          size: 20, color: color.withValues(alpha: 0.5)),
      contentPadding: EdgeInsets.zero,
    );
  }
}
