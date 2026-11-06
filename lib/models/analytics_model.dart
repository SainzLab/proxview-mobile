import '../core/utils/formatters.dart';

class SlaSummaryModel {
  final String period;
  final String severity;
  final int totalPeriodSec;
  final int totalUptimeSec;
  final String uptimeDuration;
  final int totalDowntimeSec;
  final String downtimeDuration;
  final int totalDegradationSec;
  final String degradationDuration;
  final int incidentCount;
  final int mttrSec;
  final String mttrDuration;
  final int mtbfSec;
  final String mtbfDuration;
  final double availability;
  final String availabilityPercent;

  const SlaSummaryModel({
    required this.period,
    required this.severity,
    required this.totalPeriodSec,
    required this.totalUptimeSec,
    required this.uptimeDuration,
    required this.totalDowntimeSec,
    required this.downtimeDuration,
    this.totalDegradationSec = 0,
    this.degradationDuration = '0d',
    required this.incidentCount,
    required this.mttrSec,
    required this.mttrDuration,
    required this.mtbfSec,
    required this.mtbfDuration,
    required this.availability,
    required this.availabilityPercent,
  });

  factory SlaSummaryModel.fromJson(Map<String, dynamic> json) {
    final totalPeriodSec = (json['total_period_sec'] as num?)?.toInt() ?? 0;
    final totalUptimeSec = (json['total_uptime_sec'] as num?)?.toInt() ?? 0;
    final totalDowntimeSec = (json['total_downtime_sec'] as num?)?.toInt() ?? 0;
    final totalDegradationSec =
        (json['total_degradation_sec'] as num?)?.toInt() ?? 0;
    final incidentCount = (json['incident_count'] as num?)?.toInt() ?? 0;
    final mttrSec = (json['mttr_sec'] as num?)?.toInt() ?? 0;

    final int computedMtbfFallback = incidentCount > 0
        ? (totalUptimeSec / incidentCount).round()
        : totalUptimeSec;
    final mtbfSec =
        (json['mtbf_sec'] as num?)?.toInt() ?? computedMtbfFallback;

    final double parsedAvailability = (json['availability_num'] as num?)
            ?.toDouble() ??
        double.tryParse(json['availability']?.toString() ?? '100') ??
        100.0;

    String resolveDuration(dynamic rawText, int sec) {
      final str = rawText?.toString().trim() ?? '';
      if (str.isNotEmpty) return str;
      return Formatters.formatDurationSeconds(sec);
    }

    final rawAvailPercent = json['availability_percent']?.toString().trim() ?? '';

    return SlaSummaryModel(
      period: json['period']?.toString() ?? '24h',
      severity: json['severity']?.toString() ?? 'ALL',
      totalPeriodSec: totalPeriodSec,
      totalUptimeSec: totalUptimeSec,
      uptimeDuration: resolveDuration(json['uptime_duration'], totalUptimeSec),
      totalDowntimeSec: totalDowntimeSec,
      downtimeDuration:
          resolveDuration(json['downtime_duration'], totalDowntimeSec),
      totalDegradationSec: totalDegradationSec,
      degradationDuration: resolveDuration(
        json['degradation_duration'],
        totalDegradationSec,
      ),
      incidentCount: incidentCount,
      mttrSec: mttrSec,
      mttrDuration: resolveDuration(json['mttr_duration'], mttrSec),
      mtbfSec: mtbfSec,
      mtbfDuration: resolveDuration(json['mtbf_duration'], mtbfSec),
      availability: parsedAvailability,
      availabilityPercent: rawAvailPercent.isNotEmpty
          ? rawAvailPercent
          : '${parsedAvailability.toStringAsFixed(2)}%',
    );
  }
}

class SlaChartPointModel {
  final String label;
  final int totalPeriodSec;
  final int totalUptimeSec;
  final String uptimeDuration;
  final int totalDowntimeSec;
  final String downtimeDuration;
  final int totalDegradationSec;
  final String degradationDuration;
  final int incidentCount;
  final int mttrSec;
  final String mttrDuration;
  final int mtbfSec;
  final String mtbfDuration;
  final double availability;

  const SlaChartPointModel({
    required this.label,
    required this.totalPeriodSec,
    required this.totalUptimeSec,
    required this.uptimeDuration,
    required this.totalDowntimeSec,
    required this.downtimeDuration,
    this.totalDegradationSec = 0,
    this.degradationDuration = '0d',
    required this.incidentCount,
    required this.mttrSec,
    required this.mttrDuration,
    required this.mtbfSec,
    required this.mtbfDuration,
    required this.availability,
  });

  factory SlaChartPointModel.fromJson(Map<String, dynamic> json) {
    final totalPeriodSec = (json['total_period_sec'] as num?)?.toInt() ?? 0;
    final totalUptimeSec = (json['total_uptime_sec'] as num?)?.toInt() ?? 0;
    final totalDowntimeSec = (json['total_downtime_sec'] as num?)?.toInt() ?? 0;
    final totalDegradationSec =
        (json['total_degradation_sec'] as num?)?.toInt() ?? 0;
    final incidentCount = (json['incident_count'] as num?)?.toInt() ?? 0;
    final mttrSec = (json['mttr_sec'] as num?)?.toInt() ?? 0;

    final int computedMtbfFallback = incidentCount > 0
        ? (totalUptimeSec / incidentCount).round()
        : totalUptimeSec;
    final mtbfSec =
        (json['mtbf_sec'] as num?)?.toInt() ?? computedMtbfFallback;

    String resolveDuration(dynamic rawText, int sec) {
      final str = rawText?.toString().trim() ?? '';
      if (str.isNotEmpty) return str;
      return Formatters.formatDurationSeconds(sec);
    }

    return SlaChartPointModel(
      label: json['label']?.toString() ?? '',
      totalPeriodSec: totalPeriodSec,
      totalUptimeSec: totalUptimeSec,
      uptimeDuration: resolveDuration(json['uptime_duration'], totalUptimeSec),
      totalDowntimeSec: totalDowntimeSec,
      downtimeDuration:
          resolveDuration(json['downtime_duration'], totalDowntimeSec),
      totalDegradationSec: totalDegradationSec,
      degradationDuration: resolveDuration(
        json['degradation_duration'],
        totalDegradationSec,
      ),
      incidentCount: incidentCount,
      mttrSec: mttrSec,
      mttrDuration: resolveDuration(json['mttr_duration'], mttrSec),
      mtbfSec: mtbfSec,
      mtbfDuration: resolveDuration(json['mtbf_duration'], mtbfSec),
      availability:
          double.tryParse(json['availability']?.toString() ?? '100') ?? 100.0,
    );
  }
}

class SlaAnalyticsResponseModel {
  final SlaSummaryModel summary;
  final List<SlaChartPointModel> chartData;

  const SlaAnalyticsResponseModel({
    required this.summary,
    required this.chartData,
  });

  factory SlaAnalyticsResponseModel.fromJson(Map<String, dynamic> json) {
    final summaryMap = (json['summary'] as Map<String, dynamic>?) ??
        (json['data'] as Map<String, dynamic>?) ??
        const {};
    return SlaAnalyticsResponseModel(
      summary: SlaSummaryModel.fromJson(summaryMap),
      chartData: (json['chartData'] as List?)
              ?.whereType<Map>()
              .map(
                (e) => SlaChartPointModel.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList() ??
          [],
    );
  }
}
