import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/parking_service.dart';
import '../models/parking_space.dart';
import '../services/language_service.dart';
import '../utils/app_exception.dart';
import 'add_parking_screen.dart';
import 'admin_pricing_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final ParkingService _parkingService = ParkingService();
  final lang = LanguageService();
  Position? _userPosition;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) setState(() => _userRole = doc.data()?['role']);
    }
  }

  Future<void> _getUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _userPosition = position);
    } catch (e) {
      debugPrint("Error location admin: $e");
    }
  }

  String _getDistance(ParkingSpace space) {
    if (_userPosition == null) return "--- m";
    double dist = Geolocator.distanceBetween(_userPosition!.latitude,
        _userPosition!.longitude, space.latitude, space.longitude);
    return dist < 1000
        ? "${dist.toInt()}m"
        : "${(dist / 1000).toStringAsFixed(1)}km";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ListenableBuilder(
      listenable: lang,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: AppBar(
            title: Text(lang.translate('admin_panel'),
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            actions: [
              if (_userRole == 'admin')
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reservations')
                      .where('status', isEqualTo: 'reported_occupied')
                      .where('refundStatus', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snapshot) {
                    int reportCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.report_problem, color: Colors.redAccent),
                          tooltip: 'Rapoarte Incidente',
                          onPressed: () => _showReportsDialog(),
                        ),
                        if (reportCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '$reportCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              if (_userRole == 'admin')
                IconButton(
                  icon: const Icon(Icons.settings_input_component, color: Color(0xFF2563EB)),
                  tooltip: 'Configurație Prețuri Dinamice',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminPricingScreen()),
                  ),
                ),
              if (_userRole == 'admin')
                IconButton(
                  icon: const Icon(Icons.campaign, color: Color(0xFF2563EB)),
                  tooltip: 'Trimite Anunț Global',
                  onPressed: () => _showBroadcastDialog(),
                ),
              IconButton(
                icon: const Icon(Icons.receipt_long, color: Color(0xFF2563EB)),
                tooltip: 'Sincronizare Facturi',
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );
                  
                  try {
                    final reservations = await FirebaseFirestore.instance
                        .collection('reservations')
                        .where('invoiceGenerated', isEqualTo: false)
                        .get();
                    
                    int count = 0;
                    for (var doc in reservations.docs) {
                      await _parkingService.generateInvoice(doc.id);
                      count++;
                    }
                    
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sincronizare completă: $count facturi generate.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Eroare sincronizare: $e')),
                      );
                    }
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.sync, color: Color(0xFF2563EB)),
                onPressed: () {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(lang.currentLocale.languageCode == 'ro' ? 'Date sincronizate cu succes!' : 'Data synced successfully!'), duration: const Duration(seconds: 1)),
                  );
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              await Future.delayed(const Duration(seconds: 1));
            },
            color: const Color(0xFF2563EB),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(lang.translate('parking_spots'),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        StreamBuilder<List<ParkingSpace>>(
                          stream: _parkingService.getParkingSpaces(),
                          builder: (context, snapshot) {
                            final allSpaces = snapshot.data ?? [];
                            final mySpacesCount = _userRole == 'admin' 
                                ? allSpaces.length 
                                : allSpaces.where((s) => s.ownerId == user?.uid).length;
                                
                            return Text('$mySpacesCount ${lang.translate('total')}',
                                style: TextStyle(color: Colors.grey.shade600));
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                StreamBuilder<List<ParkingSpace>>(
                  stream: _parkingService.getParkingSpaces(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                    }

                    final allSpaces = snapshot.data ?? [];
                    final displaySpaces = _userRole == 'admin' 
                        ? allSpaces 
                        : allSpaces.where((s) => s.ownerId == user?.uid).toList();

                    if (displaySpaces.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map_outlined,
                                  size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(lang.translate('no_spots_added'),
                                  style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final space = displaySpaces[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade100),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4))
                                ],
                              ),
                              child: Row(
                                children: [
                                  // LEADING IMAGE
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.grey.shade100,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        space.getAllDisplayImages().first,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey);
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // CENTER CONTENT (NAME, ADDRESS, PRICE)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(space.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on,
                                                size: 10, color: Color(0xFF2563EB)),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(space.address,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey.shade600)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: space.isClosed
                                                ? Colors.red.withValues(alpha: 0.1)
                                                : (space.availableSpots > 0
                                                    ? Colors.green.withValues(alpha: 0.1)
                                                    : Colors.orange.withValues(alpha: 0.1)),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            space.isClosed 
                                                ? (space.weeklySchedule['isManuallyDisabled'] == true ? lang.translate('status_deactivated') : lang.translate('status_closed_schedule'))
                                                : (space.weeklySchedule['isAlwaysAvailable'] == true 
                                                    ? '24/7 - ${space.availableSpots}/${space.totalSpots} ${lang.currentLocale.languageCode == 'ro' ? 'LIBERE' : 'FREE'}'
                                                    : '${space.availableSpots}/${space.totalSpots} ${lang.currentLocale.languageCode == 'ro' ? 'LIBERE' : 'FREE'}'),
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: space.isClosed 
                                                  ? Colors.red 
                                                  : (space.availableSpots > 0 ? Colors.green : Colors.orange),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                            '${space.pricePerHour.toInt()} RON/h',
                                            style: const TextStyle(
                                                color: Color(0xFF2563EB),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 4),

                                  // TRAILING ACTIONS
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (space.ownerId == user?.uid || _userRole == 'admin')
                                            _buildActionButton(Icons.edit_outlined,
                                                Colors.blueGrey, () {
                                              Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          AddParkingScreen(
                                                              parkingSpace:
                                                                  space)));
                                            }, size: 18),
                                          const SizedBox(width: 6),
                                          if (space.ownerId == user?.uid || _userRole == 'admin')
                                            _buildActionButton(
                                                Icons.delete_outline,
                                                Colors.redAccent,
                                                () => _showDeleteDialog(space), size: 18),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildStatusButton(
                                              Icons.nightlight_round,
                                              space.weeklySchedule['isManuallyDisabled'] == true
                                                  ? Colors.orange
                                                  : Colors.grey.shade300,
                                              () => _parkingService.setParkingState(space.docIds, 'deactivated'),
                                              size: 16),
                                          _buildStatusButton(
                                              Icons.wb_sunny_rounded,
                                              (space.weeklySchedule['isManuallyDisabled'] != true && 
                                               space.weeklySchedule['isAlwaysAvailable'] != true)
                                                  ? Colors.yellow.shade700
                                                  : Colors.grey.shade300,
                                              () => _parkingService.setParkingState(space.docIds, 'schedule'),
                                              size: 16),
                                          _buildStatusButton(
                                              Icons.all_inclusive,
                                              space.weeklySchedule['isAlwaysAvailable'] == true
                                                  ? const Color(0xFF2563EB)
                                                  : Colors.grey.shade300,
                                              () => _parkingService.setParkingState(space.docIds, '24/7'),
                                              size: 16),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                          childCount: displaySpaces.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AddParkingScreen()),
              );
            },
            backgroundColor: const Color(0xFF2563EB),
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(lang.translate('add_spot'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  Widget _buildStatusButton(IconData icon, Color color, VoidCallback onTap, {double size = 18}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap, {double size = 18}) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: size, color: color),
      onPressed: onTap,
    );
  }

  void _showDeleteDialog(ParkingSpace space) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(lang.translate('delete_spot')),
        content: Text(lang.currentLocale.languageCode == 'ro'
            ? 'Ești sigur că vrei să ștergi "${space.name}"? Această acțiune este permanentă.'
            : 'Are you sure you want to delete "${space.name}"? This action is permanent.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang.currentLocale.languageCode == 'ro'
                  ? 'Anulează'
                  : 'Cancel')),
          TextButton(
            onPressed: () async {
              await _parkingService.deleteSpot(space.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(lang.translate('delete'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBroadcastDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Trimite Anunț Global'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Titlu (ex: Mentenanță)')),
            const SizedBox(height: 10),
            TextField(controller: bodyController, decoration: const InputDecoration(labelText: 'Mesaj'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANULEAZĂ')),
          ElevatedButton(
            onPressed: () async {
              try {
                // Salvăm în Firestore cu flag de pop-up
                await FirebaseFirestore.instance.collection('notifications').add({
                  'target': 'all', // Vizat către toți
                  'title': '📢 ' + titleController.text,
                  'message': bodyController.text,
                  'type': 'admin_announcement', // Schimbat din 'system' pentru a avea iconița corectă
                  'isRead': false,
                  'showPopup': true,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anunț trimis ca Pop-up tuturor utilizatorilor!')));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Eroare: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('TRIMITE ACUM', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReportsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rapoarte Ocupare Abuzivă',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reservations')
                      .where('status', isEqualTo: 'reported_occupied')
                      .where('refundStatus', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('Niciun raport în așteptare.'));
                    }

                    final reports = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: reports.length + 1, // +1 for guide card
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildProtocolGuide();

                        final doc = reports[index - 1];
                        final data = doc.data() as Map<String, dynamic>;
                        final resId = doc.id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(data['parkingName'] ?? 'Parcare Necunoscută',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                    child: const Text('REPORTED', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Chiriaș: ${data['userId']?.toString().substring(0, 8) ?? 'N/A'} • Mașină: ${data['carPlate'] ?? 'N/A'}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              
                              if (data['evidenceUrl'] != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      data['evidenceUrl'],
                                      height: 120,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${data['totalPrice']} RON', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                  ElevatedButton(
                                    onPressed: () => _showDecisionDialog(resId, data),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 20)),
                                    child: const Text('Rezolvă', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
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
        ),
      ),
    );
  }

  Widget _buildProtocolGuide() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gavel_rounded, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Text('Protocol Decizie Raportare Loc Ocupat', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
            ],
          ),
          const SizedBox(height: 12),
          _guideItem('1. Verificarea Dovezilor:', 'Analizează imaginea (evidenceUrl). Verifică plăcuța mașinii.'),
          _guideItem('2. Luarea Deciziei:', 'APROBĂ dacă dovada e clară (refund instant utilizator). RESPINGE dacă e neclară.'),
          _guideItem('3. Notă Internă:', 'Orice decizie este finală și marcată în istoricul tranzacțiilor.'),
        ],
      ),
    );
  }

  Widget _guideItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
          Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF))),
        ],
      ),
    );
  }

  void _showDecisionDialog(String resId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Decizie Raportare Loc Ocupat', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🛡️ PROTOCOL DECIZIE (Incident Management)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 8),
            const Text('1. Verificarea Dovezilor\nAnalizează imaginea. Verifică dacă locul este vizibil ocupat abuziv.', style: TextStyle(fontSize: 11)),
            const Text('\n2. GPS & Timp\nVerifică dacă utilizatorul a raportat în primele 30 min și era la locație.', style: TextStyle(fontSize: 11)),
            const Text('\n3. Garanția de 2 RON\nDecide dacă returnezi Garanția de Sistem (2 RON). Clientul a primit deja restul sumei.', style: TextStyle(fontSize: 11)),
            const Divider(height: 32),
            const Text('DETALII INCIDENT:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text('• Chiriaș: ${data['userId']?.toString().substring(0, 8) ?? 'ID Necunoscut'}', style: const TextStyle(fontSize: 12)),
            Text('• Garanție de returnat: ${data['serviceFee'] ?? 2.0} RON', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
              child: const Text(
                'NOTĂ: Dacă aprobi, chiriașul primește Garanția de 2 RON înapoi în portofel. Dacă respingi, taxa rămâne la platformă.',
                style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ÎNCHIDE')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _parkingService.resolveReport(resId, false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Raport respins. Garanție reținută.')));
              }
            },
            child: const Text('RESPINGE RAPORT', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _parkingService.resolveReport(resId, true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Garanție returnată chiriașului.')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('APROBĂ REFUND GARANȚIE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
