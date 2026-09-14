import 'package:flutter/material.dart';
import 'onboarding_shell.dart';

class OnboardingChoicePage extends StatelessWidget {
  final double progress;
  final String title;
  final String subtitle;
  final List<String> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;
  final VoidCallback onNext;

  const OnboardingChoicePage({
    super.key,
    required this.progress,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      progress: progress,
      title: title,
      subtitle: subtitle,
      canContinue:
          selectedValue != null && selectedValue!.trim().isNotEmpty,
      onNext: onNext,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 8),

          ...options.map((option) {
            final selected = selectedValue == option;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => onSelected(option),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFE91E63)
                        : const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFE91E63)
                          : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF20242C),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? Colors.white
                              : Colors.transparent,
                          border: Border.all(
                            color: selected
                                ? Colors.white
                                : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check,
                                size: 17,
                                color: Color(0xFFE91E63),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}