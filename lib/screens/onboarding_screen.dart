import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_container.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Identify Any Plant',
      'description':
          'Take a photo of any plant to instantly learn its name, species, and history using advanced AI.',
    },
    {
      'title': 'AI Plant Doctor',
      'description':
          'Is your plant sick? Scan the leaves to get instant disease diagnosis and treatment plans.',
    },
    {
      'title': 'Build Your Garden',
      'description':
          'Save your plants, set watering reminders, and watch them grow over time.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Stack(
        children: [
          Container(color: AppColors.offWhite),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GlassContainer(
                              width: 280,
                              height: 280,
                              opacity: 1,
                              color: index == 1
                                  ? AppColors.darkGrey
                                  : AppColors.pureWhite,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.hairline),
                              child: Center(
                                child: Icon(
                                  index == 0
                                      ? Icons.center_focus_strong_rounded
                                      : index == 1
                                          ? Icons.health_and_safety_rounded
                                          : Icons.local_florist_rounded,
                                  size: 96,
                                  color: index == 1
                                      ? AppColors.actionBlueOnDark
                                      : AppColors.emeraldGreen,
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 600.ms)
                                .slideY(begin: 0.2, end: 0),
                            const SizedBox(height: 64),
                            Text(
                              _pages[index]['title']!,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                color: AppColors.softBlack,
                                letterSpacing: -0.3,
                              ),
                              textAlign: TextAlign.center,
                            ).animate().fadeIn(delay: 200.ms),
                            const SizedBox(height: 16),
                            Text(
                              _pages[index]['description']!,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.softBlack.withOpacity(0.64),
                                height: 1.5,
                                letterSpacing: -0.2,
                              ),
                              textAlign: TextAlign.center,
                            ).animate().fadeIn(delay: 400.ms),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Navigation
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Dots indicator
                      Row(
                        children: List.generate(
                          _pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8),
                            height: 8,
                            width: _currentPage == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? AppColors.emeraldGreen
                                  : AppColors.hairline,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),

                      // Next / Get Started Button
                      ElevatedButton(
                        onPressed: () {
                          if (_currentPage == _pages.length - 1) {
                            context.go('/home');
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          _currentPage == _pages.length - 1
                              ? 'Get Started'
                              : 'Next',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
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
}
