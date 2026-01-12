import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'screens/bill_book_screen.dart';

void main() {
  runApp(const TimeCalculatorApp());
}

class TimeCalculatorApp extends StatelessWidget {
  const TimeCalculatorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Time Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        textTheme: ThemeData.light().textTheme.apply(
              displayColor: Colors.black87,
              bodyColor: Colors.black87,
            ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          centerTitle: false,
        ),
      ),
      home: const TimeCalculatorScreen(),
    );
  }
}

class TimeCalculatorScreen extends StatefulWidget {
  const TimeCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<TimeCalculatorScreen> createState() => _TimeCalculatorScreenState();
}

class _TimeCalculatorScreenState extends State<TimeCalculatorScreen> {
  String expression = '';
  String result = '0h 0m';
  List<Map<String, String>> history = [];
  bool showHistory = false;
  Timer? _autoSaveTimer;
  static const String _expressionKey = 'saved_expression';
  static const String _resultKey = 'saved_result';
  final TextEditingController _expressionController = TextEditingController();
  final FocusNode _expressionFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadSavedState();
    _startAutoSave();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _expressionController.dispose();
    _expressionFocusNode.dispose();
    super.dispose();
  }

  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _saveCurrentState();
    });
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedExpression = prefs.getString(_expressionKey) ?? '';
    final savedResult = prefs.getString(_resultKey) ?? '0h 0m';
    setState(() {
      expression = savedExpression;
      result = savedResult.isEmpty ? '0h 0m' : savedResult;
    });
    // If we have an expression, recalculate to ensure result is correct
    if (expression.isNotEmpty && mounted) {
      _calculateResult();
    }
    _expressionController.text = expression;
  }

  Future<void> _saveCurrentState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_expressionKey, expression);
    await prefs.setString(_resultKey, result);
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('time_calculator_history') ?? [];
      setState(() {
        history = historyJson
            .map((item) {
              final Map<String, dynamic> raw = json.decode(item);
              // Backward compatible mapping with optional name
              return <String, String>{
                'expression': (raw['expression'] ?? '').toString(),
                'result': (raw['result'] ?? '').toString(),
                'timestamp': (raw['timestamp'] ?? '').toString(),
                'name': (raw['name'] ?? '').toString(),
              };
            })
            .toList();
      });
    } catch (e) {
      // Handle corrupted data
      setState(() {
        history = [];
      });
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = history.map((item) => json.encode(item)).toList();
      await prefs.setStringList('time_calculator_history', historyJson);
    } catch (e) {
      // Handle save error
      debugPrint('Error saving history: $e');
    }
  }

  void _onButtonPressed(String value) {
    setState(() {
      if (value == 'C') {
        expression = '';
        result = '0h 0m';
        _expressionController.text = '';
      } else if (value == '⌫') {
        if (expression.isNotEmpty) {
          expression = expression.substring(0, expression.length - 1);
          _expressionController.text = expression;
          _expressionController.selection = TextSelection.fromPosition(
            TextPosition(offset: _expressionController.text.length),
          );
          // Recalculate result if expression changed
          if (expression.isNotEmpty) {
            _calculateResult();
          } else {
            result = '0h 0m';
          }
        } else {
          result = '0h 0m';
        }
      } else if (value == '=') {
        _calculateResult();
        // Add to history when equals is pressed
        if (expression.isNotEmpty) {
          _addToHistory();
        }
      } else if (value == 'h' || value == 'm') {
        // Only add unit if we have a number before it
        if (expression.isNotEmpty && RegExp(r'[0-9]$').hasMatch(expression)) {
          expression += value;
          _expressionController.text = expression;
          _expressionController.selection = TextSelection.fromPosition(
            TextPosition(offset: _expressionController.text.length),
          );
          // Only calculate after unit is added if expression has complete terms
          _calculateResult();
        }
      } else if (value == '+' || value == '-') {
        if (expression.isNotEmpty && !expression.endsWith('+') && !expression.endsWith('-')) {
          // Ensure previous term has a unit
          if (expression.endsWith('h') || expression.endsWith('m')) {
            expression += value;
            _expressionController.text = expression;
            _expressionController.selection = TextSelection.fromPosition(
              TextPosition(offset: _expressionController.text.length),
            );
          }
        } else if (expression.isEmpty) {
          // Allow negative numbers at start
          if (value == '-') {
            expression += value;
            _expressionController.text = expression;
            _expressionController.selection = TextSelection.fromPosition(
              TextPosition(offset: _expressionController.text.length),
            );
          }
        }
      } else if (RegExp(r'[0-9]').hasMatch(value)) {
        expression += value;
        _expressionController.text = expression;
        _expressionController.selection = TextSelection.fromPosition(
          TextPosition(offset: _expressionController.text.length),
        );
        // Don't auto-calculate when typing numbers - wait for unit or operator
      }
    });
  }

  void _calculateResult() {
    try {
      if (expression.trim().isEmpty) {
        setState(() {
          result = '0h 0m';
        });
        return;
      }

      // Check if expression has at least one complete term (number + unit)
      bool hasCompleteTerm = RegExp(r'\d+(h|m)').hasMatch(expression);
      if (!hasCompleteTerm) {
        // Show placeholder or partial result
        setState(() {
          result = '0h 0m';
        });
        return;
      }

      int totalMinutes = 0;
      String currentNumber = '';
      String currentUnit = '';
      String operation = '+';
      int i = 0;

      // Handle negative at start
      if (expression.isNotEmpty && expression[0] == '-') {
        operation = '-';
        i = 1;
      }

      while (i < expression.length) {
        String char = expression[i];

        if (RegExp(r'[0-9]').hasMatch(char)) {
          currentNumber += char;
          i++;
        } else if (expression[i] == 'h') {
          currentUnit = 'h';
          i += 1;
          
          // Process this term
          int value = int.tryParse(currentNumber.isNotEmpty ? currentNumber : '0') ?? 0;
          int minutes = value * 60;

          if (operation == '+') {
            totalMinutes += minutes;
          } else if (operation == '-') {
            totalMinutes -= minutes;
          }

          currentNumber = '';
          currentUnit = '';
        } else if (expression[i] == 'm') {
          currentUnit = 'm';
          i += 1;
          
          // Process this term
          int value = int.tryParse(currentNumber.isNotEmpty ? currentNumber : '0') ?? 0;
          int minutes = value;

          if (operation == '+') {
            totalMinutes += minutes;
          } else if (operation == '-') {
            totalMinutes -= minutes;
          }

          currentNumber = '';
          currentUnit = '';
        } else if (char == '+' || char == '-') {
          // If we have a number but no unit yet, skip processing
          if (currentNumber.isNotEmpty && currentUnit.isEmpty) {
            i++;
            continue;
          }
          
          operation = char;
          i++;
        } else {
          i++;
        }
      }

      // Handle remaining number without unit (treat as minutes)
      if (currentNumber.isNotEmpty) {
        int value = int.tryParse(currentNumber) ?? 0;
        if (operation == '+') {
          totalMinutes += value;
        } else if (operation == '-') {
          totalMinutes -= value;
        }
      }

      // Ensure non-negative result
      if (totalMinutes < 0) {
        totalMinutes = 0;
      }

      int hours = totalMinutes ~/ 60;
      int minutes = totalMinutes % 60;

      setState(() {
        result = '${hours}h ${minutes}m';
      });
    } catch (e) {
      setState(() {
        result = 'Error';
      });
      debugPrint('Calculation error: $e');
    }
  }

  void _addToHistory() {
    if (expression.isNotEmpty && result.isNotEmpty && result != 'Error') {
      setState(() {
        history.insert(0, {
          'expression': expression,
          'result': result,
          'timestamp': DateTime.now().toIso8601String(),
          'name': '',
        });
        
        // Keep only last 50 entries
        if (history.length > 50) {
          history = history.sublist(0, 50);
        }
      });
      _saveHistory();
    }
  }

  Future<void> _editHistoryName(int index) async {
    if (index < 0 || index >= history.length) return;
    final Map<String, String> item = history[index];
    final TextEditingController controller = TextEditingController(text: item['name'] ?? '');
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter a name (optional)',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName == null) return;
    setState(() {
      history[index] = {
        ...item,
        'name': newName,
      };
    });
    await _saveHistory();
  }

  Future<void> _copyHistory(int index, String mode) async {
    if (index < 0 || index >= history.length) return;
    final Map<String, String> item = history[index];
    final String expr = item['expression'] ?? '';
    final String res = item['result'] ?? '';
    String textToCopy;
    if (mode == 'expr') {
      textToCopy = expr;
    } else if (mode == 'result') {
      textToCopy = res;
    } else {
      textToCopy = '$expr = $res';
    }
    await Clipboard.setData(ClipboardData(text: textToCopy));
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: ${mode == 'expr' ? 'expression' : mode == 'result' ? 'result' : 'expression = result'}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _clearHistory() async {
    setState(() {
      history.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('time_calculator_history');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Calculator', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Bill Book',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BillBookScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(showHistory ? Icons.calculate : Icons.history),
            onPressed: () {
              setState(() {
                showHistory = !showHistory;
              });
            },
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.02, 0.02), end: Offset.zero).animate(anim),
              child: child,
            ),
          );
        },
        child: showHistory ? _buildHistoryView() : _buildCalculatorView(),
      ),
    );
  }

  Widget _buildHistoryView() {
    return Column(
      children: [
        if (history.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearHistory,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No history yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: history.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((item['name'] ?? '').isNotEmpty)
                              Text(
                                item['name']!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            Text(
                              item['expression']!,
                              style: TextStyle(
                                fontSize: (item['name'] ?? '').isNotEmpty ? 13 : 16,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '= ${item['result']}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              tooltip: 'Copy',
                              icon: const Icon(Icons.copy_all_outlined),
                              onSelected: (value) => _copyHistory(index, value),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'expr',
                                  child: Text('Copy expression'),
                                ),
                                const PopupMenuItem(
                                  value: 'result',
                                  child: Text('Copy result'),
                                ),
                                const PopupMenuItem(
                                  value: 'both',
                                  child: Text('Copy expression = result'),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit name',
                              onPressed: () => _editHistoryName(index),
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            expression = item['expression']!;
                            result = item['result']!;
                            showHistory = false;
                            _expressionController.text = expression;
                            _expressionController.selection = TextSelection.fromPosition(
                              TextPosition(offset: _expressionController.text.length),
                            );
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCalculatorView() {
    return Column(
      children: [
        // Display area
        Expanded(
          flex: 2,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.indigo.withOpacity(0.02),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _expressionController,
                  focusNode: _expressionFocusNode,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 32,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: '0',
                  ),
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9hHmM+\- ]')),
                  ],
                  onChanged: (value) {
                    final String normalized = value
                        .toLowerCase()
                        .replaceAll('hour', 'h')
                        .replaceAll('min', 'm');
                    if (normalized != value) {
                      final int baseOffset = _expressionController.selection.baseOffset;
                      final int extentOffset = _expressionController.selection.extentOffset;
                      _expressionController.value = TextEditingValue(
                        text: normalized,
                        selection: TextSelection(baseOffset: baseOffset, extentOffset: extentOffset),
                      );
                    }
                    setState(() {
                      expression = _expressionController.text.replaceAll(' ', '');
                    });
                    _calculateResult();
                  },
                  onSubmitted: (_) => _calculateResult(),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.decelerate,
                  switchOutCurve: Curves.easeIn,
                  child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                    child: Text(
                      result.isEmpty ? '0h 0m' : result,
                      key: ValueKey<String>(result),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: result == 'Error' ? Colors.red[700] : Colors.indigo[700],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Buttons
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Time unit buttons
                Row(
                  children: [
                    _buildUnitButton('h'),
                    const SizedBox(width: 12),
                    _buildUnitButton('m'),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Calculator buttons
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _buildButton('C', color: Colors.red[400]),
                            _buildButton('⌫', color: Colors.orange[400]),
                            _buildButton('(', color: Colors.grey[400]),
                            _buildButton(')', color: Colors.grey[400]),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildButton('7'),
                            _buildButton('8'),
                            _buildButton('9'),
                            _buildButton('+', color: Colors.blue[400]),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildButton('4'),
                            _buildButton('5'),
                            _buildButton('6'),
                            _buildButton('-', color: Colors.blue[400]),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildButton('1'),
                            _buildButton('2'),
                            _buildButton('3'),
                            _buildButton('=', color: Colors.green[500]),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: Container()),
                            _buildButton('0'),
                            Expanded(child: Container()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(String text, {Color? color}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          onPressed: () => _onButtonPressed(text),
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? Colors.white,
            foregroundColor: color != null ? Colors.white : Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: AnimatedScale(
            scale: 1.0,
            duration: const Duration(milliseconds: 120),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnitButton(String text) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: ElevatedButton(
          onPressed: () => _onButtonPressed(text),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo[50],
            foregroundColor: Colors.indigo[700],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
