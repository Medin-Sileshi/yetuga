import 'package:flutter/material.dart';

class ProfilePicture extends StatelessWidget {
  const ProfilePicture({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          const Text(
            'Now Let\'s Get \nYour Best Shots',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color.fromARGB(255, 23, 207, 236),
              fontSize: 50,
              fontWeight: FontWeight.w200,
            ),
          ),
          const SizedBox(height: 100),
          Container(
            height: 250,
            width: 250,
            decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(200),
                color: const Color.fromARGB(100, 187, 187, 187)),
            child: Center(
                child: Icon(
              Icons.add,
              size: 50,
              color: Colors.grey.shade300,
            )),
          )
        ],
      ),
    );
  }
}
