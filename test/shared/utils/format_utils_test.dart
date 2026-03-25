import 'package:aio_studio/shared/utils/format_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDuration', () {
    test('formats zero duration', () {
      expect(formatDuration(Duration.zero), '00:00');
    });

    test('formats seconds only', () {
      expect(formatDuration(const Duration(seconds: 5)), '00:05');
      expect(formatDuration(const Duration(seconds: 59)), '00:59');
    });

    test('formats minutes and seconds', () {
      expect(formatDuration(const Duration(minutes: 2, seconds: 5)), '02:05');
      expect(formatDuration(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('formats hours', () {
      expect(
        formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
      expect(
        formatDuration(const Duration(hours: 10, minutes: 0, seconds: 0)),
        '10:00:00',
      );
    });

    test('clamps negative duration to zero', () {
      expect(formatDuration(const Duration(seconds: -10)), '00:00');
    });
  });

  group('formatDurationFromSeconds', () {
    test('formats normal seconds', () {
      expect(formatDurationFromSeconds(125.0), '02:05');
      expect(formatDurationFromSeconds(0.0), '00:00');
      expect(formatDurationFromSeconds(3661.0), '1:01:01');
    });

    test('returns 00:00 for NaN, Infinity, and negative', () {
      expect(formatDurationFromSeconds(double.nan), '00:00');
      expect(formatDurationFromSeconds(double.infinity), '00:00');
      expect(formatDurationFromSeconds(double.negativeInfinity), '00:00');
      expect(formatDurationFromSeconds(-1.0), '00:00');
    });

    test('rounds fractional seconds correctly', () {
      expect(formatDurationFromSeconds(0.5), '00:00');
      expect(formatDurationFromSeconds(1.4), '00:01');
      expect(formatDurationFromSeconds(59.9995), '01:00');
    });
  });

  group('formatFileSize', () {
    test('returns dash for null or negative', () {
      expect(formatFileSize(null), '-');
      expect(formatFileSize(-1), '-');
    });

    test('formats bytes', () {
      expect(formatFileSize(0), '0 B');
      expect(formatFileSize(512), '512 B');
      expect(formatFileSize(1023), '1023 B');
    });

    test('formats kilobytes', () {
      expect(formatFileSize(1024), '1.0 KB');
      expect(formatFileSize(1536), '1.5 KB');
      expect(formatFileSize(1024 * 1023), '1023.0 KB');
    });

    test('formats megabytes', () {
      expect(formatFileSize(1024 * 1024), '1.0 MB');
      expect(formatFileSize(1024 * 1024 * 512), '512.0 MB');
    });

    test('formats gigabytes', () {
      expect(formatFileSize(1024 * 1024 * 1024), '1.0 GB');
      expect(formatFileSize((1024 * 1024 * 1024 * 2.5).toInt()), '2.5 GB');
    });
  });

  group('date & time formatters', () {
    final dt = DateTime(2025, 3, 18, 14, 30);

    test('formatDateTime returns yyyy-MM-dd HH:mm', () {
      expect(formatDateTime(dt), '2025-03-18 14:30');
    });

    test('formatDate returns yyyy-MM-dd', () {
      expect(formatDate(dt), '2025-03-18');
    });

    test('formatShortDateTime returns MM/dd HH:mm', () {
      expect(formatShortDateTime(dt), '03/18 14:30');
    });

    test('formatCompactDateTime returns MM-dd HH:mm', () {
      expect(formatCompactDateTime(dt), '03-18 14:30');
    });

    test('formatTime returns HH:mm', () {
      expect(formatTime(dt), '14:30');
    });

    test('formats midnight correctly', () {
      final midnight = DateTime(2025, 1, 1, 0, 0);
      expect(formatTime(midnight), '00:00');
      expect(formatDateTime(midnight), '2025-01-01 00:00');
    });
  });

  group('formatCompactNumber', () {
    test('returns plain number under 1000', () {
      expect(formatCompactNumber(0), '0');
      expect(formatCompactNumber(999), '999');
    });

    test('returns 0 for negative', () {
      expect(formatCompactNumber(-5), '0');
    });

    test('formats thousands with K suffix', () {
      expect(formatCompactNumber(1000), '1.0K');
      expect(formatCompactNumber(1500), '1.5K');
      expect(formatCompactNumber(999949), '999.9K');
    });

    test('formats millions with M suffix', () {
      expect(formatCompactNumber(999950), '1.0M');
      expect(formatCompactNumber(1000000), '1.0M');
      expect(formatCompactNumber(2500000), '2.5M');
    });
  });
}
