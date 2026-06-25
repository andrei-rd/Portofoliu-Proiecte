import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:provider/provider.dart';
import 'admin_service.dart';

import 'package:parkly/admin/users_wallet_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final adminService = Provider.of<AdminService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parkly Admin - Gestiune Parcări', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[800],
        elevation: 4,
        actions: [
          StreamBuilder<Map<String, double>>(
            stream: adminService.detailedProfitStream,
            builder: (context, snapshot) {
              final data = snapshot.data ?? {'serviceFees': 0.0, 'surgeEarnings': 0.0, 'total': 0.0};
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Center(
                  child: Text(
                    "Profit: ${data['total']?.toStringAsFixed(2)} RON",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                  ),
                ),
              );
            }
          ),
          TextButton.icon(
            icon: const Icon(Icons.sync, color: Colors.white, size: 20),
            label: const Text("Sincronizare Facturi & Profit", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );
              
              final int synced = await adminService.syncMissingInvoices();
              
              if (context.mounted) {
                Navigator.pop(context); // Închide loader-ul
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(synced > 0 
                      ? 'Audit finalizat: $synced facturi generate (TVA 20%).' 
                      : 'Toate datele sunt deja sincronizate.'),
                    backgroundColor: synced > 0 ? Colors.green : Colors.blue,
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Status Sistem (Live Data)", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // 1. VIZUALIZAREA METRICILOR (Conectat la Firestore)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('parkings').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text("Eroare la încărcarea datelor");
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }

                // Calculăm datele din documentele primite
                final docs = snapshot.data?.docs ?? [];
                int totalLocuri = docs.length;
                int ocupate = docs.where((doc) {
                  // Verificăm dacă există câmpul 'status' și dacă este 'occupied'
                  try { return doc['status'] == 'occupied'; }
                  catch (e) { return false; }
                }).length;
                int libere = totalLocuri - ocupate;

                // Dacă baza de date e goală, afișăm valori de test pentru prezentare
                String totalDisplay = totalLocuri > 0 ? totalLocuri.toString() : "150";
                String ocupateDisplay = totalLocuri > 0 ? ocupate.toString() : "92";
                String libereDisplay = totalLocuri > 0 ? libere.toString() : "58";

                return Row(
                  children: [
                    _buildStatCard("Total Locuri", totalDisplay, Icons.apps, Colors.indigo),
                    _buildStatCard("Locuri Ocupate", ocupateDisplay, Icons.directions_car, Colors.red),
                    _buildProfitStatCard(adminService),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),

            // 2. MONITORIZAREA ZONELOR AGLOMERATE
            const Text("Zone cu Grad Ridicat de Ocupare", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Card(
              color: Color(0xFFFFF3E0),
              child: ListTile(
                leading: Icon(Icons.warning_amber_rounded, color: Colors.orange),
                title: Text("Sector A - Str. Principală"),
                subtitle: Text("Grad de ocupare: 98% (Atenție: Aproape plin)"),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
              ),
            ),
            const SizedBox(height: 30),

            // 3. REZOLVAREA DISPUTELOR
            const Text("Dispute în Așteptare", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.report_problem, color: Colors.redAccent),
                title: const Text("Eroare Raportare Loc #204"),
                subtitle: const Text("Senzorul indică 'Ocupat', Utilizatorul raportează 'Liber'."),
                trailing: ElevatedButton(
                  onPressed: () async {
                    // Analytics: Înregistrăm că admin-ul a început verificarea
                    await FirebaseAnalytics.instance.logEvent(name: 'dispute_check_started');

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Se trimite agent de verificare (Sincronizat Firebase)")),
                    );
                  },
                  child: const Text("Verifică"),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 4. GESTIONAREA UTILIZATORILOR (DATE REALE)
            const Text("Utilizatori Raportați", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            _buildRealUserTable(context),
            const SizedBox(height: 30),

            // 5. GESTIONARE PORTOFEL VIRTUAL
            const Text("Finanțe & Portofel Virtual", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.account_balance_wallet),
                label: const Text("Gestionează Portofele Utilizatori"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UsersWalletScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildRealUserTable(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('reports', isGreaterThan: 0).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text("Nu există utilizatori raportați în acest moment.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          );
        }

        return Table(
          border: TableBorder.all(color: Colors.grey[300]!),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1.5),
          },
          children: [
            const TableRow(
              decoration: BoxDecoration(color: Color(0xFFF5F5F5)),
              children: [
                Padding(padding: EdgeInsets.all(10), child: Text("Nume/Email", style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(padding: EdgeInsets.all(10), child: Text("Rapoarte", style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(padding: EdgeInsets.all(10), child: Text("Acțiune", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return TableRow(children: [
                Padding(padding: const EdgeInsets.all(10), child: Text(data['displayName'] ?? data['email'] ?? doc.id)),
                Padding(padding: const EdgeInsets.all(10), child: Text("${data['reports'] ?? 0}")),
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => _arataDialogConfirmare(context, doc.id, data['displayName'] ?? 'Utilizator'),
                    child: const Text("Suspendă", style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ]);
            }),
          ],
        );
      },
    );
  }

  void _arataDialogConfirmare(BuildContext context, String uid, String name) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmare Suspendare"),
          content: Text("Doriți să suspendați contul lui $name?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Anulează")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance.collection('users').doc(uid).update({
                    'isBanned': true,
                    'bannedAt': Timestamp.now(),
                  });
                } catch (e) {
                  debugPrint("Eroare Firestore: $e");
                }

                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Utilizatorul $name a fost suspendat!")),
                );
              },
              child: const Text("Confirmă", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfitStatCard(AdminService service) {
    return StreamBuilder<double>(
      stream: service.totalPlatformProfitStream,
      builder: (context, snapshot) {
        final profit = snapshot.data ?? 0.0;
        return _buildStatCard("Profit Platformă", "${profit.toStringAsFixed(2)} RON", Icons.account_balance_wallet, Colors.green);
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}