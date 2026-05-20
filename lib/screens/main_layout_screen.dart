import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/lucide_compat.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_container.dart';

class MainLayoutScreen extends StatelessWidget {
  final Widget child;
  const MainLayoutScreen({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/ai_doctor')) return 1;
    if (location.startsWith('/garden')) return 2;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/ai_doctor');
        break;
      case 2:
        // context.go('/garden');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.canvasDark,
      body: child,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: GlassContainer(
            opacity: 0.08,
            blur: 26,
            borderRadius: BorderRadius.circular(999),
            color: AppColors.pureWhite,
            border: Border.all(color: AppColors.pureWhite.withOpacity(0.10)),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                    context, 0, currentIndex, LucideIcons.home, 'Home'),
                _buildNavItem(context, 1, currentIndex, LucideIcons.stethoscope,
                    'Doctor'),
                const SizedBox(width: 112), // Space for scan image button
                _buildNavItem(
                    context, 2, currentIndex, LucideIcons.flower2, 'Garden'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/scanner'),
        elevation: 0,
        backgroundColor: AppColors.emeraldGreen,
        foregroundColor: AppColors.pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        icon: const Icon(
          LucideIcons.imagePlus,
          color: AppColors.pureWhite,
          size: 22,
        ),
        label: const Text(
          'Scan Image',
          style: TextStyle(
            color: AppColors.pureWhite,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildNavItem(BuildContext context, int index, int currentIndex,
      IconData icon, String label) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index, context),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lightGreen : Colors.transparent,
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppColors.emeraldGreen.withOpacity(0.22),
                    AppColors.aiGlow.withOpacity(0.10),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(
          icon,
          color: isSelected
              ? AppColors.aiGlow
              : AppColors.pureWhite.withOpacity(0.42),
          size: 24,
        ),
      ),
    );
  }
}
