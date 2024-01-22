import 'package:flutter/material.dart';

class MyTextField extends StatelessWidget {
  final String hintText;
  final bool obscureText;
  final TextEditingController controller;

  const MyTextField({
    super.key,
    required this.hintText,
    required this.obscureText,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 0),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        cursorColor: Colors.grey.shade400,
        decoration: InputDecoration(
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(
              width: 1,
              color: Colors.grey,
            ),
          ),
          hintText: hintText,
          hintStyle: const TextStyle(
              color: Color.fromARGB(100, 179, 179, 179),
              fontSize: 26,
              fontWeight: FontWeight.w200),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(
              width: 1,
              color: Color.fromARGB(255, 23, 207, 236),
            ),
          ),
        ),
      ),
    );
  }
}
