import 'package:flutter/material.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:go_router/go_router.dart';
import '../application/auth_view_model.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = getIt<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              onChanged: (v) => vm.email.value = v,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              onChanged: (v) => vm.password.value = v,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 20),
            Watch.builder(
              builder: (context) {
                final async = vm.user.value;
                if (async.isLoading) {
                  return const CircularProgressIndicator();
                } else if (async.hasError) {
                  return Text(
                    async.error.toString(),
                    style: const TextStyle(color: Colors.red),
                  );
                } else {
                  return ElevatedButton(
                    onPressed: vm.canSubmit
                        ? () async {
                            await vm.login();
                            // ignore: use_build_context_synchronously
                            context.go('/articles');
                          }
                        : null,
                    child: const Text('Login'),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
