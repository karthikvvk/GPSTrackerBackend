import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gpstracking/state/app_session.dart';
import 'package:gpstracking/theme.dart';
import 'package:gpstracking/ui/app_widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

class LinkAccountPage extends StatefulWidget {
  const LinkAccountPage({super.key});

  @override
  State<LinkAccountPage> createState() => _LinkAccountPageState();
}

class _LinkAccountPageState extends State<LinkAccountPage> {
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isScanning = false;
  MobileScannerController? _scannerController;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _toggleScanner() {
    setState(() {
      _isScanning = !_isScanning;
      if (_isScanning) {
        _scannerController = MobileScannerController();
      } else {
        _scannerController?.dispose();
        _scannerController = null;
      }
    });
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final code = barcode.rawValue!;
        final parts = code.split(':');

        // Format: email:kodomo_link_userId
        if (parts.length >= 2) {
          final email = parts[0];
          final linkToken =
              parts.sublist(1).join(':'); // Handle case if email contains ':'

          _accountController.text = email;
          _passwordController.text = linkToken;

          if (mounted) {
            _toggleScanner();

            // Show success and auto-link if valid
            if (linkToken.startsWith('kodomo_link_')) {
              final childUserId = linkToken.replaceFirst('kodomo_link_', '');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Child account found: $email'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              );
              // Auto-trigger link after a short delay
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && email.isNotEmpty) {
                  context.read<AppSession>().linkChild(
                        childName: email,
                        childUserId: childUserId,
                      );
                  context.pop();
                }
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR Code Scanned!')),
              );
            }
          }
        } else {
          _accountController.text = code;
          if (mounted) {
            _toggleScanner();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('QR Code Scanned!')),
            );
          }
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_isScanning) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Scan QR Code'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _toggleScanner,
          ),
        ),
        body: MobileScanner(
          controller: _scannerController,
          onDetect: _onDetect,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(onPressed: () => context.pop()),
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.link_rounded, size: 64, color: scheme.primary),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Link Child Account',
                  style: context.textStyles.headlineLarge?.copyWith(
                    color: scheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Link the child device to start tracking.',
                  style: context.textStyles.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                // Method selection row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Email Method',
                      style: context.textStyles.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Text(
                        '|',
                        style: context.textStyles.titleMedium?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _toggleScanner,
                      child: Text(
                        'Scan QR',
                        style: context.textStyles.titleMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: scheme.primary,
                          decorationThickness: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                GradientCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Email Method section header
                      Row(
                        children: [
                          Icon(Icons.email_outlined,
                              size: 20, color: scheme.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Email Method',
                            style: context.textStyles.titleSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _accountController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryPillButton(
                        label: 'Link Account',
                        onPressed: () {
                          if (_accountController.text.trim().isNotEmpty &&
                              _passwordController.text.trim().isNotEmpty) {
                            final pwd = _passwordController.text.trim();
                            final childUserId = pwd.startsWith('kodomo_link_')
                                ? pwd.replaceFirst('kodomo_link_', '')
                                : pwd;
                            context.read<AppSession>().linkChild(
                                  childName: _accountController.text.trim(),
                                  childUserId: childUserId,
                                );
                            context.pop();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // Scan QR section
                GradientCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.qr_code_scanner_rounded,
                              size: 20, color: scheme.primary),
                          const SizedBox(width: AppSpacing.sm),
                          GestureDetector(
                            onTap: _toggleScanner,
                            child: Text(
                              'Scan QR',
                              style: context.textStyles.titleSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: scheme.primary,
                                decorationThickness: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Scan the QR code from the child device. The QR code contains the email and password for automatic linking.',
                        style: context.textStyles.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: _toggleScanner,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Open Scanner'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                              color: scheme.outline.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'QR Code Format: email:password',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
