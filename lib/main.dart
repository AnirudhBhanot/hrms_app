import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hrms_app/homepage.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String? empCode = prefs.getString('empCode');
  String? fullName = prefs.getString('fullName');

  runApp(MyApp(isLoggedIn: isLoggedIn, empCode: empCode, fullName: fullName));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String? empCode;
  final String? fullName;

  const MyApp({
    super.key,
    required this.isLoggedIn,
    this.empCode,
    this.fullName,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Login',
      theme: ThemeData(useMaterial3: true, fontFamily: 'Segoe UI'),
      home: isLoggedIn
          ? HomePage(empCode: empCode ?? "", fullName: fullName ?? "")
          : const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _buttonPressed = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    disableScreenshot(); // use this function to disable screenshot and screen recording
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  // add this function to disable screenshot and screen recording
  Future<void> disableScreenshot() async {
    await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
  }

  @override
  void dispose() {
    _controller.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 🔐 LOGIN FUNCTION
  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showSnackBar("Please enter username and password", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("http://192.168.20.44:81/api/Account/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final empCode = data["empCode"];
        final fullName = data["fullName"];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('empCode', empCode ?? "");
        await prefs.setString('fullName', fullName ?? "");

        _showSnackBar(data["message"] ?? "Login Successful", Colors.green);

        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                HomePage(empCode: empCode ?? "", fullName: fullName ?? ""),
          ),
        );
      } else {
        _showSnackBar("Invalid username or password", Colors.red);
      }
    } catch (e) {
      print(e); // important for debugging
      _showSnackBar("Server not reachable", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color.fromARGB(255, 37, 108, 189),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Card(
                    elevation: 14,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.8, end: 1),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutBack,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: child,
                              );
                            },
                            child: Image.asset('assets/logo.png', height: 80),
                          ),

                          const SizedBox(height: 24),

                          _AnimatedTextField(
                            label: 'Username',
                            icon: Icons.person_outline,
                            controller: _usernameController,
                          ),

                          const SizedBox(height: 16),

                          _AnimatedTextField(
                            label: 'Password',
                            icon: Icons.lock_outline,
                            obscure: true,
                            controller: _passwordController,
                          ),

                          const SizedBox(height: 24),

                          GestureDetector(
                            onTapDown: (_) =>
                                setState(() => _buttonPressed = true),
                            onTapUp: (_) =>
                                setState(() => _buttonPressed = false),
                            onTapCancel: () =>
                                setState(() => _buttonPressed = false),
                            child: AnimatedScale(
                              scale: _buttonPressed ? 0.97 : 1,
                              duration: const Duration(milliseconds: 120),
                              child: SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(
                                      255,
                                      37,
                                      108,
                                      189,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _isLoading ? null : _login,
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Login',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedTextField extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool obscure;
  final TextEditingController controller;

  const _AnimatedTextField({
    required this.label,
    required this.icon,
    required this.controller,
    this.obscure = false,
  });

  @override
  State<_AnimatedTextField> createState() => _AnimatedTextFieldState();
}

class _AnimatedTextFieldState extends State<_AnimatedTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.translationValues(0, _focused ? -2 : 0, 0),
      child: Focus(
        onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
        child: TextField(
          controller: widget.controller,
          obscureText: widget.obscure,
          decoration: InputDecoration(
            prefixIcon: Icon(widget.icon),
            labelText: widget.label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
