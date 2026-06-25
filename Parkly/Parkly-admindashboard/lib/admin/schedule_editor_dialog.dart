import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleEditorDialog extends StatefulWidget {
  final String spotId;
  final Map<String, dynamic>? initialSchedule;

  const ScheduleEditorDialog({super.key, required this.spotId, this.initialSchedule});

  @override
  State<ScheduleEditorDialog> createState() => _ScheduleEditorDialogState();
}

class _ScheduleEditorDialogState extends State<ScheduleEditorDialog> {
  late Map<String, dynamic> _schedule;
  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _initializeSchedule();
  }

  void _initializeSchedule() {
    // Schema standard cerută de Mobile: { Monday: { active: bool, start: "HH:mm", end: "HH:mm" } }
    final defaultSchedule = {
      for (var day in _days) 
        day: {'active': true, 'start': '09:00', 'end': '17:00'}
    };

    if (widget.initialSchedule != null && widget.initialSchedule!.isNotEmpty) {
      _schedule = {};
      // Încercăm să mapăm datele primite pe structura engleză
      for (var day in _days) {
        if (widget.initialSchedule!.containsKey(day)) {
          _schedule[day] = Map<String, dynamic>.from(widget.initialSchedule![day]);
        } else {
          // Dacă lipsește o zi (ex: era în română sau format vechi), punem default închis
          _schedule[day] = {'active': false, 'start': '09:00', 'end': '17:00'};
        }
      }
    } else {
      _schedule = defaultSchedule;
    }
  }

  Future<void> _selectTime(String day, bool isStart) async {
    final String currentStr = _schedule[day][isStart ? 'start' : 'end'] ?? (isStart ? '09:00' : '17:00');
    final TimeOfDay current = TimeOfDay(
      hour: int.parse(currentStr.split(':')[0]),
      minute: int.parse(currentStr.split(':')[1]),
    );

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: current,
    );

    if (picked != null) {
      setState(() {
        final String formatted = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
        _schedule[day][isStart ? 'start' : 'end'] = formatted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Parking Schedule Editor", style: TextStyle(fontWeight: FontWeight.bold)),
          Text("Aliniat cu formatul aplicației mobile (weeklySchedule)", 
               style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.normal)),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _days.map((day) {
              final dayData = _schedule[day] as Map<String, dynamic>;
              bool active = dayData['active'] ?? false;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    SizedBox(width: 100, child: Text(day, style: const TextStyle(fontWeight: FontWeight.w500))),
                    Checkbox(
                      value: active,
                      onChanged: (val) => setState(() => _schedule[day]['active'] = val),
                    ),
                    const Spacer(),
                    if (active) ...[
                      TextButton(
                        onPressed: () => _selectTime(day, true),
                        child: Text(dayData['start'] ?? '09:00'),
                      ),
                      const Text("-"),
                      TextButton(
                        onPressed: () => _selectTime(day, false),
                        child: Text(dayData['end'] ?? '17:00'),
                      ),
                    ] else
                      const Text("Inchis (Offline)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Anulează")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
          onPressed: () async {
            // Salvăm EXCLUSIV în weeklySchedule pentru sincronizare mobil
            await FirebaseFirestore.instance.collection('parking_spaces').doc(widget.spotId).update({
              'weeklySchedule': _schedule,
              'hasCustomSchedule': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Program sincronizat cu succes!")),
              );
              Navigator.pop(context);
            }
          },
          child: const Text("Salvează Programul", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
