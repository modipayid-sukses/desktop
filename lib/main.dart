import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:modipay/splashscreen.dart';
import 'package:modipay/utils/colornotifire.dart';
import 'package:modipay/utils/color.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/services/device_identity_service.dart';
import 'package:modipay/services/notification_service.dart';
import 'package:modipay/services/pending_ppob_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

/// Ukuran minimum window desktop: Full HD (1920x1080).
const Size _minDesktopWindowSize = Size(1920, 1080);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: _minDesktopWindowSize,
      minimumSize: _minDesktopWindowSize,
      center: true,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }
  await initializeDateFormatting('id_ID', null);
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Notification init failed: $e');
  }
  try {
    await DeviceIdentityService.initialize();
  } catch (e) {
    debugPrint('Device identity init failed: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ColorNotifire(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider.value(
          value: PendingPpobService.instance,
        ),
      ],
      child: GetMaterialApp(
        home: const Splashscreen(), // Splashscreen akan mengarahkan ke Bottombar jika sudah login
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Gilroy Medium',
          colorScheme: ColorScheme.light(
            primary: primaryBlue500,
            onPrimary: Colors.white,
            secondary: info500,
            onSecondary: Colors.white,
            surface: Colors.white,
            onSurface: grey900,
            background: grey50,
            onBackground: grey900,
            error: error500,
            onError: Colors.white,
          ),
          scaffoldBackgroundColor: grey50,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            foregroundColor: grey900,
            iconTheme: IconThemeData(color: grey900),
            titleTextStyle: TextStyle(
              fontFamily: 'Gilroy Bold',
              fontSize: 18,
              color: grey900,
            ),
          ),
          textTheme: const TextTheme(
            titleLarge: TextStyle(fontFamily: 'Gilroy Bold', color: grey900),
            titleMedium: TextStyle(fontFamily: 'Gilroy Bold', color: grey900),
            bodyLarge: TextStyle(fontFamily: 'Gilroy Medium', color: grey900),
            bodyMedium: TextStyle(fontFamily: 'Gilroy Medium', color: grey900),
            bodySmall: TextStyle(fontFamily: 'Gilroy Medium', color: grey600),
            labelLarge: TextStyle(fontFamily: 'Gilroy Bold', color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: grey700),
          dividerTheme: DividerThemeData(color: grey200),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            hintStyle: const TextStyle(color: grey400, fontFamily: 'Gilroy Medium'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: grey200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: grey200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryBlue500, width: 1.5),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              textStyle: const TextStyle(fontFamily: 'Gilroy Bold'),
            ),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: primaryBlue50,
            selectedColor: primaryBlue500,
            labelStyle: const TextStyle(color: grey900, fontFamily: 'Gilroy Medium'),
            secondaryLabelStyle: const TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}
