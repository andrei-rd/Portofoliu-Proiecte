import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Obține sau creează ID-ul unic pentru o cameră de chat între doi useri
  String getChatRoomId(String user1, String user2) {
    List<String> ids = [user1, user2];
    ids.sort(); // Sortăm pentru ca ID-ul să fie același indiferent de cine inițiază chat-ul
    return ids.join('_');
  }

  // Trimite un mesaj
  Future<void> sendMessage(String receiverId, String message, {Map<String, dynamic>? replyTo}) async {
    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email ?? '';
    final Timestamp timestamp = Timestamp.now();

    final String chatRoomId = getChatRoomId(currentUserId, receiverId);

    final messageData = {
      'senderId': currentUserId,
      'senderEmail': currentUserEmail,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
      'seen': false,
      'isSupport': receiverId == 'parkly_support' || currentUserId == 'parkly_support',
      if (replyTo != null) 'replyTo': replyTo,
    };

    // 1. Adăugăm mesajul în sub-colecție
    await _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(messageData);

    // 2. Actualizăm metadatele conversației (pentru lista de chat-uri)
    await _db.collection('chats').doc(chatRoomId).set({
      'participants': [currentUserId, receiverId],
      'lastMessage': message,
      'lastMessageTime': timestamp,
      'unreadBy': FieldValue.arrayUnion([receiverId]), 
      'category': (receiverId == 'parkly_support' || currentUserId == 'parkly_support') ? 'support' : 'user_to_user',
      'isSupport': receiverId == 'parkly_support' || currentUserId == 'parkly_support',
    }, SetOptions(merge: true));

    // 3. Notificare Pop-up pentru destinatar
    await _db.collection('notifications').add({
      'target': receiverId,
      'title': '💬 Mesaj nou',
      'message': message,
      'type': 'chat', // Tip nou pentru chat
      'senderId': currentUserId,
      'chatRoomId': chatRoomId,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'showPopup': true,
    });
  }

  // LOGICA NOUĂ PENTRU TICKETS (Dashboard Sync)
  Future<void> sendTicketMessage(String message, {String type = 'text'}) async {
    final String uid = _auth.currentUser!.uid;
    final Timestamp now = Timestamp.now();

    // 1. Asigurăm existența tichetului cu status "open"
    await _db.collection('tickets').doc(uid).set({
      'userId': uid,
      'userEmail': _auth.currentUser!.email,
      'lastMessage': type == 'image' ? '📷 Foto' : message,
      'lastTimestamp': now,
      'status': 'open', // Conform protocolului
      'updatedAt': now,
    }, SetOptions(merge: true));

    // 2. Adăugăm mesajul în sub-colecție conform formatului cerut
    await _db.collection('tickets').doc(uid).collection('messages').add({
      'text': message,
      'sender': 'user',
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Marcare chat ca citit
  Future<void> markAsRead(String chatRoomId) async {
    final String currentUserId = _auth.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;

    await _db.collection('chats').doc(chatRoomId).update({
      'unreadBy': FieldValue.arrayRemove([currentUserId]),
    });

    // Marcare mesaje individuale ca 'seen'
    final unreadMessages = await _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('seen', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {'seen': true, 'seenAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  Future<void> setTypingStatus(String receiverId, bool isTyping) async {
    final String currentUserId = _auth.currentUser!.uid;
    final String chatRoomId = getChatRoomId(currentUserId, receiverId);
    
    await _db.collection('chats').doc(chatRoomId).set({
      'typing': {
        currentUserId: isTyping,
      }
    }, SetOptions(merge: true));
  }

  Future<void> addReaction(String receiverId, String messageId, String emoji) async {
    final String currentUserId = _auth.currentUser!.uid;
    final String chatRoomId = getChatRoomId(currentUserId, receiverId);
    
    await _db.collection('chats').doc(chatRoomId).collection('messages').doc(messageId).set({
      'reactions': {
        currentUserId: emoji,
      }
    }, SetOptions(merge: true));
  }

  Future<void> editMessage(String receiverId, String messageId, String newMessage) async {
    final String currentUserId = _auth.currentUser!.uid;
    final String chatRoomId = getChatRoomId(currentUserId, receiverId);
    
    await _db.collection('chats').doc(chatRoomId).collection('messages').doc(messageId).update({
      'message': newMessage,
      'isEdited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(String receiverId, String messageId) async {
    final String currentUserId = _auth.currentUser!.uid;
    final String chatRoomId = getChatRoomId(currentUserId, receiverId);
    
    await _db.collection('chats').doc(chatRoomId).collection('messages').doc(messageId).delete();
  }

  // Încarcă un fișier și trimite mesajul
  Future<void> sendFileMessage(String receiverId, File file, String type, {Map<String, dynamic>? replyTo}) async {
    final String currentUserId = _auth.currentUser!.uid;
    final String chatRoomId = getChatRoomId(currentUserId, receiverId);
    final String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    
    // 1. Upload la Storage
    Reference ref = _storage.ref().child('chat_attachments').child(chatRoomId).child(fileName);
    UploadTask uploadTask = ref.putFile(file);
    TaskSnapshot snapshot = await uploadTask;
    String downloadUrl = await snapshot.ref.getDownloadURL();

    // 2. Trimite mesajul cu URL-ul
    final Timestamp timestamp = Timestamp.now();
    final messageData = {
      'senderId': currentUserId,
      'receiverId': receiverId,
      'message': downloadUrl,
      'type': type, // 'image' sau 'document'
      'timestamp': timestamp,
      'seen': false,
      if (replyTo != null) 'replyTo': replyTo,
    };

    await _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(messageData);

    await _db.collection('chats').doc(chatRoomId).set({
      'participants': [currentUserId, receiverId],
      'lastMessage': type == 'image' ? '📷 Foto' : '📄 Document',
      'lastMessageTime': timestamp,
      'unreadBy': FieldValue.arrayUnion([receiverId]),
      'category': (receiverId == 'parkly_support' || currentUserId == 'parkly_support') ? 'support' : 'user_to_user',
      'isSupport': receiverId == 'parkly_support' || currentUserId == 'parkly_support',
    }, SetOptions(merge: true));

    // DACĂ ESTE SUPORT, TRIMITEM ȘI ÎN COLECCIA TICKETS
    if (receiverId == 'parkly_support') {
      await sendTicketMessage(downloadUrl, type: type);
    }

    // 3. Notificare Pop-up pentru destinatar
    await _db.collection('notifications').add({
      'target': receiverId,
      'title': '💬 Mesaj nou (${type == 'image' ? 'Foto' : 'Document'})',
      'message': 'Ai primit un fișier nou în chat.',
      'type': 'chat',
      'senderId': currentUserId,
      'chatRoomId': chatRoomId,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'showPopup': true,
    });
  }

  // Stream pentru mesajele dintr-o cameră
  Stream<QuerySnapshot> getMessages(String chatRoomId) {
    return _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Stream pentru lista de chat-uri ale utilizatorului curent
  Stream<QuerySnapshot> getChats() {
    return _db
        .collection('chats')
        .where('participants', arrayContains: _auth.currentUser?.uid)
        .snapshots();
  }

  Future<void> sendLocationMessage(String receiverId, double lat, double lng, {bool isLive = false}) async {
    final String currentUserId = _auth.currentUser!.uid;
    final String chatRoomId = getChatRoomId(currentUserId, receiverId);
    final Timestamp timestamp = Timestamp.now();

    final messageData = {
      'senderId': currentUserId,
      'receiverId': receiverId,
      'message': 'Locație partajată',
      'type': isLive ? 'live_location' : 'location',
      'latitude': lat,
      'longitude': lng,
      'timestamp': timestamp,
      'seen': false,
      'isLiveActive': isLive,
    };

    await _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(messageData);

    await _db.collection('chats').doc(chatRoomId).set({
      'lastMessage': isLive ? '📍 Locație în timp real' : '📍 Locație',
      'lastMessageTime': timestamp,
      'unreadBy': FieldValue.arrayUnion([receiverId]),
    }, SetOptions(merge: true));
  }

  Future<void> stopLiveLocation(String receiverId, String messageId) async {
    final String currentUserId = _auth.currentUser!.uid;
    final String chatRoomId = getChatRoomId(currentUserId, receiverId);
    
    await _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .update({'isLiveActive': false});
  }

  Future<void> updateLiveLocationCoords(String receiverId, String messageId, double lat, double lng) async {
    final String currentUserId = _auth.currentUser!.uid;
    final String chatRoomId = getChatRoomId(currentUserId, receiverId);
    
    await _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .update({
      'latitude': lat,
      'longitude': lng,
      'lastUpdate': FieldValue.serverTimestamp(),
    });
  }
}
