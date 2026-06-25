import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AvailabilityMonitorScreen extends StatefulWidget {
  const AvailabilityMonitorScreen({super.key});

  @override
  State<AvailabilityMonitorScreen> createState() => _AvailabilityMonitorScreenState();
}

class _AvailabilityMonitorScreenState extends State<AvailabilityMonitorScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Conflict & Overlap Monitor', 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          _buildGlobalSummary(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('parking_spaces').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final spots = snapshot.data!.docs;
                
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: spots.length,
                  itemBuilder: (context, index) {
                    final spot = spots[index];
                    final spotData = spot.data() as Map<String, dynamic>;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.local_parking, color: Color(0xFF2563EB), size: 20),
                            ),
                            title: Text(spotData['name'] ?? 'Unnamed Spot', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Text(spotData['address'] ?? '', style: const TextStyle(fontSize: 12)),
                            trailing: _buildSpotDailyStats(spot.id),
                          ),
                          const Divider(height: 1),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Text("TIMELINE (REZERVĂRI ZILNICE)", 
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
                          ),
                          _buildReservationTimeline(spot.id),
                          const SizedBox(height: 12),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      height: 100,
      decoration: const BoxDecoration(color: Colors.white),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        // Arătăm 7 zile în trecut și 7 în viitor
        itemCount: 15, 
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          // Calculăm data pornind de la acum 7 zile
          final date = DateTime.now().subtract(const Duration(days: 7)).add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          final isToday = DateUtils.isSameDay(date, DateTime.now());
          
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 70,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2563EB) : (isToday ? Colors.blue.shade50 : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? const Color(0xFF2563EB) : (isToday ? Colors.blue.shade200 : Colors.grey.shade200)),
                boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('EEE').format(date).toUpperCase(), 
                    style: TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(DateFormat('dd').format(date), 
                    style: TextStyle(fontSize: 18, color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                  Text(DateFormat('MMM').format(date), 
                    style: TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : Colors.grey)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlobalSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reservations').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final start = (data['startTime'] as Timestamp?)?.toDate();
          return start != null && DateUtils.isSameDay(start, _selectedDate) && data['status'] != 'anulat';
        }).toList();

        int totalReservations = docs.length;
        double totalHours = 0;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final start = (data['startTime'] as Timestamp?)?.toDate();
          final end = (data['endTime'] as Timestamp?)?.toDate();
          if (start != null && end != null) {
            totalHours += end.difference(start).inMinutes / 60.0;
          }
        }

        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(Icons.event_available, "Total Rezervări", totalReservations.toString()),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildSummaryItem(Icons.access_time_filled, "Total Ore", "${totalHours.toStringAsFixed(1)} h"),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildSummaryItem(Icons.local_parking, "Locuri Utilizate", docs.map((e) => (e.data() as Map)['spotId']).toSet().length.toString()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.blueAccent, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSpotDailyStats(String spotId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .where('spotId', isEqualTo: spotId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final start = (data['startTime'] as Timestamp?)?.toDate();
          return start != null && DateUtils.isSameDay(start, _selectedDate) && data['status'] != 'anulat';
        }).toList();

        int count = docs.length;
        double totalHours = 0;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final start = (data['startTime'] as Timestamp?)?.toDate();
          final end = (data['endTime'] as Timestamp?)?.toDate();
          if (start != null && end != null) {
            totalHours += end.difference(start).inMinutes / 60.0;
          }
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("$count Rezervări", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
            Text("${totalHours.toStringAsFixed(1)} ore total", style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.w600)),
          ],
        );
      },
    );
  }

  Widget _buildReservationTimeline(String spotId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .where('spotId', isEqualTo: spotId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();
        if (!snapshot.hasData) return const SizedBox(height: 50, child: Center(child: LinearProgressIndicator()));
        
        final allDocs = snapshot.data!.docs;
        
        final resDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['status'] == 'anulat') return false;
          final start = (data['startTime'] as Timestamp?)?.toDate();
          return start != null && DateUtils.isSameDay(start, _selectedDate);
        }).toList();

        resDocs.sort((a, b) {
          final startA = (a.data() as Map)['startTime'] as Timestamp;
          final startB = (b.data() as Map)['startTime'] as Timestamp;
          return startA.compareTo(startB);
        });

        if (resDocs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text("Fără activitate în această zi", style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey)),
          );
        }

        return Container(
          height: 90,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: resDocs.length,
            itemBuilder: (context, index) {
              final data = resDocs[index].data() as Map<String, dynamic>;
              final start = (data['startTime'] as Timestamp?)?.toDate();
              final end = (data['endTime'] as Timestamp?)?.toDate();
              
              bool isConflict = data['hasConflict'] == true;

              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                color: isConflict ? Colors.red.shade50 : const Color(0xFFF8FAFC),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time, size: 12, color: Colors.blueAccent),
                        const SizedBox(width: 4),
                        Text(start != null ? DateFormat('HH:mm').format(start) : '?', 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const Icon(Icons.arrow_downward, size: 10, color: Colors.grey),
                    Text(end != null ? DateFormat('HH:mm').format(end) : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if (isConflict) 
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text("CONFLICT DETECTAT",
                          style: TextStyle(color: Colors.red.shade700, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
