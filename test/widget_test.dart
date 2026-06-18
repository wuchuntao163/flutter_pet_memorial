import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_pet_memorial/widgets/floating_pet/desktop_pet_overlay.dart';

void main() {
  testWidgets('Desktop pet overlay shows pet with transparent background',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DesktopPetOverlay(),
        ),
      ),
    );

    final overlayMaterial = tester.widget<Material>(
      find.descendant(
        of: find.byType(DesktopPetOverlay),
        matching: find.byType(Material),
      ),
    );
    expect(overlayMaterial.color, Colors.transparent);
    expect(find.byIcon(Icons.pets), findsOneWidget);
  });
}
