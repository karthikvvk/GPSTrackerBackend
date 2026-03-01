import 'package:flutter/material.dart';

class AppMotion {
  static const Duration page = Duration(milliseconds: 260);
  static const Curve curve = Curves.easeOutCubic;

  static Widget fadeSlide(Widget child, Animation<double> animation) {
    final offsetAnimation = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: curve));
    return FadeTransition(opacity: animation, child: SlideTransition(position: offsetAnimation, child: child));
  }
}
