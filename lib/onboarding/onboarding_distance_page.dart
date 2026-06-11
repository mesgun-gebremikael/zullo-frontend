import 'package:flutter/material.dart';
import 'onboarding_data.dart';
import 'onboarding_bio_page.dart';
import 'onboarding_lifestyle_page.dart';

class OnboardingDistancePage extends StatefulWidget {
 final OnboardingData data;

  const OnboardingDistancePage({
    super.key,
    required this.data,
  });

  @override
  State<OnboardingDistancePage> createState() =>
      _OnboardingDistancePageState();
}

class _OnboardingDistancePageState
    extends State<OnboardingDistancePage> {
  double _distanceKm = 80;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LinearProgressIndicator(
                value: 0.45,
                minHeight: 4,
                color: Color(0xFFFF4458),
                backgroundColor: Color(0xFFE8E8E8),
              ),

              const SizedBox(height: 18),

              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new),
              ),

              const SizedBox(height: 20),

              const Text(
                "Vad är din avståndspreferens?",
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF20242C),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Använd reglaget för att välja hur långt bort personer får vara.",
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF667085),
                ),
              ),

              const SizedBox(height: 70),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Avstånd",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    "${_distanceKm.round()} km",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Slider(
                value: _distanceKm,
                min: 5,
                max: 300,
                activeColor: const Color(0xFFFF4458),
                onChanged: (value) {
                  setState(() {
                    _distanceKm = value;
                  });
                },
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(40),
                    ),
                  ),
                  onPressed: () {
  widget.data.distanceKm = _distanceKm.round();

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => OnboardingLifestylePage(data: widget.data),
    ),
  );
},
                  child: const Text(
                    "Nästa",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}