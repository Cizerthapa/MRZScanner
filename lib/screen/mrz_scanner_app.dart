import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mrzreader/screen/selection_screen.dart';

class MRZScannerApp extends StatelessWidget {
  const MRZScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(393, 852),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'MRZ Passport Scanner',
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blueAccent,
              brightness: Brightness.dark,
            ),
            primaryColor: Colors.blueAccent,
            scaffoldBackgroundColor: const Color(0xFF0F172A),
          ),
          home: const SelectionScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
