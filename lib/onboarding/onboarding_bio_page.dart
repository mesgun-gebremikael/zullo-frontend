import 'package:flutter/material.dart';

class OnboardingBioPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const OnboardingBioPage({
    super.key,
    required this.data,
  });

  @override
  State<OnboardingBioPage> createState() =>
      _OnboardingBioPageState();
}

class _OnboardingBioPageState
    extends State<OnboardingBioPage> {
  final _bioController = TextEditingController();

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
                value: 0.80,
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
                "Berätta mer om dig själv",
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF20242C),
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                "Skriv något som gör att andra lär känna dig bättre.",
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF667085),
                ),
              ),

              const SizedBox(height: 28),

              Expanded(
                child: TextField(
                  controller: _bioController,
                  maxLines: null,
                  expands: true,
                  decoration: InputDecoration(
                    hintText: "Exempel: Jag älskar resor, kaffe och långa promenader...",
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

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