class AmbulanceRequest {
  final String title;
  final String severity;
  final int hospitalId;
  final String? patientName;
  final int? patientAge;
  final String caseClassification;
  final String? description;
  final int? heartRate;
  final int? oxygenSaturation;
  final String? bloodPressure;
  final double? bodyTemperature;
  final int? estimatedArrivalTime;

  AmbulanceRequest({
    required this.title,
    required this.severity,
    required this.hospitalId,
    this.patientName,
    this.patientAge,
    required this.caseClassification,
    this.description,
    this.heartRate,
    this.oxygenSaturation,
    this.bloodPressure,
    this.bodyTemperature,
    this.estimatedArrivalTime,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'severity': severity,
    'hospital_id': hospitalId,
    if (patientName != null) 'patient_name': patientName,
    if (patientAge != null) 'patient_age': patientAge,
    'case_classification': caseClassification,
    if (description != null) 'description': description,
    if (heartRate != null) 'heart_rate': heartRate,
    if (oxygenSaturation != null) 'oxygen_saturation': oxygenSaturation,
    if (bloodPressure != null) 'blood_pressure': bloodPressure,
    if (bodyTemperature != null) 'body_temperature': bodyTemperature,
    if (estimatedArrivalTime != null) 'estimated_arrival_time': estimatedArrivalTime,
  };
}

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class Hospital {
  final int id;
  final String name;
  final double distance;
  final double drivingDistance;
  final int estimatedDrivingTimeMins;
  final String occupancyLoad;
  final String occupancyLoadAr;
  final int activeCasesCount;
  final int matchScore;
  final String? treatments;
  final String? phone;
  final double lat;
  final double lng;

  Hospital({
    required this.id,
    required this.name,
    required this.distance,
    required this.drivingDistance,
    required this.estimatedDrivingTimeMins,
    required this.occupancyLoad,
    required this.occupancyLoadAr,
    required this.activeCasesCount,
    required this.matchScore,
    this.treatments,
    this.phone,
    required this.lat,
    required this.lng,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) => Hospital(
    id: _parseInt(json['id']),
    name: json['name']?.toString() ?? '',
    distance: _parseDouble(json['distance']),
    drivingDistance: _parseDouble(json['driving_distance']),
    estimatedDrivingTimeMins: _parseInt(json['estimated_driving_time_mins']),
    occupancyLoad: json['occupancy_load']?.toString() ?? 'medium',
    occupancyLoadAr: json['occupancy_load_ar']?.toString() ?? '',
    activeCasesCount: _parseInt(json['active_cases_count']),
    matchScore: _parseInt(json['match_score']),
    treatments: json['treatments']?.toString(),
    phone: json['phone']?.toString(),
    lat: _parseDouble(json['lat']),
    lng: _parseDouble(json['lng']),
  );
}

class RequestStatus {
  final int id;
  final String title;
  final String severity;
  final String status;
  final String hospitalName;
  final int? estimatedArrivalTime;
  final String? acknowledgedAt;
  final String createdAt;

  RequestStatus({
    required this.id,
    required this.title,
    required this.severity,
    required this.status,
    required this.hospitalName,
    this.estimatedArrivalTime,
    this.acknowledgedAt,
    required this.createdAt,
  });

  factory RequestStatus.fromJson(Map<String, dynamic> json) => RequestStatus(
    id: _parseInt(json['id']),
    title: json['title']?.toString() ?? '',
    severity: json['severity']?.toString() ?? 'low',
    status: json['status']?.toString() ?? 'pending',
    hospitalName: json['hospital']?['name']?.toString() ?? '',
    estimatedArrivalTime: json['estimated_arrival_time'] != null ? _parseInt(json['estimated_arrival_time']) : null,
    acknowledgedAt: json['acknowledged_at']?.toString(),
    createdAt: json['created_at']?.toString() ?? '',
  );
}