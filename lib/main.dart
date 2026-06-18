import 'package:flutter/material.dart';
import 'app.dart';
import 'services/language_service.dart';
import 'widgets/floating_pet/desktop_pet_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LanguageService.instance.init();
  runApp(const PetMemorialApp());
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: DesktopPetOverlay(),
      ),
    ),
  );
}
