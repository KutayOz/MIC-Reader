import 'package:flutter/material.dart';

/// App color palette based on planning.md
class AppColors {
  AppColors._();

  // Primary colors
  static const Color primary = Color(0xFF6366F1);      // Indigo - Main actions, headers
  static const Color secondary = Color(0xFFEC4899);    // Pink - Growth indicator

  // Status colors
  static const Color success = Color(0xFF10B981);      // Green - Susceptible (S)
  static const Color warning = Color(0xFFF59E0B);      // Amber - Intermediate (I), Uncertain
  static const Color danger = Color(0xFFEF4444);       // Red - Resistant (R)

  // Plate indicators
  static const Color growth = Color(0xFFEC4899);       // Pink - Growth (same as secondary)
  static const Color inhibition = Color(0xFF8B5CF6);   // Violet - Inhibition indicator

  // Neutral colors
  static const Color background = Color(0xFFF8FAFC);   // Light gray
  static const Color surface = Color(0xFFFFFFFF);      // White
  static const Color text = Color(0xFF0F172A);         // Dark slate
  static const Color textSecondary = Color(0xFF64748B); // Gray

  // Additional
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFE2E8F0);
}
