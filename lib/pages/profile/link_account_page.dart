import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gpstracking/nav.dart';
import 'package:gpstracking/state/app_session.dart';
import 'package:gpstracking/theme.dart';
import 'package:gpstracking/ui/app_widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

class LinkAccountPage extends StatefulWidget {
  const LinkAccountPage({super.key});

  @override
  State<LinkAccountPage> createState() => _LinkAccountPageState();
}

class _LinkAccountPageState extends State<LinkAccountPage> {
  final _emailController = TextEditingController();
  bool _isScanning = false;
  bool _loading = false;
  String? _error;
  MobileScannerController? _scannerController;
  bool _hasNavigated = false;

  @override
  void dispose() {
    _emailController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  // ── NEW: Show media picker bottom sheet first ─────────────────────────────
  Future<void> _showMediaPicker() async {
    final picker = ImagePicker();

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _startScanner(); // opens live camera scanner
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                final file =
                    await picker.pickImage(source: ImageSource.gallery);
                if (file == null || !mounted) return;

                // Feed the image into mobile_scanner for QR decoding
                final tempController = MobileScannerController();
                final result = await tempController.analyzeImage(file.path);
                await tempController.dispose();

                if (!mounted) return;

                if (result != null && result.barcodes.isNotEmpty) {
                  // Reuse the same _onDetect logic
                  _onDetect(result);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No QR code found in image.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startScanner() {
    setState(() {
      _isScanning = true;
      _scannerController = MobileScannerController();
    });
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

  void _onDetect(BarcodeCapture capture) async {
    if (_hasNavigated) return;

    for (final barcode in capture.barcodes) {
      if (barcode.rawValue == null) continue;

      final code = barcode.rawValue!;
      final parts = code.split(':');

      if (parts.length >= 2) {
        final email = parts[0];
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
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('QR Code Scanned!')));
        }
      } else {
        _emailController.text = code;
        _toggleScanner();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('QR Code Scanned!')));
      }
      break;
    }
  }

  Future<void> _linkByEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter the child\'s email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final session = context.read<AppSession>();
    final errorMsg = await session.lookupChildByEmail(email);
    if (!mounted) return;
    if (errorMsg != null) {
      setState(() {
        _loading = false;
        _error = errorMsg;
      });
    } else {
      context.go(AppRoutes.dashboard);
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
                      Row(children: [
                        Icon(Icons.email_outlined,
                            size: 20, color: scheme.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Email Method',
                            style: context.textStyles.titleSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Enter the child\'s registered email address.',
                          style: context.textStyles.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
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
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: AppSpacing.paddingMd,
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(children: [
                            Icon(Icons.error_outline_rounded,
                                color: scheme.onErrorContainer),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(_error!,
                                  style: context.textStyles.bodyMedium
                                      ?.copyWith(
                                          color: scheme.onErrorContainer)),
                            ),
                          ]),
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

                // ── QR Method — now opens media picker sheet ──────────────
                GradientCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Icon(Icons.qr_code_scanner_rounded,
                            size: 20, color: scheme.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Scan QR Code',
                            style: context.textStyles.titleSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                          'Scan the QR code shown on the child\'s Profile page for instant linking.',
                          style: context.textStyles.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        // ← Changed: calls _showMediaPicker instead
                        onPressed: _showMediaPicker,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Media Picker Bottom Sheet ─────────────────────────────────────────────────

class _MediaPickerSheet extends StatefulWidget {
  final VoidCallback onScanQR;
  final void Function(XFile) onPickFromGallery;

  const _MediaPickerSheet({
    required this.onScanQR,
    required this.onPickFromGallery,
  });

  @override
  State<_MediaPickerSheet> createState() => _MediaPickerSheetState();
}

class _MediaPickerSheetState extends State<_MediaPickerSheet> {
  List<AssetEntity> _recentAssets = [];
  bool _loadingAssets = true;

  @override
  void initState() {
    super.initState();
    _loadRecentPhotos();
  }

  Future<void> _loadRecentPhotos() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      setState(() => _loadingAssets = false);
      return;
    }
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (albums.isEmpty) {
      setState(() => _loadingAssets = false);
      return;
    }
    // Load first 20 recent images
    final assets = await albums.first.getAssetListPaged(page: 0, size: 20);
    setState(() {
      _recentAssets = assets;
      _loadingAssets = false;
    });
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) widget.onPickFromGallery(file);
  }

  Future<void> _pickAsset(AssetEntity asset) async {
    final file = await asset.originFile;
    if (file != null) widget.onPickFromGallery(XFile(file.path));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.65,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Select image',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: scheme.onSurface)),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Done', style: TextStyle(color: scheme.primary)),
                ),
              ],
            ),
          ),

          // Grid
          Expanded(
            child: _loadingAssets
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(2),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemCount:
                        _recentAssets.length + 2, // +2 for Camera & Browse
                    itemBuilder: (ctx, index) {
                      // First cell: Camera
                      if (index == 0) {
                        return _ActionCell(
                          icon: Icons.camera_alt_rounded,
                          label: 'Camera',
                          color: scheme.surfaceContainerHigh,
                          onTap: widget.onScanQR,
                        );
                      }
                      // Second cell: Browse
                      if (index == 1) {
                        return _ActionCell(
                          icon: Icons.photo_library_rounded,
                          label: 'Browse',
                          color: scheme.surfaceContainerHigh,
                          onTap: _pickFromGallery,
                        );
                      }
                      // Rest: recent photos
                      final asset = _recentAssets[index - 2];
                      return _AssetThumbnail(
                        asset: asset,
                        onTap: () => _pickAsset(asset),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCell({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: color,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: scheme.onSurface, size: 28),
            const SizedBox(height: 4),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _AssetThumbnail extends StatefulWidget {
  final AssetEntity asset;
  final VoidCallback onTap;

  const _AssetThumbnail({required this.asset, required this.onTap});

  @override
  State<_AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<_AssetThumbnail> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    widget.asset
        .thumbnailDataWithSize(const ThumbnailSize(200, 200))
        .then((data) {
      if (mounted) setState(() => _thumb = data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: _thumb != null
          ? Image.memory(_thumb!, fit: BoxFit.cover)
          : Container(color: Colors.grey.shade800),
    );
  }
}
