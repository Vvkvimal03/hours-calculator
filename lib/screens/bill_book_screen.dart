import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'machine_owner_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

// Conditional import for File (only on mobile/desktop)
import 'dart:io' if (dart.library.html) 'dart:html' as io;

class BillEntry {
  final String id;
  String name;
  String mobile;
  String time;
  String advance;
  DateTime date;
  String village;
  String machineOwner;
  String paid; // "yes" or "no"
  DateTime createdDate; // Auto-saved, not visible in UI
  DateTime? updatedAt; // Auto-saved on update, not visible in UI

  BillEntry({
    required this.id,
    required this.name,
    required this.mobile,
    required this.time,
    required this.advance,
    required this.date,
    required this.village,
    required this.machineOwner,
    required this.paid,
    required this.createdDate,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'mobile': mobile,
        'time': time,
        'advance': advance,
        'date': date.toIso8601String(),
        'village': village,
        'machineOwner': machineOwner,
        'paid': paid,
        'createdDate': createdDate.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
  factory BillEntry.fromMap(Map<String, dynamic> m) {
    // Handle migration from boolean to string
    String paidValue;
    if (m['paid'] is bool) {
      paidValue = (m['paid'] as bool) ? 'yes' : 'no';
    } else {
      paidValue = (m['paid'] ?? 'no') as String;
    }
    
    return BillEntry(
      id: m['id'] as String,
      name: (m['name'] ?? '') as String,
      mobile: (m['mobile'] ?? '') as String,
      time: (m['time'] ?? '') as String,
      advance: (m['advance'] ?? '') as String,
      date: DateTime.tryParse((m['date'] ?? '') as String) ?? DateTime.now(),
      village: (m['village'] ?? '') as String,
      machineOwner: (m['machineOwner'] ?? '') as String,
      paid: paidValue,
      createdDate: DateTime.tryParse((m['createdDate'] ?? '') as String) ?? DateTime.now(),
      updatedAt: m['updatedAt'] != null ? DateTime.tryParse((m['updatedAt'] ?? '') as String) : null,
    );
  }
}

class BillBookScreen extends StatefulWidget {
  const BillBookScreen({Key? key}) : super(key: key);

  @override
  State<BillBookScreen> createState() => _BillBookScreenState();
}

class _BillBookScreenState extends State<BillBookScreen> {
  static const String _prefsBillsKey = 'bill_book_entries_v2';
  static const String _prefsNamesKey = 'bill_book_names_v1';
  static const String _prefsVillagesKey = 'bill_book_villages_v1';
  static const String _prefsMachineOwnersKey = 'bill_book_machine_owners_v1';
  static const String _prefsMachineOwnersListKey = 'machine_owners_v1';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey _formCardKey = GlobalKey();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _mobileCtrl = TextEditingController();
  final TextEditingController _timeHoursCtrl = TextEditingController();
  final TextEditingController _timeMinutesCtrl = TextEditingController();
  final TextEditingController _advanceCtrl = TextEditingController();
  final TextEditingController _villageCtrl = TextEditingController();
  String _paid = 'no'; // "yes" or "no"
  DateTime _selectedDate = DateTime.now(); // Selectable date

  // Filter controllers
  final TextEditingController _filterNameCtrl = TextEditingController();
  final TextEditingController _filterMobileCtrl = TextEditingController();
  final TextEditingController _filterTimeHoursCtrl = TextEditingController();
  final TextEditingController _filterTimeMinutesCtrl = TextEditingController();
  final TextEditingController _filterAdvanceCtrl = TextEditingController();
  final TextEditingController _filterVillageCtrl = TextEditingController();
  final TextEditingController _filterDateCtrl = TextEditingController();
  String? _filterMachineOwner; // Dropdown selection for machine owner filter
  String? _filterPaid; // "yes", "no", or null for all

  final List<String> _names = <String>[];
  final List<String> _villages = <String>[];
  final List<String> _machineOwners = <String>[];
  final List<BillEntry> _bills = <BillEntry>[];
  List<BillEntry> _filteredBills = <BillEntry>[];
  String? _selectedMachineOwner;
  String? _editingId; // Track which entry is being edited
  final Map<String, TextEditingController> _autocompleteControllers = {};

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _timeHoursCtrl.dispose();
    _timeMinutesCtrl.dispose();
    _advanceCtrl.dispose();
    _villageCtrl.dispose();
    _filterNameCtrl.dispose();
    _filterMobileCtrl.dispose();
    _filterTimeHoursCtrl.dispose();
    _filterTimeMinutesCtrl.dispose();
    _filterAdvanceCtrl.dispose();
    _filterVillageCtrl.dispose();
    _filterDateCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    // Add listeners to filter controllers
    _filterNameCtrl.addListener(_applyFilters);
    _filterMobileCtrl.addListener(_applyFilters);
    _filterTimeHoursCtrl.addListener(_applyFilters);
    _filterTimeMinutesCtrl.addListener(_applyFilters);
    _filterAdvanceCtrl.addListener(_applyFilters);
    _filterVillageCtrl.addListener(_applyFilters);
    _filterDateCtrl.addListener(_applyFilters);
  }

  Future<void> _loadData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> rawBills = prefs.getStringList(_prefsBillsKey) ?? <String>[];
    final List<String> rawNames = prefs.getStringList(_prefsNamesKey) ?? <String>[];
    final List<String> rawVillages = prefs.getStringList(_prefsVillagesKey) ?? <String>[];
    final List<String> rawMachineOwners = prefs.getStringList(_prefsMachineOwnersKey) ?? <String>[];
    final List<String> rawMachineOwnersList = prefs.getStringList(_prefsMachineOwnersListKey) ?? <String>[];
    setState(() {
      _bills
        ..clear()
        ..addAll(rawBills.map((e) {
          final Map<String, dynamic> map = json.decode(e) as Map<String, dynamic>;
          // Handle migration from v1 to v2 (add machineOwner if missing)
          if (!map.containsKey('machineOwner')) {
            map['machineOwner'] = '';
          }
          // Handle migration: add createdDate if missing (use date as fallback)
          if (!map.containsKey('createdDate')) {
            map['createdDate'] = map['date'] ?? DateTime.now().toIso8601String();
          }
          return BillEntry.fromMap(map);
        }));
      _names
        ..clear()
        ..addAll(rawNames);
      _villages
        ..clear()
        ..addAll(rawVillages);
      _machineOwners
        ..clear()
        ..addAll(rawMachineOwners);
      // Load machine owner names from machine owner list
      for (final String ownerJson in rawMachineOwnersList) {
        try {
          final Map<String, dynamic> ownerMap = json.decode(ownerJson) as Map<String, dynamic>;
          final String ownerName = (ownerMap['name'] ?? '') as String;
          if (ownerName.isNotEmpty && !_machineOwners.contains(ownerName)) {
            _machineOwners.add(ownerName);
          }
        } catch (e) {
          // Skip invalid entries
        }
      }
      if (_names.isEmpty) {
        _names.addAll(<String>[
          'Arun','Balaji','Chandru','Dinesh','Elango','Gopi','Hari','Ilayaraja','Jaya','Kavin','Karthik','Kumar','Latha','Muthu','Naveen','Prabhu','Raja','Saravanan','Selvam','Siva','Subash','Thiru','Udhay','Vasanth','Vel','Yuva'
        ]);
      }
      _applyFilters();
    });
  }

