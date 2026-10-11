import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0F172A); // Slate 900
  static const surface = Color(0xFF1E293B); // Slate 800
  static const surfaceElevated = Color(0xFF334155); // Slate 700
  static const border = Color(0xFF334155); // Slate 700

  // Electric Mint / Green
  static const primary = Color(0xFF00E676);
  static const primaryVariant = Color(0xFF00C853);
  static const secondaryAccent = Color(
    0xFF3B82F6,
  ); // Electric Blue for contrast

  static const textPrimary = Color(0xFFF8FAFC); // Slate 50
  static const textSecondary = Color(0xFF94A3B8); // Slate 400

  // Feedback
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEE4444);

  // Gradients for deterministic routine covers
  static const coverPush = [
    Color(0xFFF97316),
    Color(0xFFEA580C),
  ]; // Vibrant Orange
  static const coverPull = [
    Color(0xFF3B82F6),
    Color(0xFF2563EB),
  ]; // Electric Blue
  static const coverLegs = [
    Color(0xFF00E676),
    Color(0xFF00C853),
  ]; // Electric Mint
  static const coverUpper = [Color(0xFFA855F7), Color(0xFF9333EA)]; // Purple
  static const coverLower = [Color(0xFF06B6D4), Color(0xFF0891B2)]; // Cyan
  static const coverDefault = [Color(0xFF475569), Color(0xFF334155)]; // Slate
}
