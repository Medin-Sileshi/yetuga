import 'package:flutter/cupertino.dart';

class AgeInput extends StatefulWidget {
  const AgeInput({super.key});

  @override
  State<AgeInput> createState() => _AgeInputState();
}

class _AgeInputState extends State<AgeInput> {
  DateTime dateTime = DateTime.now();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          const Text(
            'When Is \nYour Birthday?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color.fromARGB(255, 23, 207, 236),
              fontSize: 50,
              fontWeight: FontWeight.w200,
            ),
          ),
          const SizedBox(height: 150),
          buildDatePicker(),
        ],
      ),
    );
  }

  Widget buildDatePicker() => SizedBox(
        height: 200,
        child: CupertinoDatePicker(
          minimumYear: 1950,
          maximumYear: DateTime.now().year,
          initialDateTime: dateTime,
          mode: CupertinoDatePickerMode.date,
          onDateTimeChanged: (dateTime) =>
              setState(() => this.dateTime = dateTime),
        ),
      );
}
