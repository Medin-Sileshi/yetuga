import 'package:flutter/material.dart';
import 'package:yetuga/components/my_textfield.dart';

class NameInput extends StatelessWidget {
  final TextEditingController nameController;
  const NameInput({super.key, required this.nameController});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          const Text(
            'Your Nickname \nPlease...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color.fromARGB(255, 23, 207, 236),
              fontSize: 50,
              fontWeight: FontWeight.w200,
            ),
          ),
          const SizedBox(height: 150),
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 40, 0),
            child: MyTextField(
                hintText: 'Name',
                obscureText: false,
                controller: nameController),
          ),
        ],
      ),
    );
  }
}
