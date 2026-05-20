import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants/app_colors.dart';
import '../services/ai_service.dart';
import '../services/scan_result_store.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const _handoffDelay = Duration(milliseconds: 450);

  String _status = 'Loading PlantVerse AI';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverOrContinue());
  }

  Future<void> _recoverOrContinue() async {
    final handoffDelay = Future<void>.delayed(_handoffDelay);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final picker = ImagePicker();
      try {
        final response = await picker.retrieveLostData();
        final image = response.file ??
            (response.files?.isNotEmpty == true ? response.files!.first : null);

        if (image != null) {
          setState(() => _status = 'Restoring your scan');
          final bytes = await image.readAsBytes();
          final result = await ref.read(aiServiceProvider).identifyPlant(
                imageBytes: bytes,
                fileName: image.name,
              );
          if (!mounted) return;
          ref.read(scanResultProvider.notifier).state = ScanResult(
            result: result,
            imageBytes: bytes,
          );
          await handoffDelay;
          if (!mounted) return;
          context.go('/plant_details');
          return;
        }
      } catch (_) {
        // Continue to home if there is no recoverable camera result.
      }
    }

    await handoffDelay;
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasDark,
      body: Center(
        child: Text(
          _status,
          style: TextStyle(
            color: AppColors.pureWhite.withOpacity(0.72),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
