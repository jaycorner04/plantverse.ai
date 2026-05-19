import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/constants/app_colors.dart';
import '../core/routes/app_router.dart';
import '../services/ai_service.dart';
import '../services/app_update_service.dart';

class AppUpdateGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppUpdateGate({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiServiceProvider).warmBackend();
      _checkForUpdate();
    });
  }

  Future<void> _checkForUpdate() async {
    if (_checked) return;
    _checked = true;

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    try {
      final info = await ref.read(appUpdateServiceProvider).checkForUpdate();
      if (!mounted || info == null) return;
      await _showUpdateDialog(info);
    } catch (_) {
      // Update checks must never block app launch.
    }
  }

  Future<void> _showUpdateDialog(AppUpdateInfo info) {
    final service = ref.read(appUpdateServiceProvider);
    final notes = info.releaseNotes.take(3).toList(growable: false);
    final dialogContext = rootNavigatorKey.currentContext;
    if (dialogContext == null) return Future.value();

    return showDialog<void>(
      context: dialogContext,
      barrierDismissible: !info.forceUpdate,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.softBlack,
          icon: const Icon(
            LucideIcons.downloadCloud,
            color: AppColors.emeraldGreen,
          ),
          title: const Text(
            'PlantVerse update ready',
            style: TextStyle(color: AppColors.pureWhite),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Version ${info.latestVersionName} is available. Install it to get the newest plant fixes and offline data.',
                style: TextStyle(color: AppColors.pureWhite.withOpacity(0.78)),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final note in notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Icon(
                            LucideIcons.sparkles,
                            size: 13,
                            color: AppColors.emeraldGreen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            note,
                            style: TextStyle(
                              color: AppColors.pureWhite.withOpacity(0.72),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
          actions: [
            if (!info.forceUpdate)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Later',
                  style: TextStyle(color: AppColors.pureWhite.withOpacity(0.7)),
                ),
              ),
            FilledButton.icon(
              onPressed: () async {
                final opened = await service.openUpdate(info);
                if (!context.mounted) return;
                if (!opened) {
                  ScaffoldMessenger.maybeOf(dialogContext)?.showSnackBar(
                    SnackBar(
                      content: Text('Open this link: ${info.apkUrl}'),
                    ),
                  );
                  return;
                }
                if (!info.forceUpdate) Navigator.of(context).pop();
              },
              icon: const Icon(LucideIcons.download),
              label: const Text('Install update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
