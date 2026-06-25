import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../services/language_service.dart';
import '../services/parking_service.dart';
import '../models/parking_space.dart';
import '../widgets/parking_card.dart';
import 'public_profile_screen.dart';
import 'parking_details_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Creăm o listă de target-uri validă
    List<String> targets = ['all'];
    if (user?.uid != null) {
      targets.add(user!.uid);
    }

    return ListenableBuilder(
      listenable: LanguageService(),
      builder: (context, child) {
        final lang = LanguageService();
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: AppBar(
            title: Text(lang.translate('messages_title'),
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                onPressed: () => _confirmDeleteAll(context, user?.uid, lang),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.grey),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lang.translate('messages_updated')),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              )
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('target', whereIn: targets)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                // Dacă eroarea e de index, va apărea link-ul aici
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Eroare Firebase: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mail_outline_rounded,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(lang.translate('no_messages'),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                );
              }

              // Filtrare pentru notificările ascunse, cele viitoare și mesaje de chat (pentru a evita duplicarea listei de chat)
              final now = DateTime.now();
              final allDocs = snapshot.data!.docs;
              final displayDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                
                // 1. Nu afișăm chat-urile aici (au tab separat)
                if (data['type'] == 'chat') return false;

                // 2. Nu afișăm dacă a fost ascunsă manual de acest user
                final List hiddenBy = data['hiddenBy'] ?? [];
                if (hiddenBy.contains(user?.uid)) return false;
                
                // 3. Nu afișăm notificările care au un timestamp în viitor (programate)
                final Timestamp? createdAt = data['createdAt'] as Timestamp?;
                if (createdAt != null && createdAt.toDate().isAfter(now)) {
                  return false;
                }
                
                return true;
              }).toList();

              if (displayDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mail_outline_rounded,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(lang.translate('no_messages'),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await Future.delayed(const Duration(seconds: 1));
                },
                color: const Color(0xFF2563EB),
                child: ListView.builder(
                  padding: const EdgeInsets.all(15),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: displayDocs.length,
                  itemBuilder: (context, index) {
                    final doc = displayDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final Timestamp? createdAt = data['createdAt'] as Timestamp?;
                    final DateTime date = createdAt?.toDate() ?? DateTime.now();
                    final bool isRead = data['isRead'] ?? false;
                    final String type = data['type'] ?? 'system';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isRead ? Colors.white : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isRead
                                ? Colors.grey.shade100
                                : const Color(0xFFBFDBFE)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(15),
                        leading: CircleAvatar(
                          backgroundColor:
                              _getIconColor(type).withValues(alpha: 0.1),
                          child: Icon(_getIcon(type),
                              color: _getIconColor(type), size: 20),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(_getLocalizedTitle(data, lang),
                                  style: TextStyle(
                                      fontWeight: isRead
                                          ? FontWeight.w600
                                          : FontWeight.w900)),
                            ),
                            Text(DateFormat('HH:mm').format(date),
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_getLocalizedMessage(data, lang),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.grey.shade700, fontSize: 13)),
                        ),
                        onTap: () async {
                          await FirebaseFirestore.instance
                              .collection('notifications')
                              .doc(doc.id)
                              .update({'isRead': true});
                          if (context.mounted) {
                            _showNotificationDetails(context, data, lang);
                          }
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _getLocalizedTitle(Map<String, dynamic> data, LanguageService lang) {
    final String title = data['title'] ?? '';
    if (title.contains('Rezervare Confirmată')) return lang.translate('notif_res_confirmed_title');
    if (title.contains('Rezervare Anulată')) return lang.translate('notif_res_cancelled_title');
    if (title.contains('Refund Realizat')) return lang.translate('notif_refund_processed_title');
    if (title.contains('Bani primiți')) return lang.translate('notif_money_received_title');
    if (title.contains('Loc închiriat')) return lang.translate('notif_spot_rented_title');
    if (title.contains('Expiră parcarea')) return lang.translate('notif_expiry_warning');
    if (title.contains('Raport Trimis') || title.contains('Report Submitted')) return lang.translate('notif_report_received_title');
    if (title.contains('Decizie Suport') || title.contains('Support Decision')) return lang.translate('notif_report_decision_title');
    return title;
  }

  String _getLocalizedMessage(Map<String, dynamic> data, LanguageService lang) {
    final String msg = data['message'] ?? '';
    final String type = data['type'] ?? '';
    
    // 1. Rezervare Confirmată (Buyer)
    if (msg.contains('Ai rezervat locul') || msg.contains('Ai rezervat un loc')) {
      // Exemplu: "Ai rezervat locul 23 la Parcare Centrală."
      if (msg.contains(' la ')) {
         final parts = msg.split(' la ');
         final spotPart = parts[0].replaceAll('Ai rezervat', '').trim();
         final parkingPart = parts[1].replaceAll('.', '').trim();
         return "${lang.translate('notif_res_confirmed_msg')} $spotPart la $parkingPart.";
      }
      return lang.translate('notif_res_confirmed_msg');
    }
    
    // 2. Rezervare Anulată
    if (msg.contains('anulată cu succes')) {
      return lang.translate('notif_res_cancelled_msg');
    }
    
    // 3. Refund Realizat
    if (msg.contains('returnată în portofelul tău')) {
      return lang.translate('notif_refund_processed_msg');
    }

    // 4. Bani primiți (Owner)
    if (msg.contains('Bani primiți') || msg.contains('închirierea locului tău')) {
       // Exemplu: "Ai primit 10.0 RON pentru închirierea locului tău 12."
       final RegExp reg = RegExp(r'Ai primit (.*?) RON');
       final match = reg.firstMatch(msg);
       if (match != null) {
         final amount = match.group(1);
         return lang.currentLocale.languageCode == 'ro'
          ? "Ai primit $amount RON pentru închiriere."
          : "You received $amount RON for renting.";
       }
       return lang.translate('notif_money_received_msg');
    }

    // 4. Loc închiriat (Owner - Detalii)
    if (msg.contains('a închiriat locul tău')) {
       // Exemplu: "Utilizatorul Andrei a închiriat locul tău (Parcare) cu mașina BV01AAA."
       final RegExp reg = RegExp(r'Utilizatorul (.*?) a închiriat locul tău \((.*?)\) cu mașina (.*?)\.');
       final match = reg.firstMatch(msg);
       if (match != null) {
         final user = match.group(1);
         final parking = match.group(2);
         final car = match.group(3);
         return lang.currentLocale.languageCode == 'ro'
          ? "Utilizatorul $user a închiriat locul tău ($parking) cu mașina $car."
          : "User $user rented your spot ($parking) with car $car.";
       }
    }
    
    if (msg.contains('Am primit raportul tău') || msg.contains('received your report')) {
      return lang.translate('notif_report_received_msg');
    }
    if (msg.contains('Raport aprobat') || msg.contains('Report approved')) {
      return lang.translate('notif_report_decision_refund');
    }
    if (msg.contains('Raport respins') || msg.contains('Report rejected')) {
      return lang.translate('notif_report_decision_rejected');
    }
    
    return msg;
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'admin_announcement':
        return Icons.campaign_rounded;
      case 'reservation':
        return Icons.local_parking_rounded;
      case 'payment':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'admin_announcement':
        return Colors.purple;
      case 'reservation':
        return Colors.green;
      case 'payment':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  void _confirmDeleteAll(BuildContext context, String? userId, LanguageService lang) {
    if (userId == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(lang.translate('delete_all_notif_title')),
        content: Text(lang.translate('delete_all_notif_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text(lang.translate('cancel'))
          ),
          TextButton(
            onPressed: () async {
              final batch = FirebaseFirestore.instance.batch();
              final snapshots = await FirebaseFirestore.instance
                  .collection('notifications')
                  .where('target', whereIn: [userId, 'all'])
                  .get();
              
              for (var doc in snapshots.docs) {
                final data = doc.data();
                if (data['target'] == userId) {
                  // Notificare personală -> Ștergere definitivă
                  batch.delete(doc.reference);
                } else {
                  // Notificare globală -> Doar o ascundem pentru acest user
                  batch.update(doc.reference, {
                    'hiddenBy': FieldValue.arrayUnion([userId])
                  });
                }
              }
              await batch.commit();
              if (context.mounted) Navigator.pop(context);
            }, 
            child: Text(lang.translate('delete'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _showNotificationDetails(
      BuildContext context, Map<String, dynamic> data, LanguageService lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        final bool isOwnerNotif = data['title']?.toString().contains('Loc închiriat') ?? false;
        final bool isBuyerNotif = data['title']?.toString().contains('Rezervare Confirmată') ?? false;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            padding: const EdgeInsets.all(25),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['title'] ?? '',
                      style:
                          const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Text(data['message'] ?? '',
                      style: const TextStyle(
                          fontSize: 15, color: Color(0xFF334155), height: 1.5)),

                  // Card Loc Parcare (Dacă avem spotId)
                  if (data['spotId'] != null) ...[
                    const SizedBox(height: 20),
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('parking_spaces')
                          .doc(data['spotId'])
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final space = ParkingSpace.fromFirestore(snapshot.data!);

                          return FutureBuilder<Position?>(
                            future: Geolocator.getLastKnownPosition(),
                            builder: (context, posSnapshot) {
                              return ParkingCard(
                                space: space,
                                userPosition: posSnapshot.data,
                              );
                            },
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],

                  // Detalii suplimentare pentru rezervări (Proprietar)
                  if (data['type'] == 'reservation' && isOwnerNotif) ...[
                    const Divider(height: 40),
                    Text(lang.translate('tenant_details').toUpperCase(),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                    const SizedBox(height: 16),
                    
                    // Tenant Profile Card (Clickable)
                    GestureDetector(
                      onTap: () {
                        final buyerId = data['buyerId'];
                        if (buyerId != null && buyerId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PublicProfileScreen(userId: buyerId),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: const Color(0xFF2563EB),
                              backgroundImage: (data['buyerPhotoURL'] != null && data['buyerPhotoURL'].toString().isNotEmpty)
                                  ? NetworkImage(data['buyerPhotoURL'])
                                  : null,
                              child: (data['buyerPhotoURL'] == null || data['buyerPhotoURL'].toString().isEmpty)
                                  ? Text(
                                      (data['buyerName']?.toString().isNotEmpty == true) 
                                          ? data['buyerName'].toString()[0].toUpperCase() 
                                          : 'U',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['buyerName'] ?? 'N/A',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text(data['buyerEmail'] ?? 'N/A',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    _buildDetailRow(lang.translate('car_label'), data['carPlate'] ?? 'N/A'),
                    _buildDetailRow(lang.translate('interval_label'),
                        data['startTime'] != null && data['endTime'] != null 
                          ? "${DateFormat('HH:mm').format((data['startTime'] as Timestamp).toDate())} - ${DateFormat('HH:mm').format((data['endTime'] as Timestamp).toDate())}"
                          : 'N/A'),
                  ],

                  // Detalii suplimentare pentru rezervări (Chiriaș/Buyer)
                  if (data['type'] == 'reservation' && isBuyerNotif) ...[
                    const Divider(height: 40),
                    Text(lang.translate('location_info').toUpperCase(),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                    const SizedBox(height: 16),
                    _buildDetailRow(lang.translate('car_label'), data['carPlate'] ?? 'N/A'),
                    _buildDetailRow(lang.translate('interval_label'),
                        data['startTime'] != null && data['endTime'] != null 
                          ? "${DateFormat('HH:mm').format((data['startTime'] as Timestamp).toDate())} - ${DateFormat('HH:mm').format((data['endTime'] as Timestamp).toDate())}"
                          : 'N/A'),
                  ],

                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(lang.translate('close').toUpperCase(),
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
