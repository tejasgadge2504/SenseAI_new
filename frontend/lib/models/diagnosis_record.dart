class DiagnosisRecord {
  final String id;
  final String patientId;
  final String patientName;
  final String diseaseType;
  final Map<String, dynamic> inputs;
  final Map<String, dynamic> apiResponse;
  final String timestamp;
  final List<int> checkedActions;

  DiagnosisRecord({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.diseaseType,
    required this.inputs,
    required this.apiResponse,
    required this.timestamp,
    this.checkedActions = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'patientId': patientId,
    'patientName': patientName,
    'diseaseType': diseaseType,
    'inputs': inputs,
    'apiResponse': apiResponse,
    'timestamp': timestamp,
    'checkedActions': checkedActions,
  };

  factory DiagnosisRecord.fromJson(Map<String, dynamic> json) =>
      DiagnosisRecord(
        id: json['id'] ?? '',
        patientId: json['patientId'] ?? '',
        patientName: json['patientName'] ?? '',
        diseaseType: json['diseaseType'] ?? '',
        inputs: Map<String, dynamic>.from(json['inputs'] ?? {}),
        apiResponse: Map<String, dynamic>.from(json['apiResponse'] ?? {}),
        timestamp: json['timestamp'] ?? '',
        checkedActions: List<int>.from(json['checkedActions'] ?? []),
      );

  String get riskLevel =>
      (apiResponse['risk_level'] ?? 'UNKNOWN').toString();

  int get riskScore =>
      (apiResponse['risk_score'] ?? 0) as int;

  String get recommendation =>
      (apiResponse['recommendation'] ?? '').toString();

  List<String> get checklist {
    final raw = apiResponse['checklist'];
    if (raw == null) return [];
    return List<String>.from(raw);
  }
}