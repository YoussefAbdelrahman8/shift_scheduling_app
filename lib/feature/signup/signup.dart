import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes_manager/routes.dart';
import '../../providers/CoreSessionProvider.dart';


class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final GlobalKey<FormState> _formKey = GlobalKey();

  final FocusNode _focusNodeEmail = FocusNode();
  final FocusNode _focusNodePassword = FocusNode();
  final FocusNode _focusNodeConfirmPassword = FocusNode();
  final TextEditingController _controllerUsername = TextEditingController();
  final TextEditingController _controllerEmail = TextEditingController();
  final TextEditingController _controllerPassword = TextEditingController();
  final TextEditingController _controllerConfirmPassword = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    // Clear any previous errors when entering signup page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CoreSessionProvider>().clearError();
    });
  }

  Future<void> _signup() async {
    if (_formKey.currentState?.validate() ?? false) {
      final provider = context.read<CoreSessionProvider>();

      // Clear any previous errors
      provider.clearError();

      final success = await provider.signUp(
        username: _controllerUsername.text.trim(),
        email: _controllerEmail.text.trim(),
        password: _controllerPassword.text,
      );

      if (success && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Please login.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Clear form and navigate to login
        _formKey.currentState?.reset();
        Navigator.pushReplacementNamed(context, Routes.SignInRoute);
      }
      // Error handling is done automatically through the provider
      // and displayed in the UI via Consumer widget
    }
  }

  // Enhanced password validation to match provider requirements
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Please enter password.";
    }
    if (value.length < 8) {
      return "Password must be at least 8 characters.";
    }

    // Check for password strength requirements
    bool hasUppercase = value.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = value.contains(RegExp(r'[a-z]'));
    bool hasDigits = value.contains(RegExp(r'[0-9]'));
    bool hasSpecialCharacters = value.contains(RegExp(r'[@$!%*?&]'));

    if (!hasUppercase) {
      return "Password must contain at least one uppercase letter.";
    }
    if (!hasLowercase) {
      return "Password must contain at least one lowercase letter.";
    }
    if (!hasDigits) {
      return "Password must contain at least one number.";
    }
    if (!hasSpecialCharacters) {
      return "Password must contain at least one special character (@\$!%*?&).";
    }

    return null;
  }

  // Enhanced email validation
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Please enter email.";
    }

    // More robust email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return "Please enter a valid email address.";
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      body: Consumer<CoreSessionProvider>(
        builder: (context, sessionProvider, child) {
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  Text(
                    "Register",
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Create your account",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 35),

                  // Username Field
                  TextFormField(
                    controller: _controllerUsername,
                    keyboardType: TextInputType.name,
                    enabled: !sessionProvider.isLoading,
                    decoration: InputDecoration(
                      labelText: "Username",
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      errorBorder: sessionProvider.errorMessage != null
                          ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.red),
                      )
                          : null,
                    ),
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Please enter username.";
                      }
                      if (value.trim().length < 3) {
                        return "Username must be at least 3 characters.";
                      }
                      if (value.trim().length > 20) {
                        return "Username must be less than 20 characters.";
                      }
                      // Check for valid username characters
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
                        return "Username can only contain letters, numbers, and underscores.";
                      }
                      return null;
                    },
                    onEditingComplete: () => _focusNodeEmail.requestFocus(),
                  ),

                  const SizedBox(height: 10),

                  // Email Field
                  TextFormField(
                    controller: _controllerEmail,
                    focusNode: _focusNodeEmail,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !sessionProvider.isLoading,
                    decoration: InputDecoration(
                      labelText: "Email",
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      errorBorder: sessionProvider.errorMessage != null
                          ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.red),
                      )
                          : null,
                    ),
                    validator: _validateEmail,
                    onEditingComplete: () => _focusNodePassword.requestFocus(),
                  ),

                  const SizedBox(height: 10),

                  // Password Field
                  TextFormField(
                    controller: _controllerPassword,
                    obscureText: _obscurePassword,
                    focusNode: _focusNodePassword,
                    enabled: !sessionProvider.isLoading,
                    keyboardType: TextInputType.visiblePassword,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: const Icon(Icons.password_outlined),
                      suffixIcon: IconButton(
                        onPressed: sessionProvider.isLoading ? null : () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: _obscurePassword
                            ? const Icon(Icons.visibility_outlined)
                            : const Icon(Icons.visibility_off_outlined),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      errorBorder: sessionProvider.errorMessage != null
                          ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.red),
                      )
                          : null,
                    ),
                    validator: _validatePassword,
                    onEditingComplete: () => _focusNodeConfirmPassword.requestFocus(),
                  ),

                  const SizedBox(height: 10),

                  // Confirm Password Field
                  TextFormField(
                    controller: _controllerConfirmPassword,
                    obscureText: _obscureConfirmPassword,
                    focusNode: _focusNodeConfirmPassword,
                    enabled: !sessionProvider.isLoading,
                    keyboardType: TextInputType.visiblePassword,
                    decoration: InputDecoration(
                      labelText: "Confirm Password",
                      prefixIcon: const Icon(Icons.password_outlined),
                      suffixIcon: IconButton(
                        onPressed: sessionProvider.isLoading ? null : () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        icon: _obscureConfirmPassword
                            ? const Icon(Icons.visibility_outlined)
                            : const Icon(Icons.visibility_off_outlined),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      errorBorder: sessionProvider.errorMessage != null
                          ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.red),
                      )
                          : null,
                    ),
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return "Please confirm your password.";
                      }
                      if (value != _controllerPassword.text) {
                        return "Passwords don't match.";
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => sessionProvider.isLoading ? null : _signup(),
                  ),

                  const SizedBox(height: 20),

                  // Error Message Display
                  if (sessionProvider.errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sessionProvider.errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => sessionProvider.clearError(),
                            icon: Icon(Icons.close, color: Colors.red.shade700, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                  // Password Requirements Helper
                  if (_controllerPassword.text.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Password Requirements:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildRequirementItem("At least 8 characters", _controllerPassword.text.length >= 8),
                          _buildRequirementItem("One uppercase letter", _controllerPassword.text.contains(RegExp(r'[A-Z]'))),
                          _buildRequirementItem("One lowercase letter", _controllerPassword.text.contains(RegExp(r'[a-z]'))),
                          _buildRequirementItem("One number", _controllerPassword.text.contains(RegExp(r'[0-9]'))),
                          _buildRequirementItem("One special character (@\$!%*?&)", _controllerPassword.text.contains(RegExp(r'[@$!%*?&]'))),
                        ],
                      ),
                    ),

                  const SizedBox(height: 30),

                  // Register Button and Navigation
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: sessionProvider.isLoading ? null : _signup,
                          child: sessionProvider.isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Text("Register"),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Login navigation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Already have an account?"),
                          TextButton(
                            onPressed: sessionProvider.isLoading ? null : () {
                              // Clear form and errors before navigating
                              _formKey.currentState?.reset();
                              sessionProvider.clearError();
                              Navigator.pushReplacementNamed(context, Routes.SignInRoute);
                            },
                            child: const Text("Login"),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper widget for password requirements
  Widget _buildRequirementItem(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isMet ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _focusNodeEmail.dispose();
    _focusNodePassword.dispose();
    _focusNodeConfirmPassword.dispose();
    _controllerUsername.dispose();
    _controllerEmail.dispose();
    _controllerPassword.dispose();
    _controllerConfirmPassword.dispose();
    super.dispose();
  }
}