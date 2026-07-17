import 'package:flutter/material.dart';
import '../models/user.dart';
import 'ticket_screen.dart';
import 'qr_scanner_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  // Исправлено: использован lowerCamelCase
  static const String testLogin = '12345678';
  static const String testPassword = 'Иванов';

  void _handleQRScan(String scannedData) {
    String login = scannedData;

    if (scannedData.startsWith('LIBRARY:')) {
      final parts = scannedData.split(':');
      if (parts.length >= 2) {
        login = parts[1];
      }
    }

    if (login.length == 8 && RegExp(r'^\d+$').hasMatch(login)) {
      _loginController.text = login;
      _showAutoLoginDialog(login);
    } else {
      // Исправлено: сохранение контекста перед асинхронной операцией
      final context = this.context;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Неверный формат QR-кода: $scannedData'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showAutoLoginDialog(String login) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Найден читательский билет'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Был отсканирован QR-код с номером:'),
            const SizedBox(height: 8),
            Text(
              login,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Выполнить вход с этим номером?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performLogin(login);
            },
            child: const Text('Войти'),
          ),
        ],
      ),
    );
  }

  void _authenticate() {
    final login = _loginController.text.trim();
    final password = _passwordController.text.trim();

    if (login.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Заполните все поля';
      });
      return;
    }

    if (login.length != 8 || !RegExp(r'^\d+$').hasMatch(login)) {
      setState(() {
        _errorMessage = 'Логин должен состоять из 8 цифр';
      });
      return;
    }

    _performLogin(login);
  }

  void _performLogin(String login) {
    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 800), () {
      // Исправлено: проверка, что виджет все еще смонтирован
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TicketScreen(
            user: User(
              login: login,
              name: _getUserNameByLogin(login),
              qrData: 'LIBRARY:$login:${DateTime.now().millisecondsSinceEpoch}',
              validUntil: DateTime.now().add(const Duration(days: 365)),
            ),
          ),
        ),
      );
    });
  }

  String _getUserNameByLogin(String login) {
    if (login == testLogin) {
      return 'Иванов Иван Иванович';
    }
    return 'Пользователь $login';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2C3E50), Color(0xFF3498DB)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.library_books,
                    size: 60,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Читательский билет',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 40),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: TextField(
                      controller: _loginController,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      decoration: const InputDecoration(
                        labelText: 'Номер читательского билета',
                        hintText: '8 цифр',
                        border: InputBorder.none,
                        counterText: '',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      style: const TextStyle(fontSize: 16),
                      onChanged: (_) {
                        if (_errorMessage.isNotEmpty) {
                          setState(() => _errorMessage = '');
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Пароль',
                        hintText: 'Введите пароль',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      style: const TextStyle(fontSize: 16),
                      onChanged: (_) {
                        if (_errorMessage.isNotEmpty) {
                          setState(() => _errorMessage = '');
                        }
                      },
                      onSubmitted: (_) => _authenticate(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QRScannerScreen(
                                  onScanComplete: _handleQRScan,
                                ),
                              ),
                            );
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner),
                        SizedBox(width: 8),
                        Text(
                          'СКАНИРОВАТЬ QR-КОД',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 30),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _authenticate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2C3E50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF2C3E50),
                              ),
                            ),
                          )
                        : const Text(
                            'ВОЙТИ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          _loginController.text = testLogin;
                          _passwordController.text = testPassword;
                          _authenticate();
                        },
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text(
                    'Быстрый вход (тестовые данные)',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
