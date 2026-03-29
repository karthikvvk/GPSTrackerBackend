import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gpstracking/nav.dart';
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
  final _emailController  = TextEditingController();
  bool _isScanning        = false;
  bool _loading           = false;
  String? _error;
  MobileScannerController? _scannerController;

  @override
  void dispose() {
    _emailController.dispose();
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

  bool _hasNavigated = false;

  // ---------------------------------------------------------------------------
  // QR detect — same logic as before, untouched
  // ---------------------------------------------------------------------------
  void _onDetect(BarcodeCapture capture) async {
    if (_hasNavigated) return;

    for (final barcode in capture.barcodes) {
      if (barcode.rawValue == null) continue;

      final code  = barcode.rawValue!;
      final parts = code.split(':');

      // Format: email:kodomo_link_userId
      if (parts.length >= 2) {
        final email     = parts[0];
        final linkToken = parts.sublist(1).join(':');

        if (linkToken.startsWith('kodomo_link_')) {
          _hasNavigated = true;

          _scannerController?.stop();
          setState(() => _isScanning = false);
          _scannerController?.dispose();
          _scannerController = null;

          await Future.delayed(const Duration(milliseconds: 100));
          if (!mounted) return;

          final childUserId = linkToken.replaceFirst('kodomo_link_', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Child account found: $email'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );

          context.read<AppSession>().linkChild(
                childName: email,
                childUserId: childUserId,
              );
          context.go(AppRoutes.dashboard);
        } else {
          _emailController.text = email;
          _toggleScanner();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR Code Scanned!')),
          );
        }
      } else {
        _emailController.text = code;
        _toggleScanner();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Code Scanned!')),
        );
      }
      break;
    }
  }

  // ---------------------------------------------------------------------------
  // Email Method — lookup child by email via backend
  // ---------------------------------------------------------------------------
  Future<void> _linkByEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter the child\'s email address.');
      return;
    }

    setState(() {
      _loading = true;
      _error   = null;
    });

    final session = context.read<AppSession>();
    final errorMsg = await session.lookupChildByEmail(email);

    if (!mounted) return;

    if (errorMsg != null) {
      setState(() {
        _loading = false;
        _error   = errorMsg;
      });
    } else {
      context.go(AppRoutes.dashboard);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
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
                  style: context.textStyles.headlineLarge
                      ?.copyWith(color: scheme.onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Link the child device to start tracking.',
                  style: context.textStyles.bodyLarge
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Email Method ──────────────────────────────────────────
                GradientCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Enter the child\'s registered email address.',
                        style: context.textStyles.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _linkByEmail(),
                        decoration: const InputDecoration(
                          labelText: 'Child\'s Email',
                          hintText: 'child@example.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),

                      // Error message
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: AppSpacing.paddingMd,
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  color: scheme.onErrorContainer),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: context.textStyles.bodyMedium
                                      ?.copyWith(
                                          color: scheme.onErrorContainer),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.xl),
                      PrimaryPillButton(
                        label: _loading ? 'Linking…' : 'Link Account',
                        icon: Icons.link_rounded,
                        onPressed: _loading ? null : _linkByEmail,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── QR Method ─────────────────────────────────────────────
                GradientCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.qr_code_scanner_rounded,
                              size: 20, color: scheme.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Scan QR Code',
                            style: context.textStyles.titleSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Scan the QR code shown on the child\'s Profile page for instant linking.',
                        style: context.textStyles.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: _toggleScanner,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Open Scanner'),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                              color:
                                  scheme.outline.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.lg),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
