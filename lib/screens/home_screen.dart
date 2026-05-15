import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../animations/staggered_reveal.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_container.dart';
import '../widgets/immersive_background.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasDark,
      body: ImmersiveBackground(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverSafeArea(
              sliver: SliverToBoxAdapter(
                child: StaggeredReveal(
                  delay: 80.ms,
                  children: [
                    _topBar(context),
                    _hero(context),
                    _scanExperience(context),
                    _toolGrid(context),
                    const SizedBox(height: 126),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: GlassContainer(
        blur: 24,
        opacity: 0.08,
        borderRadius: BorderRadius.circular(999),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.emeraldGreen, AppColors.aiGlow],
                ),
              ),
              child: const Icon(
                LucideIcons.leaf,
                color: AppColors.canvasDark,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'PlantVerse AI',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            _topIcon(LucideIcons.search),
            const SizedBox(width: 8),
            _topIcon(LucideIcons.sparkles),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width > 760 ? 72.0 : 48.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
      child: Column(
        children: [
          _capsule('AI nature operating system', LucideIcons.bot)
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .shimmer(
                duration: 2400.ms,
                color: AppColors.aiGlow.withOpacity(0.28),
              ),
          const SizedBox(height: 18),
          Text(
            'Scan life.\nUnderstand nature.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.pureWhite,
              fontSize: titleSize,
              height: 0.98,
              fontWeight: FontWeight.w800,
              letterSpacing: -2,
            ),
          ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.16, end: 0),
          const SizedBox(height: 18),
          Text(
            'Identify plants, read care signals, and turn every leaf into a living AI profile with cinematic guidance.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.pureWhite.withOpacity(0.68),
              fontSize: 17,
              height: 1.55,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 26),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _primaryPill(
                icon: LucideIcons.imagePlus,
                label: 'Scan Image',
                onPressed: () => context.push('/scanner'),
              ),
              _ghostPill(
                icon: LucideIcons.messageCircle,
                label: 'Ask AI',
                onPressed: () => context.push('/ai_chatbot'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _heroImageCard(),
        ],
      ),
    );
  }

  Widget _heroImageCard() {
    return GlassContainer(
      height: 340,
      width: double.infinity,
      blur: 22,
      opacity: 0.06,
      borderRadius: BorderRadius.circular(32),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.pureWhite.withOpacity(0.08),
          AppColors.emeraldGreen.withOpacity(0.05),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Image.network(
              'https://images.unsplash.com/photo-1614594975525-e45190c55d0b?auto=format&fit=crop&q=90&w=1200',
              fit: BoxFit.cover,
            )
                .animate(
                    onPlay: (controller) => controller.repeat(reverse: true))
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.045, 1.045),
                  duration: 5200.ms,
                  curve: Curves.easeInOut,
                ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.canvasDark.withOpacity(0.76),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 18,
            child: _confidenceBadge(),
          ),
          Positioned(
            right: 26,
            bottom: 34,
            child: _scanPulse(),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 22,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Live botanical intelligence, tuned for home growers.',
                    style: TextStyle(
                      color: AppColors.pureWhite.withOpacity(0.88),
                      fontSize: 16,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 70),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanExperience(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      child: GlassContainer(
        blur: 24,
        opacity: 0.08,
        borderRadius: BorderRadius.circular(28),
        padding: const EdgeInsets.all(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.pureWhite.withOpacity(0.08),
            AppColors.emeraldGreen.withOpacity(0.06),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _glowIcon(LucideIcons.scanLine),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'AI scan chamber',
                    style: TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Capture leaves, stems, and texture. PlantVerse builds a care profile, air exchange estimate, origin story, and confidence map.',
              style: TextStyle(
                color: AppColors.pureWhite.withOpacity(0.66),
                fontSize: 15,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 20),
            _primaryPill(
              icon: LucideIcons.imagePlus,
              label: 'Scan Image',
              onPressed: () => context.push('/scanner'),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.12, end: 0),
    );
  }

  Widget _toolGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _toolCard(
                  title: 'Doctor',
                  value: 'Disease lens',
                  icon: LucideIcons.stethoscope,
                  onTap: () => context.push('/ai_doctor'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _toolCard(
                  title: 'Assistant',
                  value: 'Care chat',
                  icon: LucideIcons.sparkles,
                  onTap: () => context.push('/ai_chatbot'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GlassContainer(
            blur: 22,
            opacity: 0.07,
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _glowIcon(LucideIcons.wind),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Air exchange ready',
                        style: TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Each scan now explains oxygen output, intake, and release.',
                        style: TextStyle(
                          color: AppColors.pureWhite.withOpacity(0.58),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolCard({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        height: 176,
        blur: 22,
        opacity: 0.07,
        borderRadius: BorderRadius.circular(28),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _glowIcon(icon),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.pureWhite.withOpacity(0.48),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                height: 1.08,
                fontWeight: FontWeight.w800,
                color: AppColors.pureWhite,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ).animate().scale(
            begin: const Offset(0.98, 0.98),
            end: const Offset(1, 1),
            duration: 500.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }

  Widget _primaryPill({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.emeraldGreen,
        foregroundColor: AppColors.pureWhite,
        elevation: 0,
        shadowColor: AppColors.emeraldGreen.withOpacity(0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    ).animate().boxShadow(
          begin: BoxShadow(
            color: AppColors.emeraldGreen.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          end: BoxShadow(
            color: AppColors.emeraldGreen.withOpacity(0.34),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
          duration: 900.ms,
        );
  }

  Widget _ghostPill({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.pureWhite,
        side: BorderSide(color: AppColors.pureWhite.withOpacity(0.14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        backgroundColor: AppColors.pureWhite.withOpacity(0.06),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }

  Widget _topIcon(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.pureWhite.withOpacity(0.08),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.pureWhite.withOpacity(0.08)),
      ),
      child: Icon(icon, color: AppColors.pureWhite.withOpacity(0.82), size: 18),
    );
  }

  Widget _capsule(String label, IconData icon) {
    return GlassContainer(
      blur: 18,
      opacity: 0.08,
      borderRadius: BorderRadius.circular(999),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.aiGlow, size: 15),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.pureWhite,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _confidenceBadge() {
    return GlassContainer(
      blur: 18,
      opacity: 0.12,
      borderRadius: BorderRadius.circular(999),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.activity, color: AppColors.aiGlow, size: 16),
          SizedBox(width: 8),
          Text(
            'AI confidence live',
            style: TextStyle(
              color: AppColors.pureWhite,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanPulse() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.aiGlow.withOpacity(0.24)),
          ),
        )
            .animate(onPlay: (controller) => controller.repeat())
            .scale(
              begin: const Offset(0.78, 0.78),
              end: const Offset(1.22, 1.22),
              duration: 1600.ms,
            )
            .fadeOut(duration: 1600.ms),
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.emeraldGreen,
            boxShadow: [
              BoxShadow(
                color: AppColors.emeraldGreen.withOpacity(0.42),
                blurRadius: 28,
              ),
            ],
          ),
          child: const Icon(
            LucideIcons.scanLine,
            color: AppColors.pureWhite,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _glowIcon(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.emeraldGreen.withOpacity(0.14),
        boxShadow: [
          BoxShadow(
            color: AppColors.emeraldGreen.withOpacity(0.22),
            blurRadius: 24,
          ),
        ],
      ),
      child: Icon(icon, color: AppColors.aiGlow, size: 22),
    );
  }
}
