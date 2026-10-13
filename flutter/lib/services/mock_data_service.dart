import 'dart:math';

import '../models/models.dart';

class MockDataService {
  static final List<BloodTest> _tests = [
    BloodTest(
      id: 'test_001',
      name: 'Full Blood Count',
      category: 'General',
      description:
          'Evaluates red blood cells, white blood cells, haemoglobin and platelet levels.',
      prepInstructions:
          'No fasting required. Drink water normally and continue with your daily routine.',
      turnaroundDays: 2,
      price: 59.00,
      sampleType: 'Blood',
      icon: '🩸',
    ),
    BloodTest(
      id: 'test_002',
      name: 'Vitamin D',
      category: 'Wellness',
      description:
          'Measures vitamin D levels to support immune function, bone health, and energy.',
      prepInstructions:
          'No special preparation required. If you are taking supplements, note this in your appointment.',
      turnaroundDays: 3,
      price: 79.00,
      sampleType: 'Blood',
      icon: '☀️',
    ),
    BloodTest(
      id: 'test_003',
      name: 'Thyroid Panel',
      category: 'Hormone',
      description:
          'Checks thyroid hormones to assess metabolism, energy and endocrine balance.',
      prepInstructions:
          'No fasting needed. Avoid taking iodine supplements before the test if advised.',
      turnaroundDays: 3,
      price: 89.00,
      sampleType: 'Blood',
      icon: '🧠',
    ),
    BloodTest(
      id: 'test_004',
      name: 'Liver Function Test',
      category: 'General',
      description:
          'Assesses liver enzymes and function markers for a better health overview.',
      prepInstructions:
          'Fasting for 8-12 hours is recommended for best accuracy.',
      turnaroundDays: 2,
      price: 69.00,
      sampleType: 'Blood',
      icon: '🧪',
    ),
    BloodTest(
      id: 'test_005',
      name: 'Diabetes Screening',
      category: 'Metabolic',
      description:
          'Checks glucose and HbA1c levels to help identify diabetes risk.',
      prepInstructions:
          'Morning appointment recommended. Fast for 8-12 hours if possible.',
      turnaroundDays: 2,
      price: 95.00,
      sampleType: 'Blood',
      icon: '📉',
    ),
    BloodTest(
      id: 'test_006',
      name: 'Cholesterol Profile',
      category: 'Cardio',
      description:
          'Measures HDL, LDL, total cholesterol and triglycerides for heart health.',
      prepInstructions:
          'Fast for 8-12 hours before your blood draw for the most accurate reading.',
      turnaroundDays: 2,
      price: 74.00,
      sampleType: 'Blood',
      icon: '❤️',
    ),
  ];

  static final List<Appointment> _appointments = [
    Appointment(
      id: 'appt_001',
      testName: 'Full Blood Count',
      dateTime: DateTime.now().add(const Duration(days: 2, hours: 4)),
      status: 'Confirmed',
      amount: 59.00,
    ),
    Appointment(
      id: 'appt_002',
      testName: 'Vitamin D',
      dateTime: DateTime.now().subtract(const Duration(days: 10)),
      status: 'Completed',
      amount: 79.00,
    ),
  ];

  static final List<LabResult> _results = [
    LabResult(
      id: 'res_001',
      testName: 'Vitamin D',
      status: 'Ready',
      issuedAt: DateTime.now().subtract(const Duration(days: 3)),
      summary: 'Vitamin D is within the healthy range. Continue your current routine.',
      fileUrl: 'https://example.com/result-vitamin-d.pdf',
    ),
    LabResult(
      id: 'res_002',
      testName: 'Full Blood Count',
      status: 'Ready',
      issuedAt: DateTime.now().subtract(const Duration(days: 14)),
      summary: 'Results are normal. A follow-up consultation is optional.',
      fileUrl: 'https://example.com/result-fbc.pdf',
    ),
  ];

  static List<BloodTest> getTests() {
    return List.unmodifiable(_tests);
  }

  static List<BloodTest> searchTests(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return getTests();

    return _tests.where((test) {
      return test.name.toLowerCase().contains(q) ||
          test.category.toLowerCase().contains(q) ||
          test.description.toLowerCase().contains(q);
    }).toList();
  }

  static BloodTest? getTestById(String id) {
    try {
      return _tests.firstWhere((element) => element.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<Appointment> getAppointments() {
    return List.unmodifiable(_appointments);
  }

  static List<LabResult> getResults() {
    return List.unmodifiable(_results);
  }

  static Future<void> bookAppointment({
    required BloodTest test,
    required DateTime selectedDateTime,
    required String patientName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final appointment = Appointment(
      id: 'appt_${DateTime.now().millisecondsSinceEpoch}',
      testName: test.name,
      dateTime: selectedDateTime,
      status: 'Confirmed',
      amount: test.price,
    );

    _appointments.insert(0, appointment);
  }
}
