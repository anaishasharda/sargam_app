import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
//import 'package:sargam_app/feature/auth/login.dart';
//import 'package:sargam_app/feature/onboarding/onboarding.dart';
//import 'package:sargam_app/feature/auth/signup.dart';
import 'package:sargam_app/feature/navigation/main_navigation.dart';
import 'package:sargam_app/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sargam',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      //home: const OnboardingScreen(),
      //home: LoginScreen(),
      debugShowCheckedModeBanner: false,
      home: const MainNavigation(),
    );
  }
}
