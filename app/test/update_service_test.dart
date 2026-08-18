import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:blox_notify/services/update_service.dart';

String _releaseJson({String assetName = 'blox-notify-1.0.1+2.apk'}) => jsonEncode({
      'tag_name': 'v1.0.1',
      'body': 'Fixed a bug.',
      'assets': [
        {
          'name': assetName,
          'browser_download_url':
              'https://github.com/AnushGurung11/BloxNotify/releases/download/v1.0.1/$assetName',
        },
      ],
    });

UpdateService _serviceReturning(http.Response response) =>
    UpdateService(client: MockClient((request) async => response));

void main() {
  test('returns the update when the release versionCode is newer', () async {
    final service = _serviceReturning(http.Response(_releaseJson(), 200));

    final update = await service.checkForUpdate(1);

    expect(update, isNotNull);
    expect(update!.versionName, '1.0.1');
    expect(update.versionCode, 2);
    expect(update.downloadUrl, contains('blox-notify-1.0.1+2.apk'));
    expect(update.notes, 'Fixed a bug.');
  });

  test('returns null when the installed version is current', () async {
    final service = _serviceReturning(http.Response(_releaseJson(), 200));

    expect(await service.checkForUpdate(2), isNull);
    expect(await service.checkForUpdate(99), isNull);
  });

  test('returns null for a release without a matching APK asset', () async {
    final service = _serviceReturning(
      http.Response(_releaseJson(assetName: 'app-release.apk'), 200),
    );

    expect(await service.checkForUpdate(1), isNull);
  });

  test('returns null on non-200 responses', () async {
    final service = _serviceReturning(http.Response('rate limited', 403));

    expect(await service.checkForUpdate(1), isNull);
  });

  test('returns null on network errors without throwing', () async {
    final service = UpdateService(
      client: MockClient((request) async => throw http.ClientException('offline')),
    );

    expect(await service.checkForUpdate(1), isNull);
  });
}