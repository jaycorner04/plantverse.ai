import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/constants/app_colors.dart';
import '../services/ai_service.dart';
import '../services/scan_result_store.dart';
import '../widgets/glass_container.dart';
import '../widgets/immersive_background.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanAnimationController;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isScanning = false;
  Uint8List? _selectedBytes;
  String? _status;
  String? _errorMessage;
  Timer? _scanStatusTimer;

  @override
  void initState() {
    super.initState();
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostImage());
  }

  @override
  void dispose() {
    _scanStatusTimer?.cancel();
    _scanAnimationController.dispose();
    super.dispose();
  }

  Future<void> _pickAndScan(ImageSource source) async {
    if (_isScanning) return;

    XFile? image;
    try {
      image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 68,
        maxWidth: 1024,
      );
    } on PlatformException catch (error) {
      _showPickerError(error.message ?? error.code);
      return;
    } catch (error) {
      _showPickerError(error.toString());
      return;
    }

    if (image == null) return;
    await _scanPickedImage(image);
  }

  Future<void> _recoverLostImage() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final response = await _imagePicker.retrieveLostData();
      if (!mounted || response.isEmpty) return;

      final image = response.file ??
          (response.files?.isNotEmpty == true ? response.files!.first : null);
      if (image == null) {
        final exception = response.exception;
        if (exception != null) {
          _showPickerError(exception.message ?? exception.code);
        }
        return;
      }

      await _scanPickedImage(image);
    } catch (error) {
      if (!mounted) return;
      _showPickerError(error.toString());
    }
  }

  Future<void> _scanPickedImage(XFile image) async {
    final bytes = await image.readAsBytes();
    setState(() {
      _selectedBytes = bytes;
      _isScanning = true;
      _status = ref.read(aiServiceProvider).usesBackend
          ? 'Waking PlantVerse cloud...'
          : 'Identifying flora...';
      _errorMessage = null;
    });
    _scanAnimationController.repeat(reverse: true);
    _startScanStatusCycle();

    try {
      final result = await ref.read(aiServiceProvider).identifyPlant(
            imageBytes: bytes,
            fileName: image.name,
          );
      if (!mounted) return;
      ref.read(scanResultProvider.notifier).state = ScanResult(
        result: result,
        imageBytes: bytes,
      );
      context.go('/plant_details');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _status = null;
      });
    } finally {
      if (mounted) {
        _scanStatusTimer?.cancel();
        _scanAnimationController.stop();
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _startScanStatusCycle() {
    final messages = ref.read(aiServiceProvider).usesBackend
        ? const [
            'Uploading compressed plant image...',
            'Asking PlantVerse AI vision...',
            'Checking backup plant providers...',
            'Building care, toxicity, and environment profile...',
            'Still working. Free cloud servers can take about a minute after sleeping...',
          ]
        : const [
            'Checking local plant catalog...',
            'Building safe offline care guidance...',
          ];
    var index = 0;
    _scanStatusTimer?.cancel();
    _scanStatusTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (!mounted || !_isScanning) {
        timer.cancel();
        return;
      }
      final safeIndex = index < messages.length ? index : messages.length - 1;
      final next = messages[safeIndex];
      setState(() => _status = next);
      if (index < messages.length - 1) index += 1;
    });
  }

  void _showPickerError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage =
          'Could not open camera/gallery. Check app permissions and try again. $message';
      _status = null;
      _isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final aiReady = ref.watch(aiServiceProvider).hasLiveProvider;

    return Scaffold(
      backgroundColor: AppColors.canvasDark,
      body: ImmersiveBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: _selectedBytes == null
                  ? Container(
                      color: AppColors.softBlack,
                      child: const Center(
                        child: Icon(
                          LucideIcons.scanLine,
                          size: 180,
                          color: Colors.white10,
                        ),
                      ),
                    )
                  : Image.memory(_selectedBytes!, fit: BoxFit.cover),
            ).animate(target: _isScanning ? 1 : 0).shimmer(
                  duration: 2.seconds,
                  color: AppColors.emeraldGreen.withOpacity(0.12),
                ),
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.28)),
            ),
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _glassIcon(
                      LucideIcons.arrowLeft,
                      onPressed: () => context.pop(),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.pureWhite.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.pureWhite.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            aiReady ? LucideIcons.cpu : LucideIcons.leaf,
                            color: aiReady
                                ? AppColors.actionBlueOnDark
                                : AppColors.warningYellow,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isScanning
                                ? 'PROCESSING'
                                : aiReady
                                    ? 'LIVE AI'
                                    : 'FREE MODE',
                            style: const TextStyle(
                              color: AppColors.pureWhite,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _glassIcon(
                      LucideIcons.imagePlus,
                      onPressed: () => _pickAndScan(ImageSource.gallery),
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: SizedBox(
                width: 300,
                height: 400,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isScanning
                          ? AppColors.actionBlueOnDark
                          : AppColors.pureWhite.withOpacity(0.35),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: _isScanning
                        ? [
                            BoxShadow(
                              color:
                                  AppColors.actionBlueOnDark.withOpacity(0.18),
                              blurRadius: 40,
                              spreadRadius: 10,
                            )
                          ]
                        : [],
                  ),
                  child: Stack(
                    children: [
                      if (_selectedBytes != null)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(7),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(34),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(
                                    _selectedBytes!,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  ),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          AppColors.softBlack.withOpacity(0.20),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        const Center(
                          child: Icon(
                            LucideIcons.imagePlus,
                            color: Colors.white24,
                            size: 62,
                          ),
                        ),
                      ..._buildCornerMarkers(),
                      if (_isScanning)
                        AnimatedBuilder(
                          animation: _scanAnimationController,
                          builder: (context, child) {
                            return Positioned(
                              top: _scanAnimationController.value * 390,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  color: AppColors.actionBlueOnDark,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.actionBlueOnDark,
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ).animate(target: _isScanning ? 1 : 0).scaleXY(
                      end: 1.04,
                      duration: 400.ms,
                      curve: Curves.easeOutBack,
                    ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 54),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorMessage ??
                          _status ??
                          (aiReady
                              ? 'Online scan uses PlantVerse cloud first. First scan may take longer if the free server is waking.'
                              : 'Free mode gives safe care guidance and catalog matches only when reliable.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _errorMessage == null
                            ? AppColors.pureWhite.withOpacity(0.86)
                            : AppColors.errorRed,
                        fontSize: 16,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _sourceButton(
                          icon: LucideIcons.camera,
                          label: 'Camera',
                          onTap: () => _pickAndScan(ImageSource.camera),
                        ),
                        const SizedBox(width: 12),
                        _sourceButton(
                          icon: LucideIcons.imagePlus,
                          label: 'Gallery',
                          onTap: () => _pickAndScan(ImageSource.gallery),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassIcon(IconData icon, {required VoidCallback onPressed}) {
    return GlassContainer(
      color: AppColors.pureWhite.withOpacity(0.08),
      borderRadius: BorderRadius.circular(999),
      child: IconButton(
        icon: Icon(icon, color: AppColors.pureWhite),
        onPressed: _isScanning ? null : onPressed,
      ),
    );
  }

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: _isScanning ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        disabledBackgroundColor: AppColors.pureWhite.withOpacity(0.14),
        backgroundColor: AppColors.emeraldGreen,
        foregroundColor: AppColors.pureWhite,
        shadowColor: AppColors.emeraldGreen.withOpacity(0.35),
        elevation: 8,
      ),
    );
  }

  List<Widget> _buildCornerMarkers() {
    const length = 40.0;
    const stroke = 3.0;
    final color =
        _isScanning ? AppColors.actionBlueOnDark : AppColors.pureWhite;

    Widget marker(Alignment alignment) {
      return Align(
        alignment: alignment,
        child: Container(
          width: length,
          height: length,
          decoration: BoxDecoration(
            border: Border(
              top: alignment.y < 0
                  ? BorderSide(color: color, width: stroke)
                  : BorderSide.none,
              bottom: alignment.y > 0
                  ? BorderSide(color: color, width: stroke)
                  : BorderSide.none,
              left: alignment.x < 0
                  ? BorderSide(color: color, width: stroke)
                  : BorderSide.none,
              right: alignment.x > 0
                  ? BorderSide(color: color, width: stroke)
                  : BorderSide.none,
            ),
            borderRadius: BorderRadius.only(
              topLeft: alignment == Alignment.topLeft
                  ? const Radius.circular(40)
                  : Radius.zero,
              topRight: alignment == Alignment.topRight
                  ? const Radius.circular(40)
                  : Radius.zero,
              bottomLeft: alignment == Alignment.bottomLeft
                  ? const Radius.circular(40)
                  : Radius.zero,
              bottomRight: alignment == Alignment.bottomRight
                  ? const Radius.circular(40)
                  : Radius.zero,
            ),
          ),
        ),
      );
    }

    return [
      marker(Alignment.topLeft),
      marker(Alignment.topRight),
      marker(Alignment.bottomLeft),
      marker(Alignment.bottomRight),
    ];
  }
}
