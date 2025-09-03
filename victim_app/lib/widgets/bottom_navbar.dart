import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';

class Bottom_NavBar extends StatelessWidget {
  final int indexx;
  const Bottom_NavBar({super.key, required this.indexx});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CurvedNavigationBar(
      height: 70,
      color: Colors.green,
      buttonBackgroundColor: Colors.green,
      index: indexx,
      backgroundColor: isDark ? Colors.black : (Colors.grey[50] ?? Colors.grey),
      items: <Widget>[
        Icon(Icons.home_rounded, size: 30),
        Icon(Icons.favorite_outline, size: 30,),
        Icon(Icons.search, size: 30),
        Icon(Icons.notifications_active_sharp, size: 30),
        Icon(Icons.account_circle_outlined, size: 30),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            if (indexx == index) {
            } else {
              Navigator.pushNamedAndRemoveUntil(
                  context, "/Home", ModalRoute.withName('/Home'));
            }
            break;
          case 1:
            print("$index == $indexx");
            if (indexx == index) {
            } else {
              Navigator.pushNamedAndRemoveUntil(
                  context, "/favourites", ModalRoute.withName('/Home'));
            }

            break;
          case 2:
            if (indexx == index) {
            } else {
              Navigator.pushNamedAndRemoveUntil(
                  context, "/TypeGrid", ModalRoute.withName('/Home'));
            }

            break;
          case 3:
            if (indexx == index) {
            } else {
              Navigator.pushNamedAndRemoveUntil(
                  context, "/Requests", ModalRoute.withName('/Home'));
            }

            break;
          case 4:
            if (indexx == index) {
            } else {
              Navigator.pushNamedAndRemoveUntil(
                  context, "/editHirer", ModalRoute.withName('/Home'));
            }

            break;
        }
        print("Clicked+" + index.toString());
      },
    );
   
  }
}