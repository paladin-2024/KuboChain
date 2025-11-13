import 'package:flutter/material.dart';
import 'package:kubochain/screens/intro_screens/intro_page_1.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'intro_screens/intro_page_2.dart';
import 'intro_screens/intro_page_3.dart';
import 'onboarding.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});
  @override
  _OnBoardingScreenState createState() => _OnBoardingScreenState();
}
class _OnBoardingScreenState extends State<OnBoardingScreen> {

  // controller to  keep track of which page we're on
  PageController _controller= PageController();

  // keep track of whether we're on the last page or not

  bool onLastPage= false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
          children: [
            // page view
            PageView(
              controller: _controller,
              onPageChanged: (index){
                setState(() {
                  onLastPage = (index==2);
                });
              },
              children: [
                IntroPage1(),
                IntroPage2(),
                IntroPage3(),
              ],
            ),

            // Skip button - top right
            Positioned(
              top: 68,
              right: 25,
              child: GestureDetector(
                onTap: (){
                  _controller.jumpToPage(2);
                },
                child: Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

            // Bottom section with indicators and button - positioned 10px from bottom
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // dash indicators
                  SmoothPageIndicator(
                    controller: _controller,
                    count: 3,
                    effect: CustomizableEffect(
                      activeDotDecoration: DotDecoration(
                        width: 24,
                        height: 4,
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      dotDecoration: DotDecoration(
                        width: 24,
                        height: 4,
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(2),
                        verticalOffset: 0,
                      ),
                      spacing: 8.0,
                    ),
                  ),

                  SizedBox(height: 20),

                  // next or get started button - full width
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(horizontal: 40),
                    child: onLastPage ?
                    GestureDetector(
                      onTap: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context){
                          return OnBoardingPage();
                        }));
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(100), // Changed to 100 for pill shape
                        ),
                        child: Center(
                          child: Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 17,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                        ),
                      ),
                    )
                        : GestureDetector(
                      onTap: (){
                        _controller.nextPage(
                          duration: Duration(milliseconds: 500),
                          curve: Curves.easeIn,
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(100), // Changed to 100 for pill shape
                        ),
                        child: Center(
                          child: Text(
                            'Next',
                            style: TextStyle(
                              fontSize: 17,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            )
          ],
        )
    );
  }
}