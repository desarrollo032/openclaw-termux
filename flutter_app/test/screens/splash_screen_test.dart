import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openclaw/screens/splash_screen.dart';
import 'package:openclaw/providers/setup_provider.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.nxg.openclawproot/native'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'setupDirs':
            return true;
          case 'writeResolv':
            return true;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.nxg.openclawproot/native'),
      null,
    );
  });

  testWidgets('SplashScreen builds without ticker provider errors',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SetupProvider()),
        ],
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 801));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('OpenClaw'), findsAtLeastNWidgets(1));
  });
}
