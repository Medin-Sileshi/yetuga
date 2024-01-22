import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:yetuga/pages/auth/auth_page.dart';
import 'package:yetuga/pages/onboarding/page_one.dart';
import 'package:yetuga/pages/onboarding/page_three.dart';
import 'package:yetuga/pages/onboarding/page_two.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // controller to keep track of which page we're on
  final PageController _controller = PageController();
  final userdata = GetStorage();

  // keep track of if we are on the last page or not
  bool onLastPage = false;

  @override
  Widget build(BuildContext context) {
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
                });
              },
              children: const [
                PageOne(),
                PageTwo(),
                PageThree(),
              ],
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SmoothPageIndicator(
                    controller: _controller,
                    count: 3,
                    effect: const WormEffect(
                      type: WormType.thin,
                      dotColor: Color.fromARGB(255, 4, 50, 72),
                      activeDotColor: Color.fromARGB(255, 23, 207, 236),
                    ),
                  ),
                  const SizedBox(height: 70),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                          onTap: () {
                            userdata.write('isLogged', true);
                            Get.offAll(() => const AuthPage());
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                  color: Color.fromARGB(255, 23, 207, 236)),
                            ),
                          )),
                      Image.asset(
                        'assets/images/YetugaLogoWhite.png',
                        height: 60,
                      ),
                      onLastPage
                          ? GestureDetector(
                              onTap: () {
                                userdata.write('isLogged', true);
                                Get.offAll(() => const AuthPage());
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(10.0),
                                child: Text(
                                  'Done',
                                  style: TextStyle(
                                      color: Color.fromARGB(255, 23, 207, 236)),
                                ),
                              ))
                          : GestureDetector(
                              onTap: () {
                                _controller.nextPage(
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeIn,
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(11.0),
                                child: Text(
                                  'Next',
                                  style: TextStyle(
                                      color: Color.fromARGB(255, 23, 207, 236)),
                                ),
                              )),
                    ],
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
