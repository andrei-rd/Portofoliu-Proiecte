import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'admin_service.dart';
import 'user_profile_screen.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showEditUserDialog(String userId, Map<String, dynamic> data) {
    final TextEditingController balanceController = TextEditingController(text: (data['walletBalance'] ?? 0.0).toString());
    String selectedRole = data['role'] ?? 'user';
    final adminService = Provider.of<AdminService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit User: ${data['displayName'] ?? 'User'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Sold Portofel (RON)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Rol Utilizator',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('User')),
                  DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedRole = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newBalance = double.tryParse(balanceController.text);
                if (newBalance == null) return;

                try {
                  // Update balance if changed
                  if (newBalance != (data['walletBalance'] ?? 0.0)) {
                    await adminService.updateUserWalletBalance(userId, newBalance);
                  }
                  
                  // Update role if changed
                  if (selectedRole != (data['role'] ?? 'user')) {
                    await adminService.updateUserRole(userId, selectedRole);
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Date actualizate cu succes!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Salvează'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users & Wallets')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final users = snapshot.data?.docs ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: SizedBox(
                width: double.infinity,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Display Name')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Balance')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: users.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final balance = (data['walletBalance'] ?? 0.0).toDouble();
                    final role = data['role'] ?? 'user';
                    
                    return DataRow(cells: [
                      DataCell(Text(data['displayName'] ?? 'No Name')),
                      DataCell(Text(data['email'] ?? 'No Email')),
                      DataCell(
                        Chip(
                          label: Text(role.toString().toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white)),
                          backgroundColor: role == 'admin' ? Colors.purple : Colors.grey,
                        ),
                      ),
                      DataCell(Text('${balance.toStringAsFixed(2)} RON',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                      DataCell(
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _showEditUserDialog(doc.id, data),
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Editează'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserProfileScreen(userId: doc.id, userData: data),
                                  ),
                                );
                              },
                              child: const Text('Vezi Profil'),
                            ),
                          ],
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
