import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_lane_app/domain/services/ai_gateway/ai_error.dart';

void main() {
  group('describeAiError', () {
    test('Gemini prepay depleted (the real 429 we hit) → out of credits', () {
      final msg = describeAiError(
        'RateLimitException(429): Your prepayment credits are depleted. '
        'Please go to AI Studio to manage billing.',
      );
      expect(msg.toLowerCase(), contains('out of credits'));
    });

    test('quota / rate limit without credits wording → busy', () {
      expect(
        describeAiError('Error 429: RESOURCE_EXHAUSTED, quota exceeded')
            .toLowerCase(),
        contains('busy'),
      );
    });

    test('SocketException → no internet', () {
      expect(
        describeAiError(const SocketException('Failed host lookup'))
            .toLowerCase(),
        contains('no internet'),
      );
    });

    test('TimeoutException → took too long', () {
      expect(
        describeAiError(TimeoutException('slow')).toLowerCase(),
        contains('too long'),
      );
    });

    test('invalid API key → check the API key', () {
      expect(
        describeAiError('API_KEY_INVALID: 403 permission denied')
            .toLowerCase(),
        contains('api key'),
      );
    });

    test('503 unavailable → Google service problem', () {
      expect(
        describeAiError('503 Service Unavailable').toLowerCase(),
        contains("google's ai service"),
      );
    });

    test('unknown error → generic AI failure (never leaks raw text)', () {
      final msg = describeAiError('NullPointerSomethingWeird at 0xdeadbeef');
      expect(msg, 'The AI request failed. Please try again.');
      expect(msg, isNot(contains('0xdeadbeef')));
    });
  });
}
