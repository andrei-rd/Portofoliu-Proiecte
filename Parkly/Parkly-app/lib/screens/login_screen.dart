import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/legal_texts.dart';
import 'markdown_view_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool isLogin = true;
  bool _obscurePassword = true;
  bool _acceptTerms = false;
  String error = '';
  bool loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30),

                // --- LOGO SECTION ---
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              blurRadius: 15,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'lib/assets/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Parkly",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // --- HEADER ---
                Text(
                  isLogin ? "Bun venit înapoi!" : "Creează un cont",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLogin
                      ? "Introdu datele pentru a accesa contul."
                      : "Completează formularul pentru a începe.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 25),

                // --- INPUT FIELDS ---
                if (!isLogin) ...[
                  _buildLabel("Nume complet"),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _nameController,
                    hint: "ex: Andrei Ionescu",
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 15),
                ],

                _buildLabel("Email"),
                const SizedBox(height: 6),
                _buildTextField(
                  key: const ValueKey('email_field'),
                  controller: _emailController,
                  hint: "adresa@email.com",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 15),

                _buildLabel("Parolă"),
                const SizedBox(height: 6),
                _buildTextField(
                  key: const ValueKey('password_field'),
                  controller: _passwordController,
                  hint: "••••••••",
                  icon: Icons.lock_outline_rounded,
                  isPassword: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),

                if (isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextButton(
                        onPressed: () async {
                          if (_emailController.text.isEmpty) {
                            setState(
                                () => error = 'Introdu email-ul mai întâi');
                            return;
                          }
                          setState(() => loading = true);
                          try {
                            await _auth.sendPasswordResetEmail(_emailController.text);
                            if (mounted) {
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Email de resetare trimis!')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => error = e.toString());
                            }
                          }
                          if (mounted) setState(() => loading = false);
                        },
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: const Text(
                          "Ai uitat parola?",
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                if (!isLogin) ...[
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _acceptTerms,
                          activeColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (val) =>
                              setState(() => _acceptTerms = val ?? false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MarkdownViewScreen(
                                  title: 'Termeni și Condiții',
                                  markdownData: LegalTexts.termsConditions,
                                ),
                              ),
                            );
                          },
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                              children: [
                                const TextSpan(text: "Accept "),
                                TextSpan(
                                  text: "Termenii și Condițiile",
                                  style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const TextSpan(text: " Parkly"),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // --- PRIMARY BUTTON ---
                loading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF2563EB)))
                    : Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: isLogin || _acceptTerms
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF2563EB),
                                    Color(0xFF1D4ED8)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [
                                    Colors.grey.shade400,
                                    Colors.grey.shade500
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!isLogin && !_acceptTerms) {
                              setState(() => error =
                                  'Trebuie să accepți termenii pentru a continua');
                              return;
                            }
                            if (_formKey.currentState!.validate()) {
                              setState(() {
                                loading = true;
                                error = '';
                              });
                              try {
                                if (isLogin) {
                                  await _auth.signInWithEmailPassword(
                                      _emailController.text, _passwordController.text);
                                } else {
                                  await _auth.registerWithEmailPassword(
                                      _emailController.text, _passwordController.text, _nameController.text);
                                }
                              } catch (e) {
                                setState(() => error = e.toString());
                              }
                              if (mounted) setState(() => loading = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            isLogin ? "Autentificare" : "Creează Cont",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                const SizedBox(height: 20),

                // --- OR DIVIDER ---
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "SAU",
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),

                const SizedBox(height: 20),

                // --- SOCIAL LOGIN ---
                Center(
                  child: SizedBox(
                    width: double.infinity,
                    child: _buildSocialButton(
                      icon:
                          'https://cdn-icons-png.flaticon.com/512/2991/2991148.png',
                      label: "Google",
                      onPressed: () async {
                        setState(() {
                          loading = true;
                          error = '';
                        });
                        try {
                          await _auth.signInWithGoogle();
                        } catch (e) {
                          setState(() => error = e.toString());
                        }
                        if (mounted) setState(() => loading = false);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // --- FOOTER ---
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLogin ? "Nu ai un cont?" : "Ai deja un cont?",
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          isLogin = !isLogin;
                          error = '';
                          // Păstrăm email-ul dar ștergem parola pentru securitate și claritate
                          _passwordController.clear();
                          _nameController.clear();
                        }),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8)),
                        child: Text(
                          isLogin ? "Înregistrează-te" : "Autentifică-te",
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: Text(
                        error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF64748B),
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    TextEditingController? controller,
    Key? key,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
        prefixIcon: Icon(icon, color: const Color(0xFF2563EB), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: Colors.grey.shade200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(icon, height: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
