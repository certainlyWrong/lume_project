import 'package:flutter_test/flutter_test.dart';
import 'package:mandelbrot/main.dart';

void main() {
  testWidgets('Mandelbrot app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MandelbrotApp());

    // Verify that the app title is present
    expect(find.text('Mandelbrot + Lume'), findsOneWidget);

    // Verify controls are present
    expect(find.text('Zoom:'), findsOneWidget);
    expect(find.text('Iterations:'), findsOneWidget);
    expect(find.text('Reset View'), findsOneWidget);
    expect(find.text('Process with Lume'), findsOneWidget);
  });
}
