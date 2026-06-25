import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/parking_space.dart';
import '../utils/navigation_utils.dart';
import '../services/language_service.dart';
import '../services/invoice_pdf_service.dart';
import '../services/parking_service.dart';

class ReservationDetailsScreen extends StatefulWidget {
  final String reservationId;
  final Map<String, dynamic> reservationData;

  const ReservationDetailsScreen({
    super.key,
    required this.reservationId,
    required this.reservationData,
  });

  @override
  State<ReservationDetailsScreen> createState() => _ReservationDetailsScreenState();
}

class _ReservationDetailsScreenState extends State<ReservationDetailsScreen> {
  final ParkingService _parkingService = ParkingService();
  bool _isLoading = false;
  double _userRating = 0;
  final TextEditingController _reviewController = TextEditingController();

  Future<void> _handleReport() async {
    final lang = LanguageService();
    
    setState(() => _isLoading = true);
    try {
      final Position userPos = await Geolocator.getCurrentPosition();
      final double distance = Geolocator.distanceBetween(
        userPos.latitude, userPos.longitude, 
        widget.reservationData['latitude'] ?? 0.0, 
        widget.reservationData['longitude'] ?? 0.0
      );
      
      if (distance > 200) {
        throw Exception(lang.currentLocale.languageCode == 'ro' 
          ? "Ești prea departe de parcare (${distance.toInt()}m). Trebuie să fii la fața locului!" 
          : "You are too far from the parking (${distance.toInt()}m). You must be at the location!");
      }

      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);

      if (photo == null) {
        setState(() => _isLoading = false);
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(lang.translate('cancel_report_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lang.translate('cancel_report_warning')),
              const SizedBox(height: 8),
              Text(lang.translate('cancel_report_refund_info'), style: const TextStyle(fontSize: 12)),
              Text(lang.translate('cancel_report_guarantee_info'), style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 15),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(photo.path), height: 150, width: double.infinity, fit: BoxFit.cover),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(lang.translate('no'))),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(lang.translate('confirm_btn'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _parkingService.cancelReservation(widget.reservationId);
        final storageRef = FirebaseStorage.instance.ref()
            .child('evidence/${widget.reservationId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(File(photo.path));
        final evidenceUrl = await storageRef.getDownloadURL();
        await _parkingService.reportOccupied(widget.reservationId, evidenceUrl);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.translate('report_sent_success'))));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleExtend() async {
    final lang = LanguageService();
    int? extraHours = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(lang.translate('extend_reservation'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [1, 2, 3].map((h) => ElevatedButton(
                onPressed: () => Navigator.pop(context, h),
                child: Text("+ $h h"),
              )).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );

    if (extraHours != null) {
      setState(() => _isLoading = true);
      try {
        await _parkingService.extendReservation(widget.reservationId, extraHours);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.translate('extend_success'))));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();
    final String spotId = widget.reservationData['spotId'] ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('reservations').doc(widget.reservationId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final resData = snapshot.data!.data() as Map<String, dynamic>;
        final String status = resData['status'] ?? 'activ';
        final DateTime start = (resData['startTime'] as Timestamp).toDate();
        final DateTime end = (resData['endTime'] as Timestamp).toDate();

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: AppBar(
            title: Text(lang.translate('res_details_title'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(status, end, lang),
                    const SizedBox(height: 20),
                    if (status == 'activ' && end.isAfter(DateTime.now())) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _handleExtend,
                              icon: const Icon(Icons.more_time_rounded, size: 18),
                              label: Text(lang.translate('extend_reservation')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _handleReport,
                              icon: const Icon(Icons.report_problem_outlined, size: 18),
                              label: Text(lang.translate('cancel_report_btn'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (status == 'completat' || (status == 'activ' && end.isBefore(DateTime.now()))) ...[
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('reviews').doc("${spotId}_${FirebaseAuth.instance.currentUser?.uid}").snapshots(),
                        builder: (context, revSnap) {
                          if (revSnap.hasData && revSnap.data!.exists) return const SizedBox.shrink();
                          return _buildReviewCard(lang);
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('parking_spaces').doc(spotId).get(),
                      builder: (context, spotSnapshot) {
                        final parking = (spotSnapshot.hasData && spotSnapshot.data!.exists) ? ParkingSpace.fromFirestore(spotSnapshot.data!) : null;
                        return Column(
                          children: [
                            if (parking != null)
                              Container(
                                height: 200,
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Stack(
                                    children: [
                                      PageView.builder(
                                        itemCount: parking.getAllDisplayImages().length,
                                        itemBuilder: (context, index) => Image.network(parking.getAllDisplayImages()[index], fit: BoxFit.cover, errorBuilder: (context, e, s) => const Center(child: Icon(Icons.image_not_supported))),
                                      ),
                                      Positioned(bottom: 10, right: 10, child: Container(padding: const EdgeInsets.all(5), color: Colors.black45, child: Text(lang.translate('swipe_for_photo'), style: const TextStyle(color: Colors.white, fontSize: 10)))),
                                    ],
                                  ),
                                ),
                              ),
                            _buildInfoCard(
                              title: lang.translate('location_info'),
                              icon: Icons.location_on,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(resData['parkingName'] ?? 'Parcare', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  const SizedBox(height: 8),
                                  Text(parking?.address ?? 'Adresă indisponibilă', style: TextStyle(color: Colors.grey.shade600)),
                                  const SizedBox(height: 15),
                                  if (parking != null)
                                    ElevatedButton.icon(
                                      onPressed: () => NavigationUtils.showNavigationDialog(context, parking.latitude, parking.longitude, resData['parkingName'] ?? 'Parcare'),
                                      icon: const Icon(Icons.navigation, size: 18, color: Colors.white),
                                      label: Text(lang.translate('navigate'), style: const TextStyle(color: Colors.white)),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildInfoCard(
                      title: lang.translate('time_interval'),
                      icon: Icons.access_time,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildTimeColumn(lang.translate('from'), start, lang),
                          const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
                          _buildTimeColumn(lang.translate('until'), end, lang),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildPaymentCard(resData, lang),
                    const SizedBox(height: 30),
                    Center(child: Text('${lang.translate('res_id_label')}: ${widget.reservationId}', style: TextStyle(color: Colors.grey.shade400, fontSize: 10))),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              if (_isLoading) Container(color: Colors.black.withValues(alpha: 0.3), child: const Center(child: CircularProgressIndicator())),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> resData, LanguageService lang) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('invoices').where('reservationId', isEqualTo: widget.reservationId).limit(1).get(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final invoice = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          return _buildInfoCard(
            title: lang.translate('invoice_details'),
            icon: Icons.receipt_long,
            child: Column(
              children: [
                _buildDetailRow(lang.translate('invoice_number'), invoice['invoiceNumber'] ?? 'N/A'),
                _buildDetailRow(lang.translate('issue_date'), DateFormat('dd.MM.yyyy HH:mm', lang.currentLocale.languageCode).format((invoice['issuedAt'] as Timestamp).toDate())),
                const Divider(height: 30),
                _buildDetailRow(lang.translate('gross_price'), '${invoice['totals']?['totalGross']} RON'),
                _buildDetailRow(lang.translate('vat_label'), '${invoice['totals']?['totalVat']} RON'),
                _buildDetailRow(lang.translate('net_price'), '${invoice['totals']?['totalNet']} RON', isLast: true),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => InvoicePdfService.generateAndDownload(invoice), icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.white), label: Text(lang.translate('download_invoice_pdf'), style: const TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
              ],
            ),
          );
        }
        return _buildInfoCard(title: lang.translate('payment_details'), icon: Icons.payment, child: _buildDetailRow(lang.translate('total_paid'), '${resData['totalPrice']} RON', isLast: true));
      },
    );
  }

  Widget _buildReviewCard(LanguageService lang) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFBFDBFE))),
      child: Column(
        children: [
          Text(lang.translate('rate_experience'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (index) => IconButton(onPressed: () => setState(() => _userRating = index + 1), icon: Icon(_userRating > index ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 32)))),
          if (_userRating > 0) ...[
            const SizedBox(height: 10),
            TextField(controller: _reviewController, maxLines: 2, decoration: InputDecoration(hintText: lang.translate('add_comment_optional'), fillColor: Colors.white, filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async { setState(() => _isLoading = true); await _parkingService.submitReview(widget.reservationId, _userRating, _reviewController.text); if (mounted) { setState(() { _isLoading = false; _userRating = 0; }); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.translate('rating_success')))); } }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(lang.translate('submit_rating'), style: const TextStyle(color: Colors.white)))),
          ]
        ],
      ),
    );
  }

  Widget _buildStatusCard(String status, DateTime end, LanguageService lang) {
    bool isExpired = end.isBefore(DateTime.now());
    bool isActive = status == 'activ' && !isExpired;
    bool isCancelled = status == 'anulat' ||
        status == 'reported_occupied' ||
        status == 'reported_occupied_resolved' ||
        status == 'reported_occupied_rejected';

    String statusText = lang.translate('res_completed');
    if (isActive) {
      statusText = lang.translate('res_active');
    } else if (isExpired && status == 'activ') {
      statusText = lang.currentLocale.languageCode == 'ro' ? 'Expirată' : 'Expired';
    } else if (status == 'anulat') {
      statusText = lang.translate('res_cancelled_voided');
    } else if (status == 'reported_occupied') {
      statusText = lang.translate('spot_occupied_pending');
    } else if (status == 'reported_occupied_resolved') {
      statusText = lang.translate('report_accepted_refunded');
    } else if (status == 'reported_occupied_rejected') {
      statusText = lang.translate('report_refused');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFDCFCE7)
              : (isCancelled
                  ? (status == 'reported_occupied_resolved'
                      ? Colors.green.withValues(alpha: 0.1)
                      : const Color(0xFFFEE2E2))
                  : (isExpired && status == 'activ' ? Colors.orange.withValues(alpha: 0.1) : Colors.grey.shade200)),
          borderRadius: BorderRadius.circular(15)),
      child: Row(children: [
        Icon(
            isActive
                ? Icons.check_circle
                : (isCancelled
                    ? (status == 'reported_occupied_resolved'
                        ? Icons.verified_rounded
                        : Icons.cancel_outlined)
                    : (isExpired && status == 'activ' ? Icons.timer_off_outlined : Icons.history)),
            color: isActive
                ? const Color(0xFF166534)
                : (isCancelled
                    ? (status == 'reported_occupied_resolved'
                        ? Colors.green
                        : Colors.red.shade700)
                    : (isExpired && status == 'activ' ? Colors.orange.shade900 : Colors.grey.shade700))),
        const SizedBox(width: 15),
        Expanded(
            child: Text(statusText,
                style: TextStyle(
                    color: isActive
                        ? const Color(0xFF166534)
                        : (isCancelled
                            ? (status == 'reported_occupied_resolved'
                                ? Colors.green.shade900
                                : Colors.red.shade700)
                            : (isExpired && status == 'activ' ? Colors.orange.shade900 : Colors.grey.shade700)),
                    fontWeight: FontWeight.bold,
                    fontSize: 16)))
      ]),
    );
  }

  Widget _buildInfoCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, size: 20, color: const Color(0xFF2563EB)), const SizedBox(width: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey))]), const SizedBox(height: 20), child]),
    );
  }

  Widget _buildTimeColumn(String label, DateTime date, LanguageService lang) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)), const SizedBox(height: 4), Text(DateFormat('HH:mm').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)), Text(DateFormat('dd MMM', lang.currentLocale.languageCode).format(date), style: const TextStyle(color: Colors.black54, fontSize: 14))]);
  }

  Widget _buildDetailRow(String label, String value, {bool isLast = false}) {
    return Padding(padding: EdgeInsets.only(bottom: isLast ? 0 : 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)), Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))]));
  }
}
