class BloodTest {
  final String id;
  final String name;
  final String category;
  final String description;
  final String prepInstructions;
  final int turnaroundDays;
  final double price;
  final String sampleType;
  final String icon;

  const BloodTest({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.prepInstructions,
    required this.turnaroundDays,
    required this.price,
    required this.sampleType,
    required this.icon,
  });
}

class Appointment {
  final String id;
  final String testName;
  final DateTime dateTime;
  final String status;
  final double amount;

  Appointment({
    required this.id,
    required this.testName,
    required this.dateTime,
    required this.status,
    required this.amount,
  });
}

class LabResult {
  final String id;
  final String testName;
  final String status;
  final DateTime issuedAt;
  final String summary;
  final String fileUrl;

  LabResult({
    required this.id,
    required this.testName,
    required this.status,
    required this.issuedAt,
    required this.summary,
    required this.fileUrl,
  });
}
