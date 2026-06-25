import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/language_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final dbService = DatabaseService();
    final lang = LanguageService();

    return ListenableBuilder(
        listenable: lang,
        builder: (context, child) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FB),
            appBar: AppBar(
              title: Text(lang.translate('wallet_title'),
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: StreamBuilder<DocumentSnapshot>(
              stream: dbService.getUserData(user?.uid ?? ''),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final double balance =
                    (data['walletBalance'] ?? 0.0).toDouble();

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                    await Future.delayed(const Duration(seconds: 1));
                  },
                  color: const Color(0xFF2563EB),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Sold
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                lang.translate('available_balance'),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 16),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${balance.toStringAsFixed(2)} RON',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        Text(
                          lang.translate('actions'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            _buildActionButton(
                              context,
                              lang.translate('top_up'),
                              Icons.add_card,
                              Colors.green,
                              () => _showTopUpDialog(
                                  context, dbService, user?.uid ?? '', lang),
                            ),
                            const SizedBox(width: 15),
                            _buildActionButton(
                              context,
                              lang.translate('transfer'),
                              Icons.send,
                              Colors.orange,
                              () =>
                                  _showTransferDialog(context, dbService, lang),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        Text(
                          lang.translate('transaction_history'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 15),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user?.uid)
                              .collection('transactions')
                              .orderBy('timestamp', descending: true)
                              .limit(20)
                              .snapshots(),
                          builder: (context, transSnapshot) {
                            if (transSnapshot.hasError) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: Text(
                                    'Eroare la încărcarea tranzacțiilor.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.red, fontSize: 12),
                                  ),
                                ),
                              );
                            }

                            if (!transSnapshot.hasData ||
                                transSnapshot.data!.docs.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child:
                                      Text(lang.translate('no_transactions')),
                                ),
                              );
                            }

                            return Column(
                              children: transSnapshot.data!.docs.map((doc) {
                                final trans =
                                    doc.data() as Map<String, dynamic>;
                                return _buildTransactionItem(
                                  trans['title'] ?? trans['details'] ?? 'Transaction',
                                  (trans['timestamp'] ?? trans['createdAt']) as Timestamp?,
                                  (trans['amount'] ?? 0.0).toDouble(),
                                  trans['type'] ?? 'other',
                                  lang,
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        });
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon,
      Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
      String title, Timestamp? date, double amount, String type, LanguageService lang) {
    final bool isNegative = amount < 0;
    // Refund și Credit sunt mereu verzi în UI conform cerințelor
    final bool isPositiveType = type == 'refund' || type == 'credit' || type == 'top_up' || type == 'initial_credit' || type == 'transfer_in' || type == 'rental_income';
    final Color color = (isPositiveType || !isNegative) ? Colors.green : Colors.red;
    IconData icon;

    // Folosim titlul primit direct, deoarece acesta este deja tradus în ParkingService
    // sau setat de Admin. Folosim traducerea doar ca fallback.
    String localizedTitle = title;
    
    // Tratăm cazurile speciale unde vrem să combinăm traducerea tipului cu detalii din titlu
    if (type.contains('transfer') && title.contains('@')) {
      final parts = title.split(' ');
      localizedTitle = "${lang.translate('trans_$type')} ${parts.last}";
    } else if (type == 'payment' && title.contains(':') && !title.startsWith(lang.translate('trans_payment'))) {
       final parts = title.split(':');
       localizedTitle = "${lang.translate('trans_payment')}: ${parts.last}";
    } else if (type == 'refund' && title.contains(':') && !title.startsWith(lang.translate('trans_refund'))) {
       final parts = title.split(':');
       localizedTitle = "${lang.translate('trans_refund')}: ${parts.last}";
    }

    switch (type) {
      case 'top_up':
      case 'initial_credit':
      case 'credit':
        icon = Icons.add_circle_outline_rounded;
        break;
      case 'transfer_in':
      case 'rental_income':
        icon = Icons.call_received;
        break;
      case 'transfer_out':
        icon = Icons.call_made;
        break;
      case 'payment':
        icon = Icons.car_rental;
        break;
      case 'refund':
        icon = Icons.history_rounded;
        break;
      default:
        icon = Icons.payment;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(localizedTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  date != null
                      ? '${date.toDate().day}/${date.toDate().month}/${date.toDate().year} ${date.toDate().hour}:${date.toDate().minute.toString().padLeft(2, '0')}'
                      : '-',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${isNegative ? "" : "+"}${amount.toStringAsFixed(2)} RON',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showTopUpDialog(BuildContext context, DatabaseService db, String uid,
      LanguageService lang) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.translate('top_up')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: lang.translate('amount_ron'),
            suffixText: 'RON',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang.translate('cancel'))),
          ElevatedButton(
            onPressed: () async {
              final double? amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                await db.addWalletCredits(uid, amount);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Text(lang.translate('confirm_payment')),
          ),
        ],
      ),
    );
  }

  void _showTransferDialog(
      BuildContext context, DatabaseService db, LanguageService lang) {
    final user = FirebaseAuth.instance.currentUser;
    final emailController = TextEditingController();
    final amountController = TextEditingController();
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.translate('transfer')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: lang.translate('recipient_email'),
                ),
              ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: lang.translate('amount_ron'),
                  suffixText: 'RON',
                ),
              ),
              TextField(
                controller: detailsController,
                decoration: InputDecoration(
                  labelText: lang.translate('transfer_details'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang.translate('cancel'))),
          ElevatedButton(
            onPressed: () async {
              final String email = emailController.text.trim();
              final double? amount = double.tryParse(amountController.text);

              if (email.isNotEmpty && amount != null && amount > 0) {
                try {
                  await db.transferMoneyByEmail(
                    senderUid: user?.uid ?? '',
                    recipientEmail: email,
                    amount: amount,
                    details: detailsController.text,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(lang.translate('transfer_success'))),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    String errorMsg = lang.translate('error');
                    if (e.toString().contains('User not found')) {
                      errorMsg = lang.translate('user_not_found');
                    } else if (e.toString().contains('Insufficient funds')) {
                      errorMsg = lang.translate('insufficient_funds');
                    } else if (e
                        .toString()
                        .contains('Cannot transfer to yourself')) {
                      errorMsg = lang.translate('cannot_transfer_self');
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(errorMsg)),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(lang.translate('invalid_amount'))),
                );
              }
            },
            child: Text(lang.translate('send')),
          ),
        ],
      ),
    );
  }
}
