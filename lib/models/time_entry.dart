import 'dart:convert';

class TimeEntry {
  final String id;
  int hours;
  int minutes;
  final DateTime createdAt;

  TimeEntry({
    required this.id,
    required this.hours,
    required this.minutes,
    required this.createdAt,
  });

  int get totalMinutes => hours * 60 + minutes;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hours': hours,
      'minutes': minutes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TimeEntry.fromMap(Map<String, dynamic> map) {
    return TimeEntry(
      id: map['id'] as String,
      hours: map['hours'] as int,
      minutes: map['minutes'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  String toJson() => json.encode(toMap());

  factory TimeEntry.fromJson(String source) =>
      TimeEntry.fromMap(json.decode(source) as Map<String, dynamic>);
}
