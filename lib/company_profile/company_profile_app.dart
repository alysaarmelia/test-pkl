import 'package:flutter/material.dart';

import 'pages/home_page.dart';

class CompanyProfileApp extends StatelessWidget {
  const CompanyProfileApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1C63FF),
      brightness: Brightness.dark,
      primary: const Color(0xFF5C9DFF),
      secondary: const Color(0xFF7B61FF),
    );

    return MaterialApp(
      title: 'Cipta Vera Mandiri Digital',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF050B18),
        textTheme: Typography.whiteCupertino.apply(
          fontFamily: 'SF Pro Display',
          displayColor: Colors.white,
          bodyColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const CompanyHomePage(),
    );
  }
}
