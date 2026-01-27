import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gpstracking/data/models.dart';
import 'package:gpstracking/nav.dart';
import 'package:gpstracking/state/app_session.dart';
import 'package:gpstracking/theme.dart';
import 'package:gpstracking/ui/app_widgets.dart';
import 'package:provider/provider.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.gps_fixed_rounded, size: 64, color: scheme.primary),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _isSignUp ? 'Create Account' : 'Welcome Back',
                  style: context.textStyles.headlineLarge
                      ?.copyWith(color: scheme.onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _isSignUp
                      ? 'Sign up to start tracking'
                      : 'Sign in to continue',
                  style: context.textStyles.bodyLarge
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                GradientCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Account ID / Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Please enter email'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Please enter password'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else
                          PrimaryPillButton(
                            label: _isSignUp ? 'Sign Up' : 'Sign In',
                            onPressed: _handleAuth,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isSignUp = !_isSignUp;
                      _formKey.currentState?.reset();
                    });
                  },
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign In'
                        : "Don't have an account? Create one",
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final session = context.read<AppSession>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (_isSignUp) {
        // Create account ONLY (no auto-sign in yet)
        final user = await session.createAccount(
            email, password, 'User'); // Default name
        if (user != null && mounted) {
          // Show Role Selection Popup
          _showRoleSelectionDialog(context, user);
        }
      } else {
        // Sign In
        final success = await session.signInWithEmail(email, password);
        if (success && mounted) {
          // Router handles navigation to Dashboard
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRoleSelectionDialog(
      BuildContext context, Map<String, dynamic> user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Choose your role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoleOption(
              icon: Icons.location_on_rounded,
              title: "I'm being tracked",
              subtitle: "Kodomo Mode",
              onTap: () => _finalizeSignUp(context, user, UserRole.kodomo),
            ),
            const SizedBox(height: AppSpacing.md),
            _RoleOption(
              icon: Icons.visibility_rounded,
              title: "I'm tracking someone",
              subtitle: "Kazoku Mode",
              onTap: () => _finalizeSignUp(context, user, UserRole.kazoku),
            ),
          ],
        ),
      ),
    );
  }

  void _finalizeSignUp(
      BuildContext context, Map<String, dynamic> user, UserRole role) {
    Navigator.pop(context); // Close dialog
    final session = context.read<AppSession>();

    // Set Role
    session.setRole(role);

    // Complete Sign In (triggers router)
    // Note: user map is fresh from registration, setRole updates local state but
    // we need to ensure session knows the role BEFORE completing sign in if possible,
    // or just assume setRole works.
    // Actually setRole updates _role. completeSignIn sets _role from user map if present.
    // We should manually ensure session state is consistent.

    session.completeSignIn(user);
    session.setRole(role); // Ensure role is set in session

    if (role == UserRole.kazoku) {
      // Navigate to Dashboard but show Link Dialog
      // We can use a post-frame callback or simple navigation argument?
      // Since router takes over, we can't easily pass args to dashboard via GoRouter
      // without modifying the route.
      // Alternative: Use a provider/session flag "shouldShowLinkDialog".
      // For now, I will let the user navigate to profile manually or
      // see if I can direct them to Profile page?
      // User said "navigate to the screen to link child".
      // Profile page has the linking logic.
      if (mounted) {
        // Router execution happens on next tick.
        // We can try to force navigation to Profile AFTER dashboard?
        // Or just let them land on dashboard.
        // User Request: "navigate to the screen to link child"
        // I'll try to push to profile page.
        Future.delayed(const Duration(milliseconds: 100), () {
          if (context.mounted) context.go(AppRoutes.profile);
        });
      }
    }
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: context.textStyles.titleMedium
                          ?.copyWith(color: scheme.onSurface)),
                  Text(subtitle,
                      style: context.textStyles.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
