import 'package:flutter/material.dart';

class PageThree extends StatelessWidget {
  const PageThree({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          const Text(
            'Let\'s Make \nSome Friends.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color.fromARGB(255, 23, 207, 236),
              fontSize: 50,
              fontWeight: FontWeight.w200,
            ),
          ),
          const SizedBox(height: 100),
          Image.asset(
            'assets/images/Friends.png',
            height: 200,
          )
        ],
      ),
    );
  }
}
