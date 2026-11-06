enum NetworkToolType {
  ping,
  traceroute,
  ipScan;

  String get label {
    switch (this) {
      case NetworkToolType.ping:
        return 'PING';
      case NetworkToolType.traceroute:
        return 'TRACEROUTE';
      case NetworkToolType.ipScan:
        return 'IP SCAN';
    }
  }

  String get fullTitle {
    switch (this) {
      case NetworkToolType.ping:
        return 'Ping';
      case NetworkToolType.traceroute:
        return 'Traceroute';
      case NetworkToolType.ipScan:
        return 'IP Scan';
    }
  }

  String get description {
    switch (this) {
      case NetworkToolType.ping:
        return 'Menguji konektivitas & latensi ke host target (IPv4 / IPv6).';
      case NetworkToolType.traceroute:
        return 'Melacak rute lompatan router (hops) dari server monitoring menuju host tujuan.';
      case NetworkToolType.ipScan:
        return 'Memindai daftar host aktif pada subnet menggunakan Nmap.';
    }
  }

  String get endpointPath {
    switch (this) {
      case NetworkToolType.ping:
        return '/tools/ping';
      case NetworkToolType.traceroute:
        return '/tools/traceroute';
      case NetworkToolType.ipScan:
        return '/tools/ipscan';
    }
  }

  String commandPreview(String rawTarget) {
    final target = rawTarget.trim().isEmpty ? '<target>' : rawTarget.trim();
    final ipv6 = NetworkToolValidator.looksLikeIpv6(target);
    switch (this) {
      case NetworkToolType.ping:
        return ipv6 ? 'ping -6 -c 4 $target' : 'ping -c 10 $target';
      case NetworkToolType.traceroute:
        return ipv6 ? 'traceroute -6 $target' : 'traceroute $target';
      case NetworkToolType.ipScan:
        return ipv6 ? 'nmap -6 -sn $target' : 'nmap -sn $target';
    }
  }
}

class NetworkToolResponse {
  final bool success;
  final String output;
  final String message;
  final int? statusCode;
  final bool isValidationError;
  final NetworkToolType? toolType;
  final String? target;
  final DateTime timestamp;

  NetworkToolResponse({
    required this.success,
    required this.output,
    required this.message,
    this.statusCode,
    this.isValidationError = false,
    this.toolType,
    this.target,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory NetworkToolResponse.fromJson(
    Map<String, dynamic> json, {
    int? statusCode,
    bool isValidationError = false,
    NetworkToolType? toolType,
    String? target,
  }) {
    return NetworkToolResponse(
      success: json['success'] == true,
      output: json['output']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      statusCode: statusCode,
      isValidationError: isValidationError || statusCode == 400,
      toolType: toolType,
      target: target,
    );
  }
}

class NetworkToolValidator {
  static final RegExp _dangerousChars = RegExp(r'''[;&|$`\s'"\\<>()]''');
  static final RegExp _domainPattern = RegExp(
    r'^(?=.{1,253}$)([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$',
  );

  static bool looksLikeIpv6(String input) {
    final cleaned = input.trim().split('/').first;
    return cleaned.contains(':');
  }

  static bool isValidIpv4(String input) {
    final parts = input.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      if (part.isEmpty || part.length > 3) return false;
      final val = int.tryParse(part);
      if (val == null || val < 0 || val > 255) return false;
    }
    return true;
  }

  static bool isValidIpv6(String input) {
    if (!input.contains(':')) return false;
    final uri = Uri.tryParse('http://[$input]');
    return uri != null && uri.host.isNotEmpty;
  }

  /// Validasi input untuk Ping & Traceroute (IPv4, IPv6, atau Domain/Hostname <= 253 karakter)
  static String? validateHostOrDomain(String raw) {
    final target = raw.trim();
    if (target.isEmpty) {
      return 'Masukkan alamat IPv4, IPv6, atau nama domain target terlebih dahulu.';
    }
    if (target.length > 253) {
      return 'Target terlalu panjang (maksimal 253 karakter).';
    }
    if (_dangerousChars.hasMatch(target)) {
      return 'Target mengandung karakter tidak diizinkan. Gunakan format IPv4, IPv6, atau domain.';
    }
    if (isValidIpv4(target) || isValidIpv6(target) || _domainPattern.hasMatch(target)) {
      return null;
    }
    return 'Target tidak valid. Hanya format IPv4, IPv6, atau domain yang diperbolehkan.';
  }

  /// Validasi input untuk IP Scan Nmap:
  /// - IPv4 atau IPv4/prefix (/16 s.d. /32)
  /// - IPv6 atau IPv6/prefix (/1 s.d. /128)
  static String? validateIpScanTarget(String raw) {
    final target = raw.trim();
    if (target.isEmpty) {
      return 'Masukkan alamat IP atau subnet target (contoh: 192.168.1.0/24).';
    }
    if (target.length > 253 || _dangerousChars.hasMatch(target)) {
      return 'Target tidak valid. Gunakan format IP atau IP/prefix (contoh: 192.168.1.0/24, 2001:db8::/64).';
    }

    final segments = target.split('/');
    if (segments.length > 2) {
      return 'Format subnet tidak valid. Gunakan satu tanda "/" (contoh: 192.168.1.0/24).';
    }

    final ipPart = segments[0];
    final prefixPart = segments.length == 2 ? segments[1] : null;

    if (isValidIpv4(ipPart)) {
      if (prefixPart != null) {
        final prefix = int.tryParse(prefixPart);
        if (prefix == null || prefix < 16 || prefix > 32) {
          return 'Prefix subnet IPv4 harus berada di rentang /16 s.d. /32.';
        }
      }
      return null;
    }

    if (isValidIpv6(ipPart)) {
      if (prefixPart != null) {
        final prefix = int.tryParse(prefixPart);
        if (prefix == null || prefix < 1 || prefix > 128) {
          return 'Prefix subnet IPv6 harus berada di rentang /1 s.d. /128.';
        }
      }
      return null;
    }

    return 'Target tidak valid. Gunakan format IP atau IP/prefix (contoh: 192.168.1.0/24, 2001:db8::/64).';
  }
}
