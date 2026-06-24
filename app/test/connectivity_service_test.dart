import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_lane_app/domain/services/connectivity/connectivity_service.dart';

void main() {
  final fakeAddress = InternetAddress('1.2.3.4');

  group('ConnectivityService.hasInternet', () {
    test('true when the first host resolves', () async {
      final service = ConnectivityService(
        probeHosts: const ['a.example', 'b.example'],
        lookup: (host) async => [fakeAddress],
      );
      expect(await service.hasInternet(), isTrue);
    });

    test('falls back to the second host when the first throws', () async {
      final service = ConnectivityService(
        probeHosts: const ['bad.example', 'good.example'],
        lookup: (host) async {
          if (host == 'bad.example') {
            throw const SocketException('no route');
          }
          return [fakeAddress];
        },
      );
      expect(await service.hasInternet(), isTrue);
    });

    test('false when every host throws SocketException', () async {
      final service = ConnectivityService(
        probeHosts: const ['a.example', 'b.example'],
        lookup: (host) async => throw const SocketException('offline'),
      );
      expect(await service.hasInternet(), isFalse);
    });

    test('false when lookup exceeds the timeout', () async {
      final service = ConnectivityService(
        timeout: const Duration(milliseconds: 50),
        probeHosts: const ['slow.example'],
        lookup: (host) async {
          await Future.delayed(const Duration(seconds: 5));
          return [fakeAddress];
        },
      );
      expect(await service.hasInternet(), isFalse);
    });

    test('false when lookup returns an empty list', () async {
      final service = ConnectivityService(
        probeHosts: const ['empty.example'],
        lookup: (host) async => const [],
      );
      expect(await service.hasInternet(), isFalse);
    });
  });
}
