// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:yetuga/pages/registration_forms/phone_number_input.dart';
// import 'package:yetuga/theme/dark_mode.dart';
// import 'package:yetuga/theme/light_mode.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';

// void main() async {
//   SystemChrome.setSystemUIOverlayStyle(
//     const SystemUiOverlayStyle(
//       statusBarColor: Colors.transparent,
//       systemNavigationBarColor: Color.fromARGB(255, 0, 24, 43),
//     ),
//   );
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );

//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       theme: lightMode,
//       darkTheme: darkMode,
//       home: PhoneNumber(),
//     );
//   }
// }
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import "package:get_storage/get_storage.dart";
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yetuga/firebase_options.dart';
import 'package:yetuga/pages/onboarding/onboarding_screen.dart';
import 'package:yetuga/pages/splash_screen/splash_screen.dart';
import 'package:yetuga/theme/dark_mode.dart';
import 'package:yetuga/theme/light_mode.dart';

void main() async {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await GetStorage.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter Demo',
        theme: lightMode,
        darkTheme: darkMode,
        home: const HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final userdate = GetStorage();

  @override
  void initState() {
    super.initState();

    userdate.writeIfNull('isLogged', false);

    Future.delayed(Duration.zero, () async {
      checkiflogged();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void checkiflogged() {
    userdate.read('isLogged')
        ? Get.offAll(() => const SplashScreen())
        : Get.offAll(() => const OnboardingScreen());
  }
}
