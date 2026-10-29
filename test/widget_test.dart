import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxview/main.dart';
import 'package:proxview/models/user_model.dart';
import 'package:proxview/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App initializes and shows LoginView when unauthenticated',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('PROX VIEW MONITORING PROXMOX'), findsOneWidget);
    expect(find.text('OTENTIKASI 3-FAKTOR'), findsOneWidget);
    expect(find.text('HUBUNGKAN PERANGKAT'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/diskominfosubang.png',
      ),
      findsAtLeastNWidgets(1),
    );
  });

  test('StorageService never persists plaintext token into SharedPreferences',
      () async {
    SharedPreferences.setMockInitialValues({
      'proxview_api_token': 'legacy_plaintext_token',
    });
    FlutterSecureStorage.setMockInitialValues({});

    final storage = StorageService();
    const secretToken =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    await storage.saveApiToken(secretToken);
    await storage.saveCachedUser(
      const UserModel(
        id: 1,
        name: 'Asep NOC',
        username: 'asep_noc',
        role: 'Teknisi',
        isActive: true,
        apiToken: secretToken,
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('proxview_api_token'), isNull);

    final cachedRaw = prefs.getString('proxview_cached_user');
    expect(cachedRaw, isNotNull);
    final cachedMap = jsonDecode(cachedRaw!) as Map<String, dynamic>;
    expect(cachedMap.containsKey('api_token'), isFalse);
    expect(await storage.getApiToken(), equals(secretToken));
  });

  test('StorageService normalizes and validates server URLs securely', () {
    expect(
      StorageService.normalizeBaseUrl('sainzcloud.my.id'),
      equals('https://proxview.sainzcloud.my.id/api/mobile/v1'),
    );
    expect(
      StorageService.normalizeBaseUrl('https://sainzcloud.my.id/api/mobile/v1'),
      equals('https://proxview.sainzcloud.my.id/api/mobile/v1'),
    );
    expect(
      StorageService.normalizeBaseUrl('monitoring.subang.go.id'),
      equals('https://monitoring.subang.go.id/api/mobile/v1'),
    );
    expect(
      StorageService.normalizeBaseUrl('192.168.8.10:7060'),
      equals('http://192.168.8.10:7060/api/mobile/v1'),
    );
    expect(StorageService.isValidServerUrl('https://pve.example.com'), isTrue);
    expect(StorageService.isValidServerUrl('invalid host with spaces'), isFalse);
    expect(StorageService.isValidServerUrl(''), isFalse);
  });
}
