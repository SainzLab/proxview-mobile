class SlaSummaryModel {
  final String period;
  final String severity;
  final int totalPeriodSec;
  final int totalUptimeSec;
  final int totalDowntimeSec;
  final int incidentCount;
  final int mttrSec;
  final double availability;

  const SlaSummaryModel({
    required this.period,
    required this.severity,
    required this.totalPeriodSec,
    required this.totalUptimeSec,
    required this.totalDowntimeSec,
    required this.incidentCount,
    required this.mttrSec,
    required this.availability,
  });

  factory SlaSummaryModel.fromJson(Map<String, dynamic> json) {
    return SlaSummaryModel(
      period: json['period']?.toString() ?? '24h',
      severity: json['severity']?.toString() ?? 'ALL',
      totalPeriodSec: (json['total_period_sec'] as num?)?.toInt() ?? 0,
      totalUptimeSec: (json['total_uptime_sec'] as num?)?.toInt() ?? 0,
      totalDowntimeSec: (json['total_downtime_sec'] as num?)?.toInt() ?? 0,
      incidentCount: (json['incident_count'] as num?)?.toInt() ?? 0,
      mttrSec: (json['mttr_sec'] as num?)?.toInt() ?? 0,
      availability: double.tryParse(json['availability']?.toString() ?? '100') ?? 100.0,
    );
  }
}

class SlaChartPointModel {
  final String label;
  final int totalPeriodSec;
  final int totalUptimeSec;
  final int totalDowntimeSec;
  final int incidentCount;
  final int mttrSec;
  final double availability;

  const SlaChartPointModel({
    required this.label,
    required this.totalPeriodSec,
    required this.totalUptimeSec,
    required this.totalDowntimeSec,
    required this.incidentCount,
    required this.mttrSec,
    required this.availability,
  });

  factory SlaChartPointModel.fromJson(Map<String, dynamic> json) {
    return SlaChartPointModel(
      label: json['label']?.toString() ?? '',
      totalPeriodSec: (json['total_period_sec'] as num?)?.toInt() ?? 0,
      totalUptimeSec: (json['total_uptime_sec'] as num?)?.toInt() ?? 0,
      totalDowntimeSec: (json['total_downtime_sec'] as num?)?.toInt() ?? 0,
      incidentCount: (json['incident_count'] as num?)?.toInt() ?? 0,
      mttrSec: (json['mttr_sec'] as num?)?.toInt() ?? 0,
      availability: double.tryParse(json['availability']?.toString() ?? '100') ?? 100.0,
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
    return SlaAnalyticsResponseModel(
      summary: SlaSummaryModel.fromJson(
        (json['summary'] as Map<String, dynamic>?) ?? const {},
      ),
      chartData: (json['chartData'] as List?)
              ?.map((e) => SlaChartPointModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
