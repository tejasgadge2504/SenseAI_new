import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/patient.dart';
import '../models/diagnosis_record.dart';

class StorageService {
  static const _patientsKey   = 'patients';
  static const _diagnosisKey  = 'diagnosis_records';
  static const _syncQueueKey  = 'sync_queue';

  // ─── Patients ─────────────────────────────────────────────────────────────

  static Future<List<Patient>> getPatients() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_patientsKey) ?? '[]';
    final List decoded = jsonDecode(raw);
    return decoded.map((e) => Patient.fromJson(e)).toList();
  }

  static Future<void> savePatient(Patient patient) async {
    final prefs = await SharedPreferences.getInstance();
    final patients = await getPatients();
    patients.add(patient);
    await prefs.setString(
        _patientsKey, jsonEncode(patients.map((p) => p.toJson()).toList()));
  }

  // ─── Diagnosis Records ────────────────────────────────────────────────────

  static Future<List<DiagnosisRecord>> getDiagnoses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_diagnosisKey) ?? '[]';
    final List decoded = jsonDecode(raw);
    return decoded.map((e) => DiagnosisRecord.fromJson(e)).toList();
  }

  /// Upsert — replaces existing record with same id, or appends if new.
  /// This prevents duplicates when saving checkedActions updates.
  static Future<void> saveDiagnosis(DiagnosisRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await getDiagnoses();
    final idx = records.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      records[idx] = record; // update existing
    } else {
      records.add(record);   // new record
    }
    await prefs.setString(
        _diagnosisKey, jsonEncode(records.map((r) => r.toJson()).toList()));
  }

  static Future<List<DiagnosisRecord>> getDiagnosesForPatient(
      String patientId) async {
    final all = await getDiagnoses();
    return all.where((r) => r.patientId == patientId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Count diagnoses recorded today
  static Future<int> getTodayDiagnosisCount() async {
    final all = await getDiagnoses();
    final today = DateTime.now();
    return all.where((r) {
      try {
        final dt = DateTime.parse(r.timestamp);
        return dt.year == today.year &&
            dt.month == today.month &&
            dt.day == today.day;
      } catch (_) {
        return false;
      }
    }).length;
  }

  // ─── Sync Queue ───────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_syncQueueKey) ?? '[]';
    final List decoded = jsonDecode(raw);
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> addToSyncQueue(
      String type, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await getSyncQueue();
    queue.add({
      'id':        DateTime.now().millisecondsSinceEpoch.toString(),
      'type':      type,
      'data':      data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_syncQueueKey, jsonEncode(queue));
  }

  static Future<void> clearSyncQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncQueueKey, '[]');
  }

  static Future<int> getSyncQueueLength() async {
    final queue = await getSyncQueue();
    return queue.length;
  }

  /// Wipe all local data (use once after schema changes, then remove call)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_patientsKey);
    await prefs.remove(_diagnosisKey);
    await prefs.remove(_syncQueueKey);
  }
}