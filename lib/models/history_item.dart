import 'dart:convert';

import 'time_entry.dart';

class HistoryItem {
  final String id;
  final String title;
  final List<TimeEntry> entries;
  final DateTime createdAt;

  HistoryItem({
    required this.id,
    required this.title,
    required this.entries,
    required this.createdAt,
  });

  int get totalMinutes =>
      entries.fold<int>(0, (sum, e) => sum + e.totalMinutes);

  String get totalTimeFormatted {
    final int minutes = totalMinutes % 60;
    final int hours = (totalMinutes - minutes) ~/ 60;
    final String mm = minutes.toString().padLeft(2, '0');
    final String hh = hours.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String get formattedTimestamp {
    final DateTime dt = createdAt.toLocal();
    final String y = dt.year.toString().padLeft(4, '0');
    final String mo = dt.month.toString().padLeft(2, '0');
    final String d = dt.day.toString().padLeft(2, '0');
    final String h = dt.hour.toString().padLeft(2, '0');
    final String mi = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'entries': entries.map((e) => e.toMap()).toList(growable: false),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    final DateTime created = DateTime.parse(map['createdAt'] as String);
    final String computedTitle =
        (map['title'] as String?) ?? defaultTitleFor(created);
    return HistoryItem(
      id: map['id'] as String,
      title: computedTitle,
      entries: (map['entries'] as List<dynamic>)
          .map((e) => TimeEntry.fromMap(e as Map<String, dynamic>))
          .toList(growable: false),
      createdAt: created,
    );
  }

  String toJson() => json.encode(toMap());

  factory HistoryItem.fromJson(String source) =>
      HistoryItem.fromMap(json.decode(source) as Map<String, dynamic>);

  static String defaultTitleFor(DateTime dt) {
    final DateTime local = dt.toLocal();
    final String y = local.year.toString().padLeft(4, '0');
    final String mo = local.month.toString().padLeft(2, '0');
    final String d = local.day.toString().padLeft(2, '0');
    final String h = local.hour.toString().padLeft(2, '0');
    final String mi = local.minute.toString().padLeft(2, '0');
    return 'Saved $y-$mo-$d $h:$mi';
  }
}
