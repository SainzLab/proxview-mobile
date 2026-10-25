class Formatters {
  /// Mengonversi string persentase seperti "18.4 %" atau angka menjadi double (0.0 - 100.0)
  static double parsePercentage(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    final cleaned = value.toString().replaceAll('%', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Mengonversi latency string seperti "12 ms" menjadi double
  static double parseLatencyMs(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    final cleaned = value.toString().replaceAll(RegExp(r'[^0-9.]'), '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Format detik menjadi durasi lengkap seperti di Web ViewMox (misal "23j 53m 3d", "6m 57d", "19d")
  static String formatDurationSeconds(dynamic seconds) {
    if (seconds == null) return '0d';
    final int sec = seconds is int
        ? seconds
        : (seconds is num ? seconds.toInt() : int.tryParse(seconds.toString()) ?? 0);
    if (sec <= 0) return '0d';

    final int days = sec ~/ 86400;
    final int hours = (sec % 86400) ~/ 3600;
    final int minutes = (sec % 3600) ~/ 60;
    final int remSec = sec % 60;

    final List<String> parts = [];
    if (days > 0) parts.add('${days}h');
    if (hours > 0) parts.add('${hours}j');
    if (minutes > 0) parts.add('${minutes}m');
    if (remSec > 0 || parts.isEmpty) parts.add('${remSec}d');

    return parts.join(' ');
  }

  /// Format ISO 8601 atau Unix timestamp ke format tanggal lokal yang mudah dibaca
  static String formatDateTime(dynamic rawTime) {
    if (rawTime == null) return '-';
    DateTime? dt;
    if (rawTime is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(rawTime * 1000).toLocal();
    } else if (rawTime is num) {
      dt = DateTime.fromMillisecondsSinceEpoch(rawTime.toInt() * 1000).toLocal();
    } else if (rawTime is String && rawTime.isNotEmpty) {
      final asInt = int.tryParse(rawTime);
      if (asInt != null) {
        dt = DateTime.fromMillisecondsSinceEpoch(asInt * 1000).toLocal();
      } else {
        dt = DateTime.tryParse(rawTime)?.toLocal();
      }
    }
    if (dt == null) return rawTime.toString();

    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$min';
  }

  /// Format ISO 8601 atau Unix timestamp ke format jam lokal (HH:mm:ss)
  static String formatTimeSeconds(dynamic rawTime) {
    if (rawTime == null) return '-';
    DateTime? dt;
    if (rawTime is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(rawTime * 1000).toLocal();
    } else if (rawTime is num) {
      dt = DateTime.fromMillisecondsSinceEpoch(rawTime.toInt() * 1000).toLocal();
    } else if (rawTime is String && rawTime.isNotEmpty) {
      final asInt = int.tryParse(rawTime);
      if (asInt != null) {
        dt = DateTime.fromMillisecondsSinceEpoch(asInt * 1000).toLocal();
      } else {
        dt = DateTime.tryParse(rawTime)?.toLocal();
      }
    }
    if (dt == null) {
      final str = rawTime.toString();
      if (str.length >= 8 && str.contains(':')) {
        return str;
      }
      return str;
    }

    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final sec = dt.second.toString().padLeft(2, '0');
    return '$hour:$min:$sec';
  }
}
