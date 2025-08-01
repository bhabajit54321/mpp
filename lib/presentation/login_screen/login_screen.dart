import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(); // Changed from email to username
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isFormValid = false;
  String? _usernameError;
  String? _passwordError;
  bool _isEmailInput = false; // Track if input is email or phone

  // Animation controllers
  late AnimationController _logoAnimationController;
  late AnimationController _formAnimationController;
  late Animation<double> _logoFadeAnimation;
  late Animation<Offset> _formSlideAnimation;

  // Focus nodes to manage keyboard behavior
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _usernameController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);

    // Add focus listeners
    _usernameFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
  }

  void _setupAnimations() {
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _formAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _logoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.easeOut,
    ));

    _formSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _formAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    _logoAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _formAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _formAnimationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _validateForm() {
    setState(() {
      final username = _usernameController.text.trim();
      _usernameError = _validateUsername(username);
      _passwordError = _validatePassword(_passwordController.text);
      _isFormValid = _usernameError == null &&
          _passwordError == null &&
          username.isNotEmpty &&
          _passwordController.text.isNotEmpty;
      
      // Check if input is email for UI updates
      _isEmailInput = _isEmail(username);
    });
  }

  bool _isEmail(String input) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(input);
  }

  bool _isPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d]'), '');
    return RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned) || 
           RegExp(r'^\d{10,15}$').hasMatch(cleaned);
  }

  String? _validateUsername(String value) {
    if (value.isEmpty) return null;

    if (_isPhoneNumber(value)) {
      if (value.length < 10) return 'Please enter a valid phone number';
      return null;
    }

    if (_isEmail(value)) {
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}').hasMatch(value)) {
        return 'Please enter a valid email address';
      }
      return null;
    }

    return 'Please enter a valid email address or phone number';
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) return null;
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  Future<void> _handleLogin() async {
    if (!_isFormValid) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      // Use enhanced auth service with username (email/phone) support
      final response = await _authService.signIn(
        username: username,
        password: password,
      );

      if (response.user != null) {
        HapticFeedback.lightImpact();
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.homeMarketplaceFeed);
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Authentication failed. Please try again.');
      }
    } on AppAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar(e.message);
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Login failed. Please check your credentials.');
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _authService.signInWithGoogle();
      
      if (response.user != null) {
        HapticFeedback.lightImpact();
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.homeMarketplaceFeed);
        }
      }
    } on AppAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar(e.message);
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Google sign-in failed. Please try again.');
    }
  }

  Future<void> _handleFacebookLogin() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _authService.signInWithFacebook();
      
      if (response.user != null) {
        HapticFeedback.lightImpact();
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.homeMarketplaceFeed);
        }
      }
    } on AppAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar(e.message);
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Facebook sign-in failed. Please try again.');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.getErrorColor(true),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(4.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.getSuccessColor(true),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(4.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 6.h),
                    _buildLogo(),
                    SizedBox(height: 4.h),
                    _buildLoginForm(),
                    SizedBox(height: 4.h),
                    _buildSocialLoginSection(),
                    SizedBox(height: 4.h),
                    _buildSignUpLink(),
                    SizedBox(height: 4.h),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return FadeTransition(
      opacity: _logoFadeAnimation,
      child: Column(
        children: [
          // Khilonjiya.com logo text
          ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                colors: [
                  AppTheme.lightTheme.colorScheme.primary,
                  AppTheme.lightTheme.colorScheme.tertiary,
                ],
              ).createShader(bounds);
            },
            child: Text(
              'khilonjiya.com',
              style: TextStyle(
                fontSize: 8.w,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
          SizedBox(height: 1.h),
          // Tagline
          Text(
            'আমাৰ সংস্কৃতি, আমাৰ গৌৰৱ',
            style: TextStyle(
              fontSize: 3.5.w,
              fontWeight: FontWeight.w500,
              color: AppTheme.getTextSecondaryColor(true),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            'Our Culture, Our Pride',
            style: TextStyle(
              fontSize: 3.w,
              fontWeight: FontWeight.w400,
              color: AppTheme.getTextSecondaryColor(true),
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            'Welcome Back!',
            style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTheme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Sign in to continue to your marketplace',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.getTextSecondaryColor(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return SlideTransition(
      position: _formSlideAnimation,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildUsernameField(),
            SizedBox(height: 2.h),
            _buildPasswordField(),
            SizedBox(height: 1.h),
            _buildForgotPasswordLink(),
            SizedBox(height: 3.h),
            _buildLoginButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _usernameController,
          focusNode: _usernameFocusNode,
          keyboardType: _isEmailInput ? TextInputType.emailAddress : TextInputType.phone,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: true,
          autofillHints: const [AutofillHints.email, AutofillHints.username],
          decoration: InputDecoration(
            labelText: 'Email or Phone Number',
            hintText: 'Enter your email or phone number',
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: Icon(
                _isEmailInput ? Icons.email_outlined : Icons.phone_outlined,
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                size: 5.w,
              ),
            ),
            errorText: null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.lightTheme.colorScheme.outline,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.lightTheme.colorScheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.getErrorColor(true),
                width: 1,
              ),
            ),
          ),
          onChanged: (value) => _validateForm(),
          onFieldSubmitted: (value) {
            FocusScope.of(context).requestFocus(_passwordFocusNode);
          },
        ),
        if (_usernameError != null) ...[
          SizedBox(height: 1.h),
          Padding(
            padding: EdgeInsets.only(left: 3.w),
            child: Text(
              _usernameError!,
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.getErrorColor(true),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          obscureText: !_isPasswordVisible,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter your password',
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: Icon(
                Icons.lock_outline,
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                size: 5.w,
              ),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                size: 5.w,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
            errorText: null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.lightTheme.colorScheme.outline,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.lightTheme.colorScheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.getErrorColor(true),
                width: 1,
              ),
            ),
          ),
          onChanged: (value) => _validateForm(),
          onFieldSubmitted: (value) {
            if (_isFormValid) {
              _handleLogin();
            }
          },
        ),
        if (_passwordError != null) ...[
          SizedBox(height: 1.h),
          Padding(
            padding: EdgeInsets.only(left: 3.w),
            child: Text(
              _passwordError!,
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.getErrorColor(true),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildForgotPasswordLink() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          FocusScope.of(context).unfocus();
          // Navigate to forgot password screen
          _showSuccessSnackBar('Forgot password functionality coming soon!');
        },
        child: Text(
          'Forgot Password?',
          style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.lightTheme.primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      height: 7.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: _isFormValid && !_isLoading
            ? LinearGradient(
                colors: [
                  AppTheme.getPrimaryColor(true),
                  AppTheme.getAccentColor(true),
                ],
              )
            : null,
      ),
      child: ElevatedButton(
        onPressed: _isFormValid && !_isLoading ? _handleLogin : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFormValid && !_isLoading
              ? Colors.transparent
              : AppTheme.lightTheme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3 * 255),
          foregroundColor: Colors.white,
          elevation: _isFormValid ? 3.0 : 0,
                      shadowColor: AppTheme.getPrimaryColor(true).withValues(alpha: 0.3 * 255),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: 5.w,
                height: 5.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Sign In',
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildSocialLoginSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: AppTheme.lightTheme.colorScheme.outline,
                thickness: 1,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Text(
                'Or continue with',
                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: AppTheme.lightTheme.colorScheme.outline,
                thickness: 1,
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleLogin,
                icon: Icon(
                  Icons.g_mobiledata,
                  size: 24,
                  color: AppTheme.lightTheme.colorScheme.primary,
                ),
                label: Text(
                  'Google',
                  style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.primary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 3.w),
                  side: BorderSide(
                    color: AppTheme.lightTheme.colorScheme.outline,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleFacebookLogin,
                icon: Icon(
                  Icons.facebook,
                  size: 24,
                  color: const Color(0xFF1877F2),
                ),
                label: Text(
                  'Facebook',
                  style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF1877F2),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 3.w),
                  side: BorderSide(
                    color: AppTheme.lightTheme.colorScheme.outline,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Don\'t have an account? ',
          style: AppTheme.lightTheme.textTheme.bodyMedium,
        ),
        GestureDetector(
          onTap: _isLoading
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  Navigator.pushNamed(context, AppRoutes.registrationScreen);
                },
          child: Text(
            'Sign Up',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}