import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/constants/app_colors.dart';
import '../services/ai_service.dart';
import '../services/scan_result_store.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String _status = 'AI Plant Identifier & Doctor';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverOrContinue());
  }

  Future<void> _recoverOrContinue() async {
    final picker = ImagePicker();
    try {
      final response = await picker.retrieveLostData();
      final image = response.file ??
          (response.files?.isNotEmpty == true ? response.files!.first : null);

      if (image != null) {
        setState(() => _status = 'Restoring your scan...');
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
        context.go('/plant_details');
        return;
      }
    } catch (_) {
      // Continue to home if there is no recoverable camera result.
    }

    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureWhite,
      body: Container(
        color: AppColors.pureWhite,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.offWhite,
                  border: Border.all(color: AppColors.hairline),
                ),
                child: const Icon(
                  LucideIcons.leaf,
                  size: 64,
                  color: AppColors.emeraldGreen,
                ),
              )
                  .animate()
                  .scale(duration: 800.ms, curve: Curves.easeOutBack)
                  .fadeIn(),
              const SizedBox(height: 24),
              const Text(
                'PlantVerse AI',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: AppColors.softBlack,
                  letterSpacing: -0.3,
                ),
              )
                  .animate()
                  .slideY(begin: 0.5, end: 0, duration: 600.ms, delay: 200.ms)
                  .fadeIn(delay: 200.ms),
              const SizedBox(height: 8),
              Text(
                _status,
                style: TextStyle(
                  fontSize: 17,
                  color: AppColors.softBlack.withOpacity(0.62),
                  letterSpacing: -0.2,
                ),
              )
                  .animate()
                  .slideY(begin: 0.5, end: 0, duration: 600.ms, delay: 400.ms)
                  .fadeIn(delay: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