  Future<void> _refreshMachineOwners() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> rawMachineOwnersList = prefs.getStringList(_prefsMachineOwnersListKey) ?? <String>[];
    setState(() {
      _machineOwners.clear();
      for (final String ownerJson in rawMachineOwnersList) {
        try {
          final Map<String, dynamic> ownerMap = json.decode(ownerJson) as Map<String, dynamic>;
          final String ownerName = (ownerMap['name'] ?? '') as String;
          if (ownerName.isNotEmpty && !_machineOwners.contains(ownerName)) {
            _machineOwners.add(ownerName);
          }
        } catch (e) {
          // Skip invalid entries
        }
      }
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredBills = _bills.where((bill) {
        // Filter by name
        if (_filterNameCtrl.text.isNotEmpty &&
            !bill.name.toLowerCase().contains(_filterNameCtrl.text.toLowerCase())) {
          return false;
        }
        // Filter by mobile
        if (_filterMobileCtrl.text.isNotEmpty &&
            !bill.mobile.toLowerCase().contains(_filterMobileCtrl.text.toLowerCase())) {
          return false;
        }
        // Filter by time (hours)
        if (_filterTimeHoursCtrl.text.isNotEmpty) {
          final List<String> timeParts = bill.time.split(RegExp(r'[h\s]+'));
          final String hours = timeParts.isNotEmpty ? timeParts[0] : '';
          if (!hours.contains(_filterTimeHoursCtrl.text)) {
            return false;
          }
        }
        // Filter by time (minutes)
        if (_filterTimeMinutesCtrl.text.isNotEmpty) {
          final List<String> timeParts = bill.time.split(RegExp(r'[h\s]+'));
          final String minutes = timeParts.length > 1 ? timeParts[1].replaceAll('m', '').trim() : '';
          if (!minutes.contains(_filterTimeMinutesCtrl.text)) {
            return false;
          }
        }
        // Filter by advance
        if (_filterAdvanceCtrl.text.isNotEmpty &&
            !bill.advance.toLowerCase().contains(_filterAdvanceCtrl.text.toLowerCase())) {
          return false;
        }
        // Filter by village
        if (_filterVillageCtrl.text.isNotEmpty &&
            !bill.village.toLowerCase().contains(_filterVillageCtrl.text.toLowerCase())) {
          return false;
        }
        // Filter by machine owner
        if (_filterMachineOwner != null && _filterMachineOwner!.isNotEmpty &&
            bill.machineOwner != _filterMachineOwner) {
          return false;
        }
        // Filter by date
        if (_filterDateCtrl.text.isNotEmpty) {
          final String billDate = _formatDate(bill.date);
          if (!billDate.contains(_filterDateCtrl.text)) {
            return false;
          }
        }
        // Filter by paid status
        if (_filterPaid != null && bill.paid != _filterPaid) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _saveBills() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsBillsKey,
      _bills.map((e) => json.encode(e.toMap())).toList(growable: false),
    );
  }

  Future<void> _saveNames() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsNamesKey, _names);
  }

