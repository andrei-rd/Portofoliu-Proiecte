import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/parking_service.dart';
import '../services/language_service.dart';
import '../models/parking_space.dart';
import 'reservation_details_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final ParkingService parkingService = ParkingService();
    final lang = LanguageService();

    return ListenableBuilder(
      listenable: lang,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: AppBar(
            title: Text(lang.translate('history_title'),
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 3,
              tabs: [
                Tab(text: lang.translate('active')),
                Tab(text: lang.translate('past')),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildReservationList(user, parkingService, lang, isActive: true),
              _buildReservationList(user, parkingService, lang,
                  isActive: false),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReservationList(
      User? user, ParkingService parkingService, LanguageService lang,
      {required bool isActive}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .where('userId', isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Eroare: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final String status = data['status'] ?? 'activ';
          final DateTime? endTime = data['endTime'] != null
              ? (data['endTime'] as Timestamp).toDate()
              : null;

          bool isExpired = endTime != null && endTime.isBefore(DateTime.now());

          if (isActive) {
            return status == 'activ' && !isExpired;
          } else {
            return status != 'activ' || isExpired;
          }
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  isActive
                      ? lang.translate('no_active_res')
                      : lang.translate('no_past_res'),
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        // Sort by creation time
        docs.sort((a, b) {
          final aTime =
              (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final bTime =
              (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(seconds: 1));
          },
          color: const Color(0xFF2563EB),
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final res = doc.data() as Map<String, dynamic>;
              final DateTime start = res['startTime'] != null
                  ? (res['startTime'] as Timestamp).toDate()
                  : DateTime.now();
              final DateTime? end = res['endTime'] != null
                  ? (res['endTime'] as Timestamp).toDate()
                  : null;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('parking_spaces')
                              .doc(res['spotId'] ?? res['parkingId'])
                              .get(),
                          builder: (context, spotSnap) {
                            String? imgUrl;
                            if (spotSnap.hasData && spotSnap.data!.exists) {
                              final parking = ParkingSpace.fromFirestore(spotSnap.data!);
                              imgUrl = parking.getAllDisplayImages().first;
                            }

                            return Container(
                              width: 55,
                              height: 55,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F7FF),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: (imgUrl != null && imgUrl.isNotEmpty)
                                    ? Image.network(
                                        imgUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.local_parking_rounded,
                                                color: Color(0xFF2563EB)),
                                      )
                                    : const Icon(Icons.local_parking_rounded,
                                        color: Color(0xFF2563EB)),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(res['parkingName'] ?? 'Parcare',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              if (isActive && end != null)
                                CountdownTimer(endTime: end, start: start)
                              else
                                Text(
                                  DateFormat('dd MMM yyyy, HH:mm').format(start),
                                  style: TextStyle(
                                      color: Colors.grey.shade500, fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFFDCFCE7)
                                : (res['status'] == 'anulat'
                                    ? Colors.red.withValues(alpha: 0.1)
                                    : (res['status'] == 'reported_occupied' || res['status'] == 'reported_occupied_resolved' || res['status'] == 'reported_occupied_rejected'
                                        ? Colors.orange.withValues(alpha: 0.1)
                                        : Colors.grey.shade100)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isActive
                                ? lang.translate('active')
                                : (res['status'] == 'anulat'
                                    ? lang.translate('status_cancelled')
                                    : (res['status'] == 'reported_occupied'
                                        ? lang.translate('status_reported')
                                        : (res['status'] == 'reported_occupied_resolved'
                                            ? (lang.currentLocale.languageCode == 'ro' ? 'RAPORT ACCEPTAT' : 'REPORT ACCEPTED')
                                            : (res['status'] == 'reported_occupied_rejected'
                                                ? (lang.currentLocale.languageCode == 'ro' ? 'RAPORT REFUZAT' : 'REPORT REFUSED')
                                                : lang.translate('past'))))),
                            style: TextStyle(
                              color: isActive
                                  ? const Color(0xFF166534)
                                  : (res['status'] == 'anulat'
                                      ? Colors.red
                                      : (res['status'] == 'reported_occupied' || res['status'] == 'reported_occupied_resolved' || res['status'] == 'reported_occupied_rejected'
                                          ? Colors.orange.shade900
                                          : Colors.grey.shade600)),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ReservationDetailsScreen(
                                      reservationId: doc.id,
                                      reservationData: res,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              child: Text(lang.translate('details'),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ),
                          ],
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

  Future<bool?> _showCancelDialog(BuildContext context, LanguageService lang) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(lang.translate('cancel')),
        content: Text(lang.translate('cancel_confirmation')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(lang.translate('no'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(lang.translate('yes_cancel'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class CountdownTimer extends StatefulWidget {
  final DateTime endTime;
  final DateTime start;

  const CountdownTimer({super.key, required this.endTime, required this.start});

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calculateRemaining();
        });
      }
    });
  }

  void _calculateRemaining() {
    _remaining = widget.endTime.difference(DateTime.now());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();
    if (_remaining.isNegative) {
      return Text(
        lang.translate('expired'),
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      );
    }

    final h = _remaining.inHours;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;
    final timeStr =
        "${h > 0 ? '$h:' : ''}${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";

    return Text(
      "${lang.translate('expires_in')}: $timeStr",
      style: const TextStyle(
        color: Color(0xFF2563EB),
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
