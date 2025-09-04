// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:webview_flutter/webview_flutter.dart';
// import 'package:share_plus/share_plus.dart';
//
// void main() {
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Market Guru HP',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: WebViewScreen(),
//     );
//   }
// }
//
// class WebViewScreen extends StatefulWidget {
//   const WebViewScreen({super.key});
//
//   @override
//   _WebViewScreenState createState() => _WebViewScreenState();
// }
//
// class _WebViewScreenState extends State<WebViewScreen> {
//   late final WebViewController controller;
//   bool isLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//
//     // Set the status bar color (white with dark icons, can be adjusted)
//     SystemChrome.setSystemUIOverlayStyle(
//       SystemUiOverlayStyle(
//         statusBarColor: Colors.white, // Change to Colors.transparent if you want transparent
//         statusBarIconBrightness: Brightness.dark,
//       ),
//     );
//
//     controller = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..addJavaScriptChannel(
//         'ShareChannel',
//         onMessageReceived: (JavaScriptMessage message) {
//           Share.share(message.message);
//         },
//       )
//       ..setNavigationDelegate(
//         NavigationDelegate(
//           onPageStarted: (String url) {
//             setState(() {
//               isLoading = true;
//             });
//           },
//           onPageFinished: (String url) {
//             setState(() {
//               isLoading = false;
//             });
//           },
//           onWebResourceError: (WebResourceError error) {
//             print('WebView error: ${error.description}');
//           },
//         ),
//       )
//       ..loadRequest(Uri.parse('https://marketguruhp.com'));
//   }
//
//   Future<bool> _onWillPop() async {
//     if (await controller.canGoBack()) {
//       controller.goBack();
//       return false;
//     }
//     return true;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return WillPopScope(
//       onWillPop: _onWillPop,
//       child: Scaffold(
//         body: Stack(
//           children: [
//             // The key fix: wrap WebView in SafeArea!
//             SafeArea(
//               child: WebViewWidget(controller: controller),
//             ),
//             if (isLoading)
//               Center(
//                 child: CircularProgressIndicator(),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Market Guru HP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SplashScreen(),
    );
  }
}

// SplashScreen - Just animation/branding, NO WebViewController!
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _rotateController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();

    // Status bar for splash: white icons on black
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    _scaleController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _rotateController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _rotateAnimation = Tween<double>(begin: 0, end: 2 * 3.14159)
        .animate(CurvedAnimation(parent: _rotateController, curve: Curves.linear));

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(Duration(milliseconds: 200));
    _fadeController.forward();
    _scaleController.forward();
    _rotateController.repeat();
    await Future.delayed(Duration(milliseconds: 600));
    _slideController.forward();

    // Splash duration
    await Future.delayed(Duration(milliseconds: 2000));

    // Navigate to WebViewScreen (do NOT pass any controller)
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              WebViewScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              Colors.grey.shade900,
              Colors.black,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
              AnimatedBuilder(
                animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow
                          Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          // Logo
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 10,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/Media.jpeg',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.white,
                                    child: Icon(
                                      Icons.business,
                                      size: 80,
                                      color: Colors.black,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 50),
              // Animated Text
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        'MARKET GURU HP',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(
                              blurRadius: 10.0,
                              color: Colors.white.withOpacity(0.5),
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      // Container(
                      //   padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      //   decoration: BoxDecoration(
                      //     border: Border.all(color: Colors.white30),
                      //     borderRadius: BorderRadius.circular(20),
                      //   ),
                      //   child: Text(
                      //     'YOUR TRADING COMPANION',
                      //     style: TextStyle(
                      //       fontSize: 12,
                      //       color: Colors.white70,
                      //       letterSpacing: 2,
                      //       fontWeight: FontWeight.w300,
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 80),
              // Loading indicator
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _rotateAnimation,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _rotateAnimation.value,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.transparent,
                                      width: 3,
                                    ),
                                    gradient: SweepGradient(
                                      colors: [
                                        Colors.white,
                                        Colors.white10,
                                        Colors.white,
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black,
                              border: Border.all(
                                color: Colors.white24,
                                width: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: 300),
                        child: Text(
                          'LOADING',
                          key: ValueKey(true),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white60,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w200,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// WebViewScreen - Creates its own WebViewController, supports login!
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    // Set status bar for webview (black icons on white)
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ShareChannel',
        onMessageReceived: (JavaScriptMessage message) {
          Share.share(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => isLoading = true),
          onPageFinished: (_) => setState(() => isLoading = false),
          onWebResourceError: (_) => setState(() => isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse('https://marketguruhp.com'));
  }

  Future<bool> _onWillPop() async {
    if (await controller.canGoBack()) {
      controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            SafeArea(
              child: WebViewWidget(controller: controller),
            ),
            if (isLoading)
              Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

