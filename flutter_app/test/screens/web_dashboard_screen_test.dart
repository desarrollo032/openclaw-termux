import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openclaw/screens/web_dashboard_screen.dart';

void main() {
  const channel = MethodChannel('com.nxg.openclawproot/native');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'openWebDashboard') {
        return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('returns to the previous route after opening native web dashboard',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const WebDashboardScreen(
                    url: 'http://localhost:18789/#token=test',
                  ),
                ),
              );
            },
            child: const Text('Open panel'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open panel'));
    await tester.pumpAndSettle();

    expect(find.text('Open panel'), findsOneWidget);
    expect(find.text('Panel Web'), findsNothing);
  });
}
