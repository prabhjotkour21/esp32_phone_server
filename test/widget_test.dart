import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:esp32_phone_server/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const Esp32PhoneServerApp());
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