  Future<void> _saveVillages() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsVillagesKey, _villages);
  }

  Future<void> _saveMachineOwners() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsMachineOwnersKey, _machineOwners);
  }

  String _formatDate(DateTime dt) {
    final DateTime l = dt.toLocal();
    final String y = l.year.toString().padLeft(4, '0');
    final String m = l.month.toString().padLeft(2, '0');
    final String d = l.day.toString().padLeft(2, '0');
    return '$d-$m-$y'; // DD-MM-YYYY format
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Note: Paid checkbox is always set (defaults to false), so it's considered mandatory
    // The asterisk (*) indicates it's a required field that must be explicitly set
    
    // Get name from autocomplete controller if available, otherwise from _nameCtrl
    final String name = (_autocompleteControllers.containsKey('name') && _autocompleteControllers['name'] != null
        ? _autocompleteControllers['name']!.text
        : _nameCtrl.text).trim();
    if (name.isNotEmpty && !_names.contains(name)) {
      setState(() => _names.add(name));
      await _saveNames();
    }
    // Get village from autocomplete controller if available, otherwise from _villageCtrl
    final String villageText = (_autocompleteControllers.containsKey('village') && _autocompleteControllers['village'] != null
        ? _autocompleteControllers['village']!.text
        : _villageCtrl.text).trim();
    if (villageText.isNotEmpty && !_villages.contains(villageText)) {
      setState(() => _villages.add(villageText));
      await _saveVillages();
    }
    final String hours = _timeHoursCtrl.text.trim();
    final String minutes = _timeMinutesCtrl.text.trim();
    final String timeString = '${hours.isEmpty ? '0' : hours}h ${minutes.isEmpty ? '0' : minutes}m';
    
    if (_editingId != null) {
      // Update existing entry
      final int idx = _bills.indexWhere((e) => e.id == _editingId);
      if (idx != -1) {
        setState(() {
          _bills[idx].name = name;
          _bills[idx].mobile = _mobileCtrl.text.trim();
          _bills[idx].time = timeString;
          _bills[idx].advance = _advanceCtrl.text.trim();
          _bills[idx].date = _selectedDate; // Use selected date
          _bills[idx].village = villageText;
          _bills[idx].machineOwner = _selectedMachineOwner ?? '';
          _bills[idx].paid = _paid;
          _bills[idx].updatedAt = DateTime.now(); // Auto-save updatedAt
          // Keep original createdDate when updating
        });
        await _saveBills();
        _applyFilters();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill updated')),
        );
      }
    } else {
      // Create new entry
      final DateTime now = DateTime.now();
      final BillEntry entry = BillEntry(
        id: UniqueKey().toString(),
        name: name,
        mobile: _mobileCtrl.text.trim(),
        time: timeString,
        advance: _advanceCtrl.text.trim(),
        date: _selectedDate, // Use selected date
        village: villageText,
        machineOwner: _selectedMachineOwner ?? '',
        paid: _paid,
        createdDate: now, // Auto-save created date (hidden field)
      );
      setState(() {
        _bills.insert(0, entry);
      });
      await _saveBills();
      _applyFilters();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill saved')),
      );
    }
    _clearForm();
  }

  void _clearForm() {
    _nameCtrl.clear();
    _mobileCtrl.clear();
    _timeHoursCtrl.clear();
    _timeMinutesCtrl.clear();
    _advanceCtrl.clear();
    _villageCtrl.clear();
    setState(() {
      _selectedMachineOwner = null;
      _editingId = null;
      _paid = 'no';
      _selectedDate = DateTime.now(); // Reset to current date
    });
  }

  void _populateFormForEdit(BillEntry entry) {
    _nameCtrl.text = entry.name;
    _mobileCtrl.text = entry.mobile;
    _advanceCtrl.text = entry.advance;
    _villageCtrl.text = entry.village;
    
    setState(() {
      _selectedMachineOwner = entry.machineOwner.isEmpty ? null : entry.machineOwner;
      _paid = entry.paid;
      _editingId = entry.id;
      _selectedDate = entry.date; // Load the entry's date
    });
    
    // Update autocomplete controllers if they exist (after setState and widget rebuild)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final nameController = _autocompleteControllers['name'];
          final villageController = _autocompleteControllers['village'];
          if (nameController != null) {
            try {
              if (nameController.text != entry.name) {
                nameController.value = TextEditingValue(
                  text: entry.name,
                  selection: TextSelection.collapsed(offset: entry.name.length),
                );
              }
            } catch (e) {
              // Ignore errors if controller is disposed
            }
          }
          if (villageController != null) {
            try {
              if (villageController.text != entry.village) {
                villageController.value = TextEditingValue(
                  text: entry.village,
                  selection: TextSelection.collapsed(offset: entry.village.length),
                );
              }
            } catch (e) {
              // Ignore errors if controller is disposed
            }
          }
        }
      });
    });
    
    // Parse time string to extract hours and minutes
    // Handle formats like "2h 30m", "2h30m", "2 h 30 m", etc.
    final RegExp timeRegex = RegExp(r'(\d+)\s*h\s*(\d+)\s*m');
    final Match? match = timeRegex.firstMatch(entry.time);
    if (match != null) {
      _timeHoursCtrl.text = match.group(1) ?? '0';
      _timeMinutesCtrl.text = match.group(2) ?? '0';
    } else {
      // Fallback: try to extract just hours if format is different
      final RegExp hoursOnlyRegex = RegExp(r'(\d+)\s*h');
      final Match? hoursMatch = hoursOnlyRegex.firstMatch(entry.time);
      if (hoursMatch != null) {
        _timeHoursCtrl.text = hoursMatch.group(1) ?? '0';
        _timeMinutesCtrl.text = '0';
      } else {
        _timeHoursCtrl.text = '0';
        _timeMinutesCtrl.text = '0';
      }
    }
  }

  void _showEditDialog(BillEntry entry) {
    _populateFormForEdit(entry);
    // Scroll to form to show the edit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderObject? renderObject = _formCardKey.currentContext?.findRenderObject();
      if (renderObject != null) {
        Scrollable.ensureVisible(
          _formCardKey.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit the form above and click Update'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearFilters() {
    _filterNameCtrl.clear();
    _filterMobileCtrl.clear();
    _filterTimeHoursCtrl.clear();
    _filterTimeMinutesCtrl.clear();
    _filterAdvanceCtrl.clear();
    _filterVillageCtrl.clear();
    _filterDateCtrl.clear();
    setState(() => _filterMachineOwner = null);
    setState(() => _filterPaid = null);
    _applyFilters();
  }

  Future<void> _downloadCSV() async {
    if (_filteredBills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }

    final StringBuffer csv = StringBuffer();
    // CSV Header with Serial Number, Created At, and Updated At
    csv.writeln('S.No,Name,Mobile,Time,Advance,Date,Village,Machine Owner,Paid,Created At,Updated At');
    
    // CSV Data
    int serialNumber = 1;
    for (final bill in _filteredBills) {
      csv.writeln([
        serialNumber.toString(),
        '"${bill.name}"',
        '"${bill.mobile}"',
        '"${bill.time}"',
        '"${bill.advance}"',
        '"${_formatDate(bill.date)}"',
        '"${bill.village}"',
        '"${bill.machineOwner}"',
        '"${bill.paid}"',
        '"${_formatDate(bill.createdDate)}"',
        bill.updatedAt != null ? '"${_formatDate(bill.updatedAt!)}"' : '""',
      ].join(','));
      serialNumber++;
    }

    // Generate CSV content
    final String csvContent = csv.toString();
    final String fileName = 'bill_book_${DateTime.now().millisecondsSinceEpoch}.csv';

    if (kIsWeb) {
      // For web, download the CSV directly
      try {
        final blob = html.Blob([csvContent], 'text/csv');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading CSV: $e')),
        );
        return;
      }
    } else {
      // For mobile/desktop, save file and share
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = io.File('${directory.path}/$fileName');
        await file.writeAsString(csvContent);
        
        final XFile xFile = XFile(file.path);
        await Share.shareXFiles(
          [xFile],
          text: 'Bill Book Export',
          subject: fileName,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving CSV: $e')),
        );
        return;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${_filteredBills.length} bills as CSV')),
    );
  }

  Future<void> _downloadPDF() async {
    if (_filteredBills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          int serialNumber = 1;
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Bill Book Report',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Total Bills: ${_filteredBills.length} | Generated: ${_formatDate(DateTime.now())}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FixedColumnWidth(30),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(0.8),
                4: const pw.FlexColumnWidth(0.8),
                5: const pw.FlexColumnWidth(1),
                6: const pw.FlexColumnWidth(1),
                7: const pw.FlexColumnWidth(1.2),
                8: const pw.FlexColumnWidth(0.6),
                9: const pw.FlexColumnWidth(1),
                10: const pw.FlexColumnWidth(1),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('S.No', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Mobile', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Time', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Advance', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Village', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Owner', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Paid', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Created', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Updated', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  ],
                ),
                // Data rows
                ..._filteredBills.map((bill) {
                  final row = pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('${serialNumber++}', style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(bill.name, style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(bill.mobile, style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(bill.time, style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(bill.advance.isEmpty ? '0' : bill.advance, style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(_formatDate(bill.date), style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(bill.village.isEmpty ? '—' : bill.village, style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(bill.machineOwner.isEmpty ? '—' : bill.machineOwner, style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(bill.paid == 'yes' ? 'Yes' : 'No', style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(_formatDate(bill.createdDate), style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(bill.updatedAt != null ? _formatDate(bill.updatedAt!) : '—', style: const pw.TextStyle(fontSize: 7))),
                    ],
                  );
                  return row;
                }),
              ],
            ),
          ];
        },
      ),
    );

    // Generate PDF bytes
    final pdfBytes = await pdf.save();
    final String fileName = 'bill_book_${DateTime.now().millisecondsSinceEpoch}.pdf';

    if (kIsWeb) {
      // For web, download the PDF directly
      try {
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } catch (e) {
        // Fallback: use printing package
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
        );
      }
    } else {
      // For mobile/desktop, use printing package to share/save
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${_filteredBills.length} bills as PDF')),
    );
  }

  Future<void> _togglePaid(String id, String value) async {
    final int idx = _bills.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    setState(() => _bills[idx].paid = value);
    await _saveBills();
    _applyFilters();
  }

  Future<void> _deleteBill(String id) async {
    setState(() => _bills.removeWhere((e) => e.id == id));
    await _saveBills();
    _applyFilters();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filters'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _filterNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _filterMobileCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mobile',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _filterTimeHoursCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Hours',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _filterTimeMinutesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Minutes',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _filterAdvanceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Advance',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _filterVillageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Village',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _filterMachineOwner,
                decoration: const InputDecoration(
                  labelText: 'Machine Owner',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All'),
                  ),
                  ..._machineOwners.map((owner) {
                    return DropdownMenuItem<String?>(
                      value: owner,
                      child: Text(owner),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterMachineOwner = value;
                    _applyFilters();
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _filterDateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _filterPaid,
                decoration: const InputDecoration(
                  labelText: 'Paid Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All')),
                  DropdownMenuItem(value: 'yes', child: Text('Yes')),
                  DropdownMenuItem(value: 'no', child: Text('No')),
                ],
                onChanged: (value) {
                  setState(() => _filterPaid = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _clearFilters();
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () {
              _applyFilters();
              Navigator.of(context).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Book', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          if (_filteredBills.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.download),
              tooltip: 'Download',
              onSelected: (value) {
                if (value == 'csv') {
                  _downloadCSV();
                } else if (value == 'pdf') {
                  _downloadPDF();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'csv',
                  child: Row(
                    children: [
                      Icon(Icons.file_download, size: 20),
                      SizedBox(width: 8),
                      Text('Download as CSV'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, size: 20),
                      SizedBox(width: 8),
                      Text('Download as PDF'),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filters',
          ),
        ],
      ),
      body: Column(
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Card(
                  key: _formCardKey,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Row(
                        children: [
                          Expanded(
                            child: Autocomplete<String>(
                              key: ValueKey('name_${_editingId ?? 'new'}'),
                              optionsBuilder: (TextEditingValue value) {
                                final String q = value.text.toLowerCase();
                                if (q.isEmpty) return const Iterable<String>.empty();
                                return _names.where((n) => n.toLowerCase().contains(q));
                              },
                              fieldViewBuilder: (context, controller, focus, onSubmit) {
                                // Store controller reference for later use
                                _autocompleteControllers['name'] = controller;
                                
                                // Initialize value after build if we have a value
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted && _nameCtrl.text.isNotEmpty && controller.text != _nameCtrl.text) {
                                    controller.value = TextEditingValue(
                                      text: _nameCtrl.text,
                                      selection: TextSelection.collapsed(offset: _nameCtrl.text.length),
                                    );
                                  }
                                });
                                
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focus,
                                  decoration: const InputDecoration(
                                    labelText: 'Name *',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                );
                              },
                              onSelected: (s) {
                                _nameCtrl.text = s;
                                // Also update the autocomplete controller if it exists
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  final controller = _autocompleteControllers['name'];
                                  if (mounted && controller != null) {
                                    try {
                                      controller.value = TextEditingValue(
                                        text: s,
                                        selection: TextSelection.collapsed(offset: s.length),
                                      );
                                    } catch (e) {
                                      // Ignore if controller is disposed
                                    }
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _mobileCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Mobile number *',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _timeHoursCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Hours *',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _timeMinutesCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Minutes *',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _advanceCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Advance',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null && picked != _selectedDate) {
                                  setState(() {
                                    _selectedDate = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date *',
                                  border: OutlineInputBorder(),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDate(_selectedDate)),
                                    const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Autocomplete<String>(
                              key: ValueKey('village_${_editingId ?? 'new'}'),
                              optionsBuilder: (TextEditingValue value) {
                                final String q = value.text.toLowerCase();
                                if (q.isEmpty) return const Iterable<String>.empty();
                                return _villages.where((n) => n.toLowerCase().contains(q));
                              },
                              fieldViewBuilder: (context, controller, focus, onSubmit) {
                                // Store controller reference for later use
                                _autocompleteControllers['village'] = controller;
                                
                                // Initialize value after build if we have a value
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted && _villageCtrl.text.isNotEmpty && controller.text != _villageCtrl.text) {
                                    controller.value = TextEditingValue(
                                      text: _villageCtrl.text,
                                      selection: TextSelection.collapsed(offset: _villageCtrl.text.length),
                                    );
                                  }
                                });
                                
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focus,
                                  decoration: const InputDecoration(
                                    labelText: 'Village *',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                );
                              },
                              onSelected: (s) {
                                _villageCtrl.text = s;
                                // Also update the autocomplete controller if it exists
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  final controller = _autocompleteControllers['village'];
                                  if (mounted && controller != null) {
                                    try {
                                      controller.value = TextEditingValue(
                                        text: s,
                                        selection: TextSelection.collapsed(offset: s.length),
                                      );
                                    } catch (e) {
                                      // Ignore if controller is disposed
                                    }
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedMachineOwner,
                              decoration: const InputDecoration(
                                labelText: 'Machine Owner *',
                                border: OutlineInputBorder(),
                              ),
                              items: _machineOwners.map((owner) {
                                return DropdownMenuItem(
                                  value: owner,
                                  child: Text(owner),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedMachineOwner = value);
                              },
                              validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const MachineOwnerListScreen()),
                              );
                              await _refreshMachineOwners();
                            },
                            tooltip: 'Manage Machine Owners',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _paid == 'yes',
                            onChanged: (v) => setState(() => _paid = (v ?? false) ? 'yes' : 'no'),
                          ),
                          const Text('Paid'),
                          const Spacer(),
                          if (_editingId != null)
                            TextButton(
                              onPressed: () => _clearForm(),
                              child: const Text('Cancel'),
                            ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _submit,
                            icon: Icon(_editingId != null ? Icons.update : Icons.save_outlined),
                            label: Text(_editingId != null ? 'Update' : 'Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredBills.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _bills.isEmpty ? 'No bills yet' : 'No bills match filters',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculate item width (with margins)
                      const double itemMargin = 12.0;
                      const double minItemWidth = 280.0;
                      final double availableWidth = constraints.maxWidth - (itemMargin * 2);
                      final int itemsPerRow = (availableWidth / minItemWidth).floor().clamp(1, 3);
                      final double actualItemWidth = (availableWidth - (itemMargin * (itemsPerRow - 1))) / itemsPerRow;

                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        padding: EdgeInsets.all(itemMargin),
                        child: Wrap(
                          direction: Axis.horizontal,
                          spacing: itemMargin,
                          runSpacing: itemMargin,
                          children: _filteredBills.map((b) {
                            return SizedBox(
                              width: actualItemWidth,
                              child: Card(
                                margin: EdgeInsets.zero,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey[200]!),
                                ),
                                child: InkWell(
                                  onTap: () => _showEditDialog(b),
                                  borderRadius: BorderRadius.circular(12),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    title: Text(
                                      '${b.name} • ${b.village.isEmpty ? '—' : b.village}',
                                      style: const TextStyle(fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        'Time: ${b.time}\nAdv: ${b.advance.isEmpty ? '0' : b.advance}\nDate: ${_formatDate(b.date)}\nMobile: ${b.mobile.isEmpty ? '—' : b.mobile}\nOwner: ${b.machineOwner.isEmpty ? '—' : b.machineOwner}\nPaid: ${b.paid == 'yes' ? 'Yes' : 'No'}\nCreated: ${_formatDate(b.createdDate)}${b.updatedAt != null ? '\nUpdated: ${_formatDate(b.updatedAt!)}' : ''}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    isThreeLine: false,
                                    dense: true,
                                  leading: Checkbox(
                                    value: b.paid == 'yes',
                                    onChanged: (v) => _togglePaid(b.id, (v ?? false) ? 'yes' : 'no'),
                                  ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20),
                                      onPressed: () => _deleteBill(b.id),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
