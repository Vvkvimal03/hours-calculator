import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/time_entry.dart';
import '../models/history_item.dart';

class TimeCalculatorProvider extends ChangeNotifier {
  static const String _prefsHistoryKey = 'time_history_items_v2';

  final List<TimeEntry> _currentEntries = <TimeEntry>[];
  final List<HistoryItem> _historyItems = <HistoryItem>[];

  List<TimeEntry> get currentEntries =>
      List<TimeEntry>.unmodifiable(_currentEntries);
  List<HistoryItem> get historyItems =>
      List<HistoryItem>.unmodifiable(_historyItems);

  int get totalCurrentMinutes =>
      _currentEntries.fold<int>(0, (sum, e) => sum + e.totalMinutes);

  String get totalCurrentHhMm {
    final int minutes = totalCurrentMinutes % 60;
    final int hours = (totalCurrentMinutes - minutes) ~/ 60;
    final String mm = minutes.toString().padLeft(2, '0');
    final String hh = hours.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> loadFromStorage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> rawList =
        prefs.getStringList(_prefsHistoryKey) ?? <String>[];
    _historyItems
      ..clear()
      ..addAll(rawList.map(HistoryItem.fromJson));
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> rawList = _historyItems
        .map((e) => e.toJson())
        .toList(growable: false);
    await prefs.setStringList(_prefsHistoryKey, rawList);
  }

  void addCurrentEntry({required int hours, required int minutes}) {
    final TimeEntry entry = TimeEntry(
      id: UniqueKey().toString(),
      hours: hours,
      minutes: minutes,
      createdAt: DateTime.now(),
    );
    _currentEntries.add(entry);
    notifyListeners();
  }

  Future<void> addEntriesFromMinutesBulk(List<int> minuteValues) async {
    if (minuteValues.isEmpty) return;
    final DateTime now = DateTime.now();
    for (final int minutesValue in minuteValues) {
      if (minutesValue <= 0) continue;
      final int h = minutesValue ~/ 60;
      final int m = minutesValue % 60;
      final TimeEntry entry = TimeEntry(
        id: UniqueKey().toString(),
        hours: h,
        minutes: m,
        createdAt: now,
      );
      _currentEntries.add(entry);
    }
    notifyListeners();
  }

  void updateCurrentEntry({
    required String id,
    required int hours,
    required int minutes,
  }) {
    final int idx = _currentEntries.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _currentEntries[idx].hours = hours;
    _currentEntries[idx].minutes = minutes;
    notifyListeners();
  }

  void removeCurrentEntry(String id) {
    _currentEntries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void clearCurrentEntries() {
    _currentEntries.clear();
    notifyListeners();
  }

  // History management (snapshots)
  Future<void> saveCurrentToHistory({String? title}) async {
    if (_currentEntries.isEmpty) return;
    final HistoryItem snapshot = HistoryItem(
      id: UniqueKey().toString(),
      title: title?.trim().isNotEmpty == true
          ? title!.trim()
          : HistoryItem.defaultTitleFor(DateTime.now()),
      entries: _currentEntries
          .map(
            (e) => TimeEntry(
              id: e.id,
              hours: e.hours,
              minutes: e.minutes,
              createdAt: e.createdAt,
            ),
          )
          .toList(growable: false),
      createdAt: DateTime.now(),
    );
    _historyItems.insert(0, snapshot);
    // Cap to 50
    if (_historyItems.length > 50) {
      _historyItems.removeRange(50, _historyItems.length);
    }
    await _saveHistory();
    notifyListeners();
  }

  Future<void> saveCurrentToHistoryAndClear({String? title}) async {
    await saveCurrentToHistory(title: title);
    _currentEntries.clear();
    notifyListeners();
  }

  void restoreFromHistory(String id) {
    final int idx = _historyItems.indexWhere((h) => h.id == id);
    if (idx == -1) return;
    final HistoryItem item = _historyItems[idx];
    _currentEntries
      ..clear()
      ..addAll(
        item.entries.map(
          (e) => TimeEntry(
            id: UniqueKey().toString(),
            hours: e.hours,
            minutes: e.minutes,
            createdAt: DateTime.now(),
          ),
        ),
      );
    notifyListeners();
  }

  Future<void> deleteHistoryItem(String id) async {
    _historyItems.removeWhere((e) => e.id == id);
    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _historyItems.clear();
    await _saveHistory();
    notifyListeners();
  }
}
