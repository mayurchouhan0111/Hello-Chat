import 'package:flutter/material.dart';

class AppBorderRadius {
  static const double sm    = 8.0;
  static const double md    = 12.0;
  static const double lg    = 16.0;
  static const double xl    = 20.0;
  static const double xxl   = 24.0;
  static const double pill  = 999.0;

  static BorderRadius get small  => BorderRadius.circular(sm);
  static BorderRadius get medium => BorderRadius.circular(md);
  static BorderRadius get large  => BorderRadius.circular(lg);
  static BorderRadius get xLarge => BorderRadius.circular(xl);
  static BorderRadius get xxLarge=> BorderRadius.circular(xxl);
  static BorderRadius get circle => BorderRadius.circular(pill);
}
