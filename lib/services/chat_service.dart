// services/chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_manager_interface/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_room_model.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  Future<bool> toggleLoveReaction({
    required String messageId,
    required String chatRoomId,
  }) async {
    try {
      final messageRef = _firestore.collection('messages').doc(messageId);
      final messageDoc = await messageRef.get();

      if (!messageDoc.exists) return false;

      final message = MessageModel.fromMap(messageDoc.data()!);
      final isLoved = message.lovedBy.contains(currentUserId);

      if (isLoved) {
        // Remove love
        await messageRef.update({
          'lovedBy': FieldValue.arrayRemove([currentUserId]),
        });
      } else {
        // Add love
        await messageRef.update({
          'lovedBy': FieldValue.arrayUnion([currentUserId]),
        });
      }

      return true;
    } catch (e) {
      print('Error toggling love reaction: $e');
      return false;
    }
  }

  // Send message
  Future<void> sendMessage({
    required String chatRoomId,
    required String content,
    String? imageUrl,
    String? replyToMessageId,
  }) async {
    final messageRef = _firestore.collection('messages').doc();
    final messageId = messageRef.id;

    // Get current user data
    final userDoc =
        await _firestore
            .collection('deliveryManagers')
            .doc(currentUserId)
            .get();
    final user = MyUser.fromDocument(userDoc.data()!);

    final message = MessageModel(
      id: messageId,
      chatRoomId: chatRoomId,
      senderId: currentUserId,
      senderName: user.name,
      content: content,
      imageUrl: imageUrl,
      timestamp: DateTime.now(),
      readBy: [currentUserId],
      replyToMessageId: replyToMessageId,
    );

    // Send message
    await messageRef.set(message.toMap());

    // Update chat room's last message
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'lastMessage': content,
      'lastMessageTime': message.timestamp.millisecondsSinceEpoch,
      'lastMessageSenderId': currentUserId,
    });

    // Update unread count for other participants
    final chatRoomDoc =
        await _firestore.collection('chatRooms').doc(chatRoomId).get();
    final chatRoom = ChatRoomModel.fromMap(chatRoomDoc.data()!);

    final updatedUnreadCount = Map<String, int>.from(chatRoom.unreadCount);
    for (String participantId in chatRoom.participants) {
      if (participantId != currentUserId) {
        updatedUnreadCount[participantId] =
            (updatedUnreadCount[participantId] ?? 0) + 1;
      }
    }

    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'unreadCount': updatedUnreadCount,
    });
  }

  Future<void> resetDeletedBy(String chatRoomId) async {
    // Use update to avoid overwriting the entire document
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'deletedBy': [],
    });
  }

  Future<void> softDeleteChatForCurrentUser(String chatRoomId) async {
    final batch = _firestore.batch();

    // 1. Update chat room's deletedBy
    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    batch.update(chatRoomRef, {
      'deletedBy': FieldValue.arrayUnion([currentUserId]),
    });

    // 2. Update all messages' deletedBy
    final messagesQuery =
        await _firestore
            .collection('messages')
            .where('chatRoomId', isEqualTo: chatRoomId)
            .get();

    for (final doc in messagesQuery.docs) {
      batch.update(doc.reference, {
        'deletedBy': FieldValue.arrayUnion([currentUserId]),
      });
    }

    await batch.commit();
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatRoomId) async {
    final messagesQuery =
        await _firestore
            .collection('messages')
            .where('chatRoomId', isEqualTo: chatRoomId)
            .where('senderId', isNotEqualTo: currentUserId)
            .get();

    final batch = _firestore.batch();

    for (var doc in messagesQuery.docs) {
      final message = MessageModel.fromMap(doc.data());
      if (!message.readBy.contains(currentUserId)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([currentUserId]),
        });
      }
    }

    await batch.commit();

    // Reset unread count
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'unreadCount.$currentUserId': 0,
    });
  }

  // Get chat rooms stream
  Stream<List<ChatRoomModel>> getChatRoomsStream() {
    return _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ChatRoomModel.fromMap(doc.data()))
                  .toList(),
        );
  }

  // Get messages stream
  Stream<List<MessageModel>> getMessagesStream(String chatRoomId) {
    return _firestore
        .collection('messages')
        .where('chatRoomId', isEqualTo: chatRoomId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => MessageModel.fromMap(doc.data()))
                  .toList(),
        );
  }

  // Get users for creating chats
  Stream<List<MyUser>> getUsersStream() {
    return _firestore
        .collection('users')
        .where('id', isNotEqualTo: currentUserId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => MyUser.fromDocument(doc.data()))
                  .toList(),
        );
  }

  // Helper method to update user's chat rooms
  Future<void> _updateUserChatRooms(String userId, String chatRoomId) async {
    await _firestore.collection('users').doc(userId).update({
      'chatRooms': FieldValue.arrayUnion([chatRoomId]),
    });
  }

  // Add participant to group
  Future<void> addParticipantToGroup(String chatRoomId, String userId) async {
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'participants': FieldValue.arrayUnion([userId]),
      'unreadCount.$userId': 0,
    });

    await _updateUserChatRooms(userId, chatRoomId);
  }

  // Remove participant from group
  Future<void> removeParticipantFromGroup(
    String chatRoomId,
    String userId,
  ) async {
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'participants': FieldValue.arrayRemove([userId]),
      'unreadCount.$userId': FieldValue.delete(),
    });

    await _firestore.collection('users').doc(userId).update({
      'chatRooms': FieldValue.arrayRemove([chatRoomId]),
    });
  }
}
