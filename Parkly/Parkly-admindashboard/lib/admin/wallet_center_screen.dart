import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'admin_service.dart';

class WalletCenterScreen extends StatefulWidget {
  const WalletCenterScreen({super.key});

  @override
  State<WalletCenterScreen> createState() => _WalletCenterScreenState();
}

class _WalletCenterScreenState extends State<WalletCenterScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final adminService = Provider.of<AdminService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet Control Center')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final users = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['displayName'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || email.contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final doc = users[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final balance = (data['walletBalance'] ?? 0.0).toDouble();
                    final role = data['role'] ?? 'user';

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: role == 'admin' ? Colors.purple.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                          child: Icon(role == 'admin' ? Icons.security : Icons.person, color: role == 'admin' ? Colors.purple : Colors.blue),
                        ),
                        title: Row(
                          children: [
                            Text(data['displayName'] ?? 'No Name'),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: role == 'admin' ? Colors.purple : Colors.grey,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(role.toString().toUpperCase(), style: const TextStyle(fontSize: 8, color: Colors.white)),
                            ),
                          ],
                        ),
                        subtitle: Text('${data['email'] ?? 'No Email'}\nBalance: $balance RON'),
                        trailing: ElevatedButton.icon(
                          onPressed: () => _showEditUserDialog(context, adminService, doc.id, data),
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                        ),
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

  void _showEditUserDialog(BuildContext context, AdminService service, String uid, Map<String, dynamic> data) {
    final TextEditingController controller = TextEditingController(text: (data['walletBalance'] ?? 0.0).toString());
    String selectedRole = data['role'] ?? 'user';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit User: ${data['displayName'] ?? 'User'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sold Portofel (RON)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Rol Utilizator', border: OutlineInputBorder()),
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
                final amount = double.tryParse(controller.text);
                if (amount == null) return;

                if (amount != (data['walletBalance'] ?? 0.0)) {
                  await service.updateUserWalletBalance(uid, amount);
                }
                if (selectedRole != (data['role'] ?? 'user')) {
                  await service.updateUserRole(uid, selectedRole);
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Confirm'),
            )
          ],
        ),
      ),
    );
  }
}
