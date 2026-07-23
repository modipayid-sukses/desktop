import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Toast ringan berbasis overlay GetX, aman dipakai di semua platform
/// (Android, iOS, Web, macOS, Windows, Linux) tanpa bergantung pada
/// method channel native seperti package `fluttertoast` (yang tidak
/// punya implementasi untuk desktop).
void showToast({required String msg}) {
  Get.rawSnackbar(
    messageText: Text(
      msg,
      style: const TextStyle(color: Colors.white, fontSize: 14),
    ),
    backgroundColor: Colors.black87,
    borderRadius: 8,
    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    duration: const Duration(seconds: 2),
    snackPosition: SnackPosition.BOTTOM,
    animationDuration: const Duration(milliseconds: 200),
  );
}
