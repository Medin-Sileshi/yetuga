import 'package:flutter/material.dart';

class MyButton extends StatelessWidget {
  final String text;
  const MyButton({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      width: 150,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [
          Color(0xFF17CDEC),
          Color(0xFF0771BF),
        ]),
        borderRadius: BorderRadius.circular(42),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
              color: Color(0xff00263C),
              fontSize: 30,
              fontWeight: FontWeight.w300),
        ),
      ),
    );
  }
}
