import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';
import '../services/language_service.dart';
import 'chat_conversation_screen.dart';
import 'public_profile_screen.dart';

class ChatsListScreen extends StatelessWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatService chatService = ChatService();
    final lang = LanguageService();

    return ListenableBuilder(
      listenable: lang,
      builder: (context, child) {
        final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: AppBar(
            title: Text(
              lang.translate('nav_messages'),
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
          body: currentUserId.isEmpty
              ? Center(child: Text(lang.currentLocale.languageCode == 'ro' ? 'Vă rugăm să vă autentificați' : 'Please log in'))
              : StreamBuilder<QuerySnapshot>(
                  stream: chatService.getChats(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              Text('Eroare: ${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              lang.translate('no_messages'),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    final chats = snapshot.data!.docs;
                    // Sortăm conversațiile descrescător după data ultimului mesaj (client-side pentru a evita erorile de index)
                    chats.sort((a, b) {
                      final aTime = (a.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
                      final bTime = (b.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      return bTime.compareTo(aTime);
                    });

                    return ListView.builder(
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        final chatDoc = chats[index];
                        final chat = chatDoc.data() as Map<String, dynamic>;
                        final List participants = chat['participants'] ?? [];
                        final String receiverId = participants.firstWhere(
                            (id) => id != currentUserId,
                            orElse: () => '');

                        if (receiverId.isEmpty) return const SizedBox();

                        return StreamBuilder<DocumentSnapshot>(
                          stream: receiverId == 'parkly_support'
                              ? FirebaseFirestore.instance.collection('tickets').doc(currentUserId).snapshots()
                              : FirebaseFirestore.instance.collection('users').doc(receiverId).snapshots(),
                          builder: (context, userSnapshot) {
                            String name = 'User';
                            String? photoURL;
                            String lastMessage = chat['lastMessage'] ?? '';
                            Timestamp? lastTime = chat['lastMessageTime'] as Timestamp?;
                            
                            if (receiverId == 'parkly_support') {
                              name = 'Echipa Parkly';
                              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                                final ticketData = userSnapshot.data!.data() as Map<String, dynamic>;
                                // Luăm mesajul cel mai nou dintre chat-ul local și ticket-ul din dashboard
                                final Timestamp? ticketTime = ticketData['lastTimestamp'] as Timestamp?;
                                if (ticketTime != null && (lastTime == null || ticketTime.seconds > lastTime.seconds)) {
                                  lastMessage = ticketData['lastMessage'] ?? lastMessage;
                                  lastTime = ticketTime;
                                }
                              }
                            } else {
                              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                name = userData['displayName'] ?? userData['name'] ?? 'User';
                                photoURL = userData['photoURL'];
                              }
                            }

                            final bool isUnread = (chat['unreadBy'] as List?)?.contains(currentUserId) ?? false;

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: isUnread ? Border.all(color: const Color(0xFF2563EB).withOpacity(0.3), width: 1) : null,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4))
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PublicProfileScreen(userId: receiverId),
                                      ),
                                    );
                                  },
                                  child: CircleAvatar(
                                    radius: 25,
                                    backgroundColor: const Color(0xFF2563EB),
                                    backgroundImage: receiverId == 'parkly_support'
                                        ? const AssetImage('lib/assets/main.jpeg')
                                        : (photoURL != null ? NetworkImage(photoURL) : null),
                                    child: (photoURL == null && receiverId != 'parkly_support')
                                        ? Text(name[0].toUpperCase(),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold))
                                        : null,
                                  ),
                                ),
                                title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(receiverId == 'parkly_support' ? 'Echipa Parkly' : name, 
                                          style: TextStyle(
                                            fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold,
                                            fontSize: 15,
                                          )),
                                      ),
                                      if (receiverId == 'parkly_support')
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('OFICIAL', style: TextStyle(color: Color(0xFF2563EB), fontSize: 8, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isUnread ? Colors.black87 : Colors.grey.shade600,
                                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      lastTime != null
                                          ? DateFormat('HH:mm').format(lastTime.toDate())
                                          : '',
                                      style: TextStyle(
                                        fontSize: 11, 
                                        color: isUnread ? const Color(0xFF2563EB) : Colors.grey.shade400,
                                        fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    if (isUnread)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF2563EB),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatConversationScreen(
                                        receiverId: receiverId,
                                        receiverName: name,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}
