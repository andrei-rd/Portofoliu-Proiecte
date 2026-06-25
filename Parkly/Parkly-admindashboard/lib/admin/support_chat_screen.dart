import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_service.dart';

class SupportChatScreen extends StatefulWidget {
  final String ticketId;
  final Map<String, dynamic> ticketData;

  const SupportChatScreen({super.key, required this.ticketId, required this.ticketData});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isUploading = false;

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await pickedFile.readAsBytes();
      final adminService = Provider.of<AdminService>(context, listen: false);
      
      final imageUrl = await adminService.uploadChatImage(widget.ticketId, bytes);
      // Trimitem link-ul imaginii și în câmpul de text pentru a fi detectat automat de ambele platforme
      await adminService.replyToTicket(widget.ticketId, imageUrl, imageUrl: imageUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Eroare la trimiterea imaginii: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    
    final adminService = Provider.of<AdminService>(context, listen: false);
    adminService.replyToTicket(widget.ticketId, _messageController.text.trim());
    _messageController.clear();
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminService = Provider.of<AdminService>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.ticketData['subject'] ?? 'Chat Suport', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.ticketData['userEmail'] ?? 'User', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: adminService.getTicketMessagesStream(widget.ticketId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final bool isAdmin = data['sender'] == 'admin';
                    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

                    return _buildMessageBubble(
                      text: data['text'] ?? '',
                      isAdmin: isAdmin,
                      time: timestamp != null ? DateFormat('HH:mm').format(timestamp) : '',
                      imageUrl: data['imageUrl'],
                    );
                  },
                );
              },
            ),
          ),

          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text("Se încarcă imaginea...", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),

          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _isUploading ? null : _pickAndSendImage,
                  icon: const Icon(Icons.image_outlined, color: Colors.grey),
                  tooltip: "Trimite imagine",
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Scrie un mesaj...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  mini: true,
                  backgroundColor: const Color(0xFF2563EB),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({required String text, required bool isAdmin, required String time, String? imageUrl}) {
    // Verificăm dacă textul în sine este un link de imagine (cazul în care aplicația mobilă îl trimite în câmpul 'text')
    bool isTextAUrl = text.startsWith('http') && (text.contains('firebasestorage') || text.contains('.jpg') || text.contains('.png'));
    String? effectiveImageUrl = imageUrl ?? (isTextAUrl ? text : null);
    bool shouldShowText = text.isNotEmpty && !isTextAUrl;

    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(4),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.4),
            decoration: BoxDecoration(
              color: isAdmin ? const Color(0xFF2563EB) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isAdmin ? 16 : 0),
                bottomRight: Radius.circular(isAdmin ? 0 : 16),
              ),
              boxShadow: [if (!isAdmin) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (effectiveImageUrl != null)
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        effectiveImageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 150,
                            width: 200,
                            color: Colors.grey[100],
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          // Dacă imaginea dă eroare, încercăm să afișăm măcar link-ul pentru a putea fi dat click pe el
                          return InkWell(
                            onTap: () => _launchURL(effectiveImageUrl),
                            child: const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Icon(Icons.broken_image_outlined, color: Colors.red, size: 32),
                                  SizedBox(height: 4),
                                  Text("Click pentru a vedea poza", style: TextStyle(fontSize: 10, color: Colors.blue, decoration: TextDecoration.underline)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (shouldShowText)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      text,
                      style: TextStyle(color: isAdmin ? Colors.white : Colors.black87, fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
