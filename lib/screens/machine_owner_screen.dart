import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class MachineOwner {
  final String id;
  String name;
  String mobile;
  String address;
  String machineType;
  String machineNumber;

  MachineOwner({
    required this.id,
    required this.name,
    required this.mobile,
    required this.address,
    required this.machineType,
    required this.machineNumber,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'mobile': mobile,
        'address': address,
        'machineType': machineType,
        'machineNumber': machineNumber,
      };

  factory MachineOwner.fromMap(Map<String, dynamic> m) => MachineOwner(
        id: m['id'] as String,
        name: (m['name'] ?? '') as String,
        mobile: (m['mobile'] ?? '') as String,
        address: (m['address'] ?? '') as String,
        machineType: (m['machineType'] ?? '') as String,
        machineNumber: (m['machineNumber'] ?? '') as String,
      );
}

class MachineOwnerListScreen extends StatefulWidget {
  const MachineOwnerListScreen({Key? key}) : super(key: key);

  @override
  State<MachineOwnerListScreen> createState() => _MachineOwnerListScreenState();
}

class _MachineOwnerListScreenState extends State<MachineOwnerListScreen> {
  static const String _prefsKey = 'machine_owners_v1';

  // Hive box
  late Box _ownersBox;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _mobileCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _machineNumberCtrl = TextEditingController();

  String? _selectedMachineType; // Selected machine type from dropdown
  static const List<String> _machineTypes = ['kartar', 'class', 'gam', 'tyre'];

  List<MachineOwner> _owners = <MachineOwner>[];
  String? _editingId; // Track which owner is being edited

  @override
  void initState() {
    super.initState();
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    _ownersBox = Hive.box('machineOwners');
    
    // Migrate data from SharedPreferences to Hive (one-time migration)
    await _migrateFromSharedPreferences();
    
    // Load data from Hive
    _loadData();
  }

  Future<void> _migrateFromSharedPreferences() async {
    // Check if migration already done
    if (_ownersBox.get('_migrated', defaultValue: false) == true) {
      return; // Already migrated
    }

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> rawOwners = prefs.getStringList(_prefsKey) ?? <String>[];
      
      for (final String ownerJson in rawOwners) {
        try {
          final Map<String, dynamic> ownerMap = json.decode(ownerJson) as Map<String, dynamic>;
          String ownerId = ownerMap['id'] as String? ?? UniqueKey().toString();
          
          // Store in Hive using owner ID as key
          _ownersBox.put(ownerId, ownerMap);
        } catch (e) {
          // Skip invalid entries
        }
      }
      
      // Mark migration as complete
      _ownersBox.put('_migrated', true);
    } catch (e) {
      // Migration failed, but continue anyway
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    _machineNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Load all owners from Hive
    final List<MachineOwner> owners = [];
    for (final key in _ownersBox.keys) {
      if (key is String && key != '_migrated') {
        try {
          final dynamic ownerData = _ownersBox.get(key);
          if (ownerData != null) {
            final Map<String, dynamic> ownerMap = ownerData is Map
                ? Map<String, dynamic>.from(ownerData)
                : json.decode(ownerData.toString()) as Map<String, dynamic>;
            owners.add(MachineOwner.fromMap(ownerMap));
          }
        } catch (e) {
          // Skip invalid entries
        }
      }
    }
    
    setState(() {
      _owners = owners;
    });
  }

  Future<void> _saveData() async {
    // Clear existing entries (except migration flag)
    for (final key in _ownersBox.keys) {
      if (key is String && key != '_migrated') {
        await _ownersBox.delete(key);
      }
    }
    
    // Save all owners to Hive
    for (final owner in _owners) {
      _ownersBox.put(owner.id, owner.toMap());
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_editingId != null) {
      // Update existing owner
      final int idx = _owners.indexWhere((e) => e.id == _editingId);
      if (idx != -1) {
        setState(() {
          _owners[idx].name = _nameCtrl.text.trim();
          _owners[idx].mobile = _mobileCtrl.text.trim();
          _owners[idx].address = _addressCtrl.text.trim();
          _owners[idx].machineType = _selectedMachineType ?? '';
          _owners[idx].machineNumber = _machineNumberCtrl.text.trim();
        });
        await _saveData();
        _clearForm();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Machine owner updated')),
        );
      }
    } else {
      // Create new owner
      final MachineOwner owner = MachineOwner(
        id: UniqueKey().toString(),
        name: _nameCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        machineType: _selectedMachineType ?? '',
        machineNumber: _machineNumberCtrl.text.trim(),
      );

      setState(() {
        _owners.insert(0, owner);
        _clearForm();
      });
      await _saveData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Machine owner saved')),
      );
    }
  }

  void _clearForm() {
    _nameCtrl.clear();
    _mobileCtrl.clear();
    _addressCtrl.clear();
    _machineNumberCtrl.clear();
    setState(() {
      _selectedMachineType = null;
      _editingId = null;
    });
  }

  void _populateFormForEdit(MachineOwner owner) {
    _nameCtrl.text = owner.name;
    _mobileCtrl.text = owner.mobile;
    _addressCtrl.text = owner.address;
    _machineNumberCtrl.text = owner.machineNumber;
    setState(() {
      _selectedMachineType = owner.machineType.isEmpty ? null : owner.machineType;
      _editingId = owner.id;
    });
  }

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  Future<void> _deleteOwner(String id) async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Machine Owner'),
        content: const Text('Are you sure you want to delete this machine owner?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _owners.removeWhere((e) => e.id == id));
      await _ownersBox.delete(id);
      await _saveData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Machine owner deleted')),
      );
    }
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Machine Owners', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Owner Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _mobileCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Mobile',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedMachineType,
                              decoration: const InputDecoration(
                                labelText: 'Machine Type *',
                                border: OutlineInputBorder(),
                              ),
                              items: _machineTypes.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(_capitalizeFirst(type)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedMachineType = value);
                              },
                              validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _machineNumberCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Machine Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: Icon(_editingId != null ? Icons.update : Icons.save_outlined),
                        label: Text(_editingId != null ? 'Update' : 'Save'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                      if (_editingId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: OutlinedButton.icon(
                            onPressed: _clearForm,
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Cancel'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _owners.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_outline, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No machine owners yet', style: TextStyle(color: Colors.grey[600])),
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
                          children: _owners.asMap().entries.map((entry) {
                            final int index = entry.key;
                            final MachineOwner owner = entry.value;
                            final int serialNumber = index + 1;

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
                                  onTap: () => _populateFormForEdit(owner),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: Colors.indigo[600],
                                                shape: BoxShape.circle,
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                '$serialNumber',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _capitalizeFirst(owner.name),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 20),
                                              onPressed: () => _deleteOwner(owner.id),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          _buildInfoChip('Mobile', owner.mobile),
                                          _buildInfoChip('Type', _capitalizeFirst(owner.machineType)),
                                          if (owner.machineNumber.isNotEmpty)
                                            _buildInfoChip('Number', owner.machineNumber),
                                          if (owner.address.isNotEmpty)
                                            _buildInfoChip('Address', owner.address),
                                        ],
                                      ),
                                    ],
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


