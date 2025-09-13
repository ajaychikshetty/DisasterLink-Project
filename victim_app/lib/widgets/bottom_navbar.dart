import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Bottom_NavBar extends StatelessWidget {
  final int indexx;
  const Bottom_NavBar({super.key, required this.indexx});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CurvedNavigationBar(
      height: 65,
      color: Colors.green,
      buttonBackgroundColor: Colors.green,
      index: indexx,
      backgroundColor: isDark ? Colors.black : (Colors.grey[50] ?? Colors.grey),
      items: const <Widget>[
        Icon(Icons.home_rounded, size: 30),
        Icon(Icons.night_shelter_sharp, size: 30),
        Icon(Icons.report, size: 30,),
        Icon(Icons.notifications_active_sharp, size: 30),
        Icon(Icons.account_circle_outlined, size: 30),
      ],
      onTap: (index) {
        if (index == indexx) return; 

        switch (index) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/shelter');
            break;
          case 2:
            context.go('/report');
            break;
          case 3:
            context.go('/notifications');
            break;
          case 4:
            context.go('/profile');
            break;
        }
      },
    );
  }
}
