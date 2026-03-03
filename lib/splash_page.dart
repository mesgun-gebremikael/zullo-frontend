import 'package:flutter/material.dart';
import 'services/auth_storage.dart';
import 'home_page.dart';
import 'welcome_page.dart';
import 'services/auth_service.dart';
import 'create_profile_page.dart';


class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final AuthStorage _storage = AuthStorage();

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

 Future<void> _checkLogin() async {
  await Future.delayed(const Duration(seconds: 2));

  final token = await _storage.getToken();
  final AuthService _authService = AuthService();

  if (!mounted) return;

  if (token == null) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
    );
    return;
  }

  // token finns → kolla om profil finns
  final exists = await _authService.hasProfile();

  if (!mounted) return;

  if (exists) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  } else {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CreateProfilePage()),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'ZULLO',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
