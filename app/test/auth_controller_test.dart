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

/// In-memory session hint so tests never touch SharedPreferences.
class _FakeHint implements AuthSessionHint {
  _FakeHint(this.value);
  bool value;
  final writes = <bool>[];

  @override
  Future<bool> read() async => value;

  @override
  Future<void> write(bool wasSignedIn) async {
    value = wasSignedIn;
    writes.add(wasSignedIn);
  }
}

void main() {
  group('AuthController status', () {
    late StreamController<User?> stream;

    setUp(() => stream = StreamController<User?>());
    tearDown(() => stream.close());

    AuthController make({
      bool hadSession = false,
      Duration grace = const Duration(seconds: 8),
    }) =>
        AuthController(
          authStream: stream.stream,
          sessionHint: _FakeHint(hadSession),
          restoreGrace: grace,
        );

    test('starts unknown before any event (splash, not login)', () async {
      final c = make();
      await c.init();
      expect(c.status, AuthStatus.unknown);
      c.dispose();
    });

    test('a non-null user → authenticated', () async {
      final c = make();
      await c.init();
      stream.add(_FakeUser('u1'));
      await Future<void>.delayed(Duration.zero);
      expect(c.status, AuthStatus.authenticated);
      expect(c.uid, 'u1');
      c.dispose();
    });

    test('null with no prior session → unauthenticated (login now)', () async {
      final c = make(hadSession: false);
      await c.init();
      stream.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(c.status, AuthStatus.unauthenticated);
      c.dispose();
    });

    test('null WITH prior session → stays unknown, then restores to authenticated',
        () async {
      // The release bug: authStateChanges emits null first, then the cached
      // user ~2.3s later. With a prior-session hint we must NOT flash login.
      final c = make(hadSession: true);
      await c.init();
      stream.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(c.status, AuthStatus.unknown); // splash, not login

      stream.add(_FakeUser('u1'));
      await Future<void>.delayed(Duration.zero);
      expect(c.status, AuthStatus.authenticated);
      c.dispose();
    });

    test('prior session but restore never arrives → falls back to login after grace',
        () async {
      final c = make(hadSession: true, grace: const Duration(milliseconds: 30));
      await c.init();
      stream.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(c.status, AuthStatus.unknown);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(c.status, AuthStatus.unauthenticated);
      c.dispose();
    });

    test('user → null (real sign-out) → unauthenticated', () async {
      final c = make(hadSession: true);
      await c.init();
      stream.add(_FakeUser('u1'));
      await Future<void>.delayed(Duration.zero);
      expect(c.status, AuthStatus.authenticated);

      // Already resolved → a later null is a genuine sign-out, not a restore.
      stream.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(c.status, AuthStatus.unauthenticated);
      c.dispose();
    });
  });
}
