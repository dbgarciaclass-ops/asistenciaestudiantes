// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asistencia_estudiantes/main.dart';

void main() {
  testWidgets('Login screen renders institution title', (WidgetTester tester) async {
    await tester.pumpWidget(const AsistenciaEstudiantesApp());
    await tester.pumpAndSettle();

    expect(find.text('Asistencia Estudiantes'), findsOneWidget);
    expect(find.text('Liceo Jacinto de la Concha'), findsOneWidget);
    expect(find.byIcon(Icons.email_outlined), findsOneWidget);
  });
}
