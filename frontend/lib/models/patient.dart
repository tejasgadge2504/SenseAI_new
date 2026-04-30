class Patient {
  final String id;
  final String name;
  final int age;
  final String gender;
  final String registeredAt;
  final String phone;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.registeredAt,
    required this.phone,
  });

  Map<String, dynamic> toJson() =>
      {
        'id': id,
        'name': name,
        'age': age,
        'gender': gender,
        'registeredAt': registeredAt,
        'phone': phone, // ← add this
      };

  factory Patient.fromJson(Map<String, dynamic> json) =>
      Patient(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        age: json['age'] ?? 0,
        gender: json['gender'] ?? '',
        registeredAt: json['registeredAt'] ?? '',
        phone: json['phone'] ?? '', // ← add this
      );

}