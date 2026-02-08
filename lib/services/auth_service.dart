class AuthService {
  Future<void> login({
    required String email,
    required String password,
  }) async {
    // Här kopplar vi backend/Firebase senare
    print('AuthService.login');
    print('Email: $email');
    print('Password: $password');
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    // Här kopplar vi backend/Firebase senare
    print('AuthService.register');
    print('Name: $name');
    print('Email: $email');
    print('Password: $password');
  }
}
