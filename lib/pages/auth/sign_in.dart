import 'package:flutter/material.dart';
import 'package:yetuga/pages/auth/auth_page.dart';

class SignIn extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();

  SignIn({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const Text(
                'First Let\'s \nSign-In to Verify \nYour Account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color.fromARGB(255, 23, 207, 236),
                  fontSize: 50,
                  fontWeight: FontWeight.w200,
                ),
              ),
              Column(
                children: [
                  const Text(
                    'Sign-In With',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w200,
                      color: Color.fromARGB(255, 175, 175, 175),
                    ),
                  ),
                  const SizedBox(height: 50),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => const AuthPage(),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 0),
                          child: Image.asset(
                            'assets/images/Google.png',
                            height: 60,
                          ),
                        ),
                      ),
                      GestureDetector(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 0),
                          child: Image.asset(
                            'assets/images/Apple.png',
                            height: 60,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(
                        color: Color.fromARGB(255, 175, 175, 175), width: 0.5),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Text(
                    'Sign-In With Email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w200,
                      color: Color.fromARGB(255, 175, 175, 175),
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
