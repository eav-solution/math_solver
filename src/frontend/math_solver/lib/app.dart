import 'package:flutter/material.dart';
import 'package:math_solver/src/features/history/presentation/history_page.dart';
import 'src/widgets/bottom_nav_bar.dart';
import 'src/features/home/presentation/home_page.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _index = 0;

  static const _screens = [HomePage(), HistoryPage()];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tabs',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: _screens[_index],
        bottomNavigationBar: BottomNavBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}
