import 'package:intl/intl.dart';

// -- Duration & file size --

String formatDuration(Duration d) {
  final dur = d.isNegative ? Duration.zero : d;
  final h = dur.inHours;
  final m = dur.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = dur.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:$m:$s';
  return '$m:$s';
}

String formatDurationFromSeconds(double seconds) {
  if (seconds.isNaN || seconds.isInfinite || seconds < 0) return '00:00';
  return formatDuration(Duration(milliseconds: (seconds * 1000).round()));
}

String formatFileSize(int? bytes) {
  if (bytes == null || bytes < 0) return '-';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

// -- Date & time --

final _dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');
final _dateFmt = DateFormat('yyyy-MM-dd');
final _shortDateTimeFmt = DateFormat('MM/dd HH:mm');
final _compactDateTimeFmt = DateFormat('MM-dd HH:mm');
final _timeFmt = DateFormat('HH:mm');

/// `2025-03-18 14:30`
String formatDateTime(DateTime dt) => _dateTimeFmt.format(dt);

/// `2025-03-18`
String formatDate(DateTime dt) => _dateFmt.format(dt);

/// `03/18 14:30`
String formatShortDateTime(DateTime dt) => _shortDateTimeFmt.format(dt);

/// `03-18 14:30`
String formatCompactDateTime(DateTime dt) => _compactDateTimeFmt.format(dt);

/// `14:30`
String formatTime(DateTime dt) => _timeFmt.format(dt);

// -- Numbers --

String formatCompactNumber(int count) {
  if (count < 0) return '0';
  if (count >= 999950) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return '$count';
}
