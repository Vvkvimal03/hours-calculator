import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _mobileCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _machineNumberCtrl = TextEditingController();

  String? _selectedMachineType; // Selected machine type from dropdown
  static const List<String> _machineTypes = ['kartar', 'class', 'gam', 'tyre'];

  List<MachineOwner> _owners = <MachineOwner>[];

  @override
  void initState() {
    super.initState();
    _loadData();
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
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> rawOwners = prefs.getStringList(_prefsKey) ?? <String>[];
    setState(() {
      _owners = rawOwners
          .map((e) => MachineOwner.fromMap(json.decode(e) as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> _saveData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _owners.map((e) => json.encode(e.toMap())).toList(growable: false),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

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

  void _clearForm() {
    _nameCtrl.clear();
    _mobileCtrl.clear();
    _addressCtrl.clear();
    _machineNumberCtrl.clear();
    setState(() {
      _selectedMachineType = null;
    });
  }

  Future<void> _deleteOwner(String id) async {
    setState(() => _owners.removeWhere((e) => e.id == id));
    await _saveData();
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
                                  child: Text(type),
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
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
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
                : ListView.builder(
                    itemCount: _owners.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemBuilder: (context, index) {
                      final MachineOwner owner = _owners[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: ListTile(
                          title: Text(owner.name),
                          subtitle: Text(
                            'Mobile: ${owner.mobile}\nType: ${owner.machineType}\nNumber: ${owner.machineNumber}\nAddress: ${owner.address}',
                          ),
                          isThreeLine: false,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteOwner(owner.id),
                          ),
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


