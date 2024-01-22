import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yetuga/components/my_button.dart';
import 'package:yetuga/home.dart';
import 'package:yetuga/model/user_model.dart';
import 'package:yetuga/pages/registration_forms/Screens/name_input.dart';
import 'package:yetuga/services/auth_service.dart';
import 'package:yetuga/services/database_services.dart';
import 'package:yetuga/utils/utils.dart';

class InputForms extends StatefulWidget {
  const InputForms({super.key});

  @override
  State<InputForms> createState() => _InputFormsState();
}

class _InputFormsState extends State<InputForms> {
  File? image;
  final FirestoreServices firestoreServices = FirestoreServices();
  final PageController _controller = PageController();
  TextEditingController nameController = TextEditingController();
  DateTime dateTime = DateTime.now();
  bool onLastPage = false;
  bool onFirstPage = false;

  @override
  void dispose() {
    super.dispose();
    nameController.dispose();
  }

  // select an image
  void selectImage() async {
    image = await pickImage(context);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // final isLoading =
    // Provider.of<AuthServices>(context, listen: false).isLoading;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _controller,
              onPageChanged: (index) {
                setState(() {
                  onLastPage = (index == 2);
                  onFirstPage = (index == 0);
                });
              },
              physics: const NeverScrollableScrollPhysics(),
              children: [
                NameInput(
                  nameController: nameController,
                ),
                // const AgeInput(),
                Center(
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
                ),
                // const ProfilePicture(),
                Center(
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
                      GestureDetector(
                        onTap: () => selectImage(),
                        child: image == null
                            ? const CircleAvatar(
                                backgroundColor:
                                    Color.fromARGB(100, 187, 187, 187),
                                radius: 120,
                                child: Icon(
                                  Icons.add,
                                  size: 100,
                                  color: Color.fromARGB(100, 255, 255, 255),
                                ),
                              )
                            : CircleAvatar(
                                backgroundImage: FileImage(image!),
                                radius: 120,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            onFirstPage
                ? Container()
                : GestureDetector(
                    onTap: () {
                      _controller.previousPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeIn,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Image.asset(
                        'assets/images/Back.png',
                        height: 35,
                      ),
                    )),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    onLastPage
                        ? GestureDetector(
                            onTap: () {
                              // firestoreServices.addUserDetails(
                              //     nameController.text.trim(), dateTime);
                              storeData();
                              // clear the txt controller
                              nameController.clear();
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(10.0),
                              child: MyButton(
                                text: 'DONE',
                              ),
                            ))
                        : GestureDetector(
                            onTap: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              _controller.nextPage(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeIn,
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(11.0),
                              child: MyButton(
                                text: 'NEXT',
                              ),
                            )),
                  ],
                ),
                const SizedBox(height: 50)
              ],
            )
          ],
        ),
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

  void storeData() async {
    final ap = Provider.of<AuthServices>(context, listen: false);
    UserModel userModel = UserModel(
      userName: nameController.text.trim(),
      birthDay: dateTime,
      profilePic: "",
      uid: "",
    );
    if (image != null) {
      ap.saveUserDataToFirebase(
        context: context,
        userModel: userModel,
        profilepic: image!,
        onSuccess: () {
          ap.saveUserDataToSP().then(
                (value) => ap.setSignIn().then(
                      (value) => Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomePage(),
                          ),
                          (route) => false),
                    ),
              );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please Upload an Image First"),
        ),
      );
    }
  }
}
