import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymomox/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App initializes and shows LoginView when unauthenticated',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('mymomox'), findsOneWidget);
    expect(find.text('OTENTIKASI 3-FAKTOR'), findsOneWidget);
    expect(find.text('HUBUNGKAN PERANGKAT'), findsOneWidget);
  });
}
