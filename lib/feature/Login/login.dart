import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes_manager/routes.dart';
import '../../providers/CoreSessionProvider.dart';


class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final GlobalKey<FormState> _formKey = GlobalKey();

  final FocusNode _focusNodePassword = FocusNode();
  final TextEditingController _controllerUsername = TextEditingController();
  final TextEditingController _controllerPassword = TextEditingController();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Clear any previous errors when entering login page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CoreSessionProvider>().clearError();
    });
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      final provider = context.read<CoreSessionProvider>();

      // Clear any previous errors
      provider.clearError();

      final success = await provider.signIn(
        emailOrUsername: _controllerUsername.text.trim(),
        password: _controllerPassword.text,
      );

      if (success && mounted) {
        // Navigate to home page on successful login
        Navigator.pushReplacementNamed(context, Routes.HomePageRoute);
      }
      // Error handling is done automatically through the provider
      // and displayed in the UI via Consumer widget
    }
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
              padding: const EdgeInsets.all(30.0),
              child: Column(
                children: [
                  const SizedBox(height: 150),
                  Text(
                    "Welcome back",
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Login to your account",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 60),

                  // Username/Email Field
                  TextFormField(
                    controller: _controllerUsername,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !sessionProvider.isLoading, // Disable when loading
                    decoration: InputDecoration(
                      labelText: "Email or Username",
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      // Show error border if there's an error
                      errorBorder: sessionProvider.errorMessage != null
                          ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.red),
                      )
                          : null,
                    ),
                    onEditingComplete: () => _focusNodePassword.requestFocus(),
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Please enter email or username.";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 10),

                  // Password Field
                  TextFormField(
                    controller: _controllerPassword,
                    focusNode: _focusNodePassword,
                    obscureText: _obscurePassword,
                    enabled: !sessionProvider.isLoading, // Disable when loading
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
                      // Show error border if there's an error
                      errorBorder: sessionProvider.errorMessage != null
                          ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.red),
                      )
                          : null,
                    ),
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter password.";
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => sessionProvider.isLoading ? null : _login(),
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

                  const SizedBox(height: 20),

                  // Login Button and Navigation
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
                          onPressed: sessionProvider.isLoading ? null : _login,
                          child: sessionProvider.isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Text("Login"),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Sign up navigation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account?"),
                          TextButton(
                            onPressed: sessionProvider.isLoading ? null : () {
                              // Clear form and errors before navigating
                              _formKey.currentState?.reset();
                              sessionProvider.clearError();
                              Navigator.pushReplacementNamed(context, Routes.SignUpRoute);
                            },
                            child: const Text("Signup"),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Session State Debug Info (remove in production)
                  if (sessionProvider.sessionState != SessionState.initial &&
                      sessionProvider.sessionState != SessionState.unauthenticated)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        'Session State: ${sessionProvider.sessionState.toString().split('.').last}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _focusNodePassword.dispose();
    _controllerUsername.dispose();
    _controllerPassword.dispose();
    super.dispose();
  }
}