import 'package:flutter/material.dart';

class OnboardingShell extends StatelessWidget {
  final double progress;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final bool canContinue;
  final String nextText;

  const OnboardingShell({
    super.key,
    required this.progress,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
    this.onNext,
    this.canContinue = true,
    this.nextText = 'Nästa',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: const Color(0xFFE9ECEF),
              color: const Color(0xFFFF4458),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: onBack ?? () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      iconSize: 34,
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    const SizedBox(height: 58),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                        letterSpacing: -1.2,
                        color: Color(0xFF20242C),
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 22,
                          height: 1.28,
                          color: Color(0xFF596273),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    const SizedBox(height: 36),
                    Expanded(child: child),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: canContinue ? onNext : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          disabledBackgroundColor: const Color(0xFFE9ECEF),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: const Color(0xFF8E96A3),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          nextText,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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
}