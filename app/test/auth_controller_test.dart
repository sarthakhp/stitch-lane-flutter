import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_lane_app/domain/state/auth_controller.dart';

/// Minimal hand-rolled fake — every member routes through noSuchMethod, so we
/// can emit a non-null [User] without Firebase or a mocking package.
class _FakeUser implements User {
  _FakeUser(this._uid);
  final String _uid;

  @override
  String get uid => _uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('AuthController status', () {
    late StreamController<User?> stream;
    late AuthController controller;

    setUp(() {
      stream = StreamController<User?>();
      controller = AuthController(authStream: stream.stream);
    });

    tearDown(() async {
      controller.dispose();
      await stream.close();
    });

    test('starts unknown before any event (must show splash, not login)', () {
      expect(controller.status, AuthStatus.unknown);
      controller.init();
      // Still unknown until the stream actually emits.
      expect(controller.status, AuthStatus.unknown);
    });

    test('a non-null user → authenticated', () async {
      controller.init();
      stream.add(_FakeUser('u1'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.status, AuthStatus.authenticated);
      expect(controller.uid, 'u1');
    });

    test('a null event → unauthenticated', () async {
      controller.init();
      stream.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.user, isNull);
    });

    test('never reports unauthenticated before the first event', () async {
      var sawUnauthenticatedWhileUnknown = false;
      controller.addListener(() {
        // no-op; presence of listener mirrors real usage
      });
      controller.init();
      // Before emitting anything, status must not be unauthenticated.
      if (controller.status == AuthStatus.unauthenticated) {
        sawUnauthenticatedWhileUnknown = true;
      }
      expect(sawUnauthenticatedWhileUnknown, isFalse);
      expect(controller.status, AuthStatus.unknown);
    });

    test('user → null → user transitions resolve correctly', () async {
      controller.init();
      stream.add(_FakeUser('u1'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.status, AuthStatus.authenticated);

      stream.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(controller.status, AuthStatus.unauthenticated);

      stream.add(_FakeUser('u2'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.status, AuthStatus.authenticated);
      expect(controller.uid, 'u2');
    });
  });
}
