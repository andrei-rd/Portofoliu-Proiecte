import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'admin_service.dart';

class UsersWalletScreen extends StatefulWidget {
  const UsersWalletScreen({super.key});

  @override
  State<UsersWalletScreen> createState() => _UsersWalletScreenState();
}

class _UsersWalletScreenState extends State<UsersWalletScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _editUser(String userId, Map<String, dynamic> data) async {
    final TextEditingController amountController = TextEditingController(text: (data['walletBalance'] ?? 0.0).toString());
    String selectedRole = data['role'] ?? 'user';
    final adminService = Provider.of<AdminService>(context, listen: false);
    
    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Edit User: ${data['displayName'] ?? 'User'}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
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
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final double? newBalance = double.tryParse(amountController.text);
                  if (newBalance == null) return;

                  Navigator.pop(context);

                  try {
                    if (newBalance != (data['walletBalance'] ?? 0.0)) {
                      await adminService.updateUserWalletBalance(userId, newBalance);
                    }
                    if (selectedRole != (data['role'] ?? 'user')) {
                      await adminService.updateUserRole(userId, selectedRole);
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Successfully updated user!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users Virtual Wallet'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Balance')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final userId = doc.id;
                    final name = data['displayName'] ?? 'N/A';
                    final email = data['email'] ?? 'N/A';
                    final balance = (data['walletBalance'] ?? 0.0).toDouble();
                    final role = data['role'] ?? 'user';

                    return DataRow(cells: [
                      DataCell(Text(name)),
                      DataCell(Text(email)),
                      DataCell(
                        Chip(
                          label: Text(role.toString().toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white)),
                          backgroundColor: role == 'admin' ? Colors.purple : Colors.grey,
                        ),
                      ),
                      DataCell(Text('$balance RON')),
                      DataCell(
                        ElevatedButton(
                          onPressed: () => _editUser(userId, data),
                          child: const Text('Edit User'),
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
