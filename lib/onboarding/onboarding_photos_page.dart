import 'package:flutter/material.dart';

class OnboardingPhotosPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const OnboardingPhotosPage({
    super.key,
    required this.data,
  });

  @override
  State<OnboardingPhotosPage> createState() =>
      _OnboardingPhotosPageState();
}

class _OnboardingPhotosPageState
    extends State<OnboardingPhotosPage> {
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
                value: 0.60,
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
                "Lägg till dina bilder",
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF20242C),
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                "Minst 2 bilder krävs för att använda ZULLO.",
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF667085),
                ),
              ),

              const SizedBox(height: 30),

              Expanded(
                child: GridView.builder(
                  itemCount: 6,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius:
                            BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFD0D5DD),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add,
                          size: 34,
                          color: Color(0xFFFF4458),
                        ),
                      ),
                    );
                  },
                ),
              ),

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
                  onPressed: () {},
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