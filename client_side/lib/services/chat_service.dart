import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:namer_app/models/contact.dart';
import 'package:namer_app/models/message.dart';
import 'package:namer_app/services/contact_provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import '../api_config.dart';
import 'auth_service.dart';
import '../models/chat.dart';
import '../models/user.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

class ChatService extends ChangeNotifier {
  IO.Socket? socket;
  final AuthService _authService = AuthService();
  final ContactProvider contactProvider;

  List<ChatModel> chats = [];
  List<MessageModel> messages = [];

  String? userId;
  String? userName;
  String? activeChatId;
  String? userProfilePic;

  Map<String, Map<String, String>> typingUsers = {};
  Map<String, bool> userPresence = {};
  String otherUserTyping = "";
  String otherUserDraft = "";

  bool isLoading = false;
  bool hasMore = true;
  final int _limit = 20;
  Timer? _typingTimer;

  int get typingCount => typingUsers.length;

  ChatService(this.contactProvider);

  Future<void> init() async {
    if (socket != null) {
      socket!.disconnect();
      socket!.dispose();
      socket = null;
    }

    userId = null;
    userName = null;
    userProfilePic = null;

    chats = [];
    messages = [];
    typingUsers.clear();
    userPresence.clear();

    final user = await _authService.getUser();

    if (user == null) {
      print("ChatService: No user found in storage, skipping socket init.");
      return;
    }
    userId = user.id;
    userName = (user.displayName != null && user.displayName!.isNotEmpty)
        ? user.displayName
        : user.username;
    userProfilePic = user.profilePicture;

    socket = IO.io(
        ApiConfig.baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setQuery({'userId': userId})
            .enableForceNew()
            .enableAutoConnect()
            .build());

    socket!.onConnect((_) {
      print('Connected to Socket Server');

      // Share socket with ContactProvider
      contactProvider.setSocket(socket);
    });

    socket!.on('chat_status', (data) {
      final String chatId = data['chatId'];
      final bool isDisabled = data['isMessagingDisabled'];

      final chatIndex = chats.indexWhere((c) => c.id == chatId);
      if (chatIndex != -1) {
        chats[chatIndex].isMessagingDisabled = isDisabled;
        notifyListeners();
      }
    });

    socket!.on('receive_message', (data) {
      final newMessage = MessageModel.fromJson(data);
      if (data['chatId'] == activeChatId) {
        messages.insert(0, newMessage);
        messages = List.from(messages);
        notifyListeners();
      }
    });

    socket?.on('members_added', (data) {
      final String chatId = data['chatId'];
      final List rawMembers = data['newMembers'];
      final systemMessage = data['systemMessage'];

      final index = chats.indexWhere((c) => c.id == chatId);
      if (index != -1) {
        final List<User> newUsers =
            rawMembers.map((m) => User.fromJson(m)).toList();

        for (var user in newUsers) {
          if (!chats[index].members.any((m) => m.id == user.id)) {
            chats[index].members.add(user);
          }
        }

        // Update last message with system message
        if (systemMessage != null) {
          chats[index].lastMessage = LastMessage.fromJson(systemMessage);
        }

        // If user is in this chat, add the system message to messages
        if (activeChatId == chatId && systemMessage != null) {
          final newMessage = MessageModel.fromJson(systemMessage);
          messages.insert(0, newMessage);
          messages = List.from(messages);
        }

        notifyListeners();
      }
    });

    socket?.on('member_left', (data) {
      final String chatId = data['chatId'];
      final String leftUserId = data['userId'];
      final String userName = data['userName'] ?? 'Someone';
      final systemMessage = data['systemMessage'];

      final index = chats.indexWhere((c) => c.id == chatId);

      if (index != -1) {
        chats[index].members.removeWhere((m) => m.id == leftUserId);

        // Update last message with system message
        if (systemMessage != null) {
          chats[index].lastMessage = LastMessage.fromJson(systemMessage);
        }

        // If user is in this chat, add the system message to messages
        if (activeChatId == chatId && systemMessage != null) {
          final newMessage = MessageModel.fromJson(systemMessage);
          messages.insert(0, newMessage);
          messages = List.from(messages);
        }

        notifyListeners();
      }
    });

    socket!.on('receive_message_global', (data) async {
      final String incomingChatId = data['chatId'];
      final index = chats.indexWhere((c) => c.id == incomingChatId);

      if (index != -1) {
        chats[index].lastMessage = LastMessage(
          id: data['_id'],
          text: data['text'],
          sender: data['sender'],
          status: data['status'] ?? 'sent',
          createdAt: DateTime.parse(data['createdAt']),
        );

        // Only increment if the user is not currently inside this chat room
        if (data['sender'].toString() != userId &&
            incomingChatId != activeChatId) {
          chats[index].unreadCount += 1;
        }

        final chatToMove = chats.removeAt(index);
        chats.insert(0, chatToMove);
        notifyListeners();
      } else {
        // Handling a message for a chat not yet in the list
        final newChat = await fetchSingleChat(incomingChatId);

        if (newChat != null) {
          newChat.lastMessage = LastMessage(
            id: data['_id'],
            text: data['text'],
            sender: data['sender'],
            status: data['status'] ?? 'sent',
            createdAt: DateTime.parse(data['createdAt']),
          );

          // If the new message is for the screen I'm currently on, keep count at 0
          newChat.unreadCount = (incomingChatId == activeChatId) ? 0 : 1;

          chats.insert(0, newChat);
          notifyListeners();
        }
      }
    });

    socket!.on('current_draft', (data) {
      final String typingId = data['senderId'] ?? "";
      final String typingName = data['sender'] ?? "User";
      final String draft = data['draft'] ?? "";
      final String profilePicture = data['profilePicture'];

      if (typingId.isNotEmpty && typingId != userId) {
        if (draft.isEmpty) {
          typingUsers.remove(typingId);
        } else {
          typingUsers[typingId] = {
            'name': typingName,
            'draft': draft,
            'profilePicture': profilePicture
          };
        }
      }

      otherUserTyping = typingName;
      otherUserDraft = draft;
      notifyListeners();
    });

    socket!.on('user_profile_updated', (data) {
      final updatedUser = User.fromJson(data);

      for (var chat in chats) {
        for (int i = 0; i < chat.members.length; i++) {
          if (chat.members[i].id == updatedUser.id) {
            chat.members[i] = updatedUser;
          }
        }
      }
      notifyListeners();
    });

    socket!.on('user_status_update', (data) {
      userPresence[data['userId']] = data['isOnline'];
      notifyListeners();
    });

    socket!.on('user_typing_global', (data) {
      final index = chats.indexWhere((c) => c.id == data['chatId']);
      if (index != -1) {
        chats[index].isTyping = data['isTyping'];
        notifyListeners();
      }
    });

    // Listen for when a chat is created (group creation)
    socket!.on('chat_created', (data) {
      print('Chat created event received: $data');
      try {
        final newChat = ChatModel.fromJson(data['chat'], currentUserId: userId);

        // Check if chat already exists (creator might already have it)
        final existingIndex = chats.indexWhere((c) => c.id == newChat.id);

        if (existingIndex == -1) {
          // Add new chat to the beginning
          chats.insert(0, newChat);
          notifyListeners();
          print('New chat created and added: ${newChat.name}');
        }
      } catch (e) {
        print('Error handling chat_created: $e');
      }
    });

    // Listen for when user is added to a group
    socket!.on('added_to_group', (data) {
      print('Added to group: $data');
      try {
        final newChat = ChatModel.fromJson(data['chat'], currentUserId: userId);

        // Check if chat already exists
        final existingIndex = chats.indexWhere((c) => c.id == newChat.id);

        if (existingIndex == -1) {
          // Add new chat to the beginning
          chats.insert(0, newChat);
          notifyListeners();

          print('New group chat added: ${newChat.name}');
        } else {
          // Update existing chat
          chats[existingIndex] = newChat;
          notifyListeners();

          print('Group chat updated: ${newChat.name}');
        }
      } catch (e) {
        print('Error handling added_to_group: $e');
      }
    });

    socket!.on('messages_seen_update', (data) {
      final String incomingChatId = data['chatId'];
      if (incomingChatId == activeChatId) {
        for (var msg in messages) {
          msg.status = 'seen';
        }
        messages = List.from(messages);
      }
      final chatIndex = chats.indexWhere((c) => c.id == incomingChatId);
      if (chatIndex != -1 && chats[chatIndex].lastMessage != null) {
        chats[chatIndex].lastMessage =
            chats[chatIndex].lastMessage!.copyWith(status: 'seen');
      }
      notifyListeners();
    });

    socket!.on('message_deleted', (data) {
      messages.removeWhere((m) => m.id == data['messageId']);
      messages = List.from(messages);
      notifyListeners();
    });

    socket!.on('room_presence', (data) {
      (data as Map).forEach((key, value) {
        userPresence[key] = value as bool;
      });
      notifyListeners();
    });

    // Contact logic listeners
    socket?.on('contact:request_received', (data) {
      print('socket event triggered: contact:request_received');
      final newRequest = ContactModel.fromJson(data);
      contactProvider.addPendingRequest(newRequest);
    });

    socket?.on('contact:request_accepted', (data) {
      print('socket event triggered: contact:request_accepted');
      final newContact = ContactModel.fromJson(data);
      contactProvider.addAcceptedContact(newContact);
    });
  }

  void logout() {
    socket?.disconnect();
    socket?.dispose();
    socket = null;

    userId = null;
    userName = null;
    userProfilePic = null;
    activeChatId = null;

    chats = [];
    messages = [];

    typingUsers.clear();
    userPresence.clear();
    activeChatId = null;

    notifyListeners();
    print("ChatService state cleared");
  }

  Future<User?> updateProfile(
      {String? displayName, String? profilePicture}) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/users/update-profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'displayName': displayName,
          'profilePicture': profilePicture,
        }),
      );

      if (response.statusCode == 200) {
        final updatedUserData = jsonDecode(response.body);
        final updatedUser = User.fromJson(updatedUserData);

        userName = updatedUser.displayName ?? updatedUser.username;
        await _authService.saveUser(updatedUser);

        notifyListeners();
        return updatedUser;
      }
      return null;
    } catch (e) {
      print("Error updating profile: $e");
      return null;
    }
  }

  void setInitialChats(List<ChatModel> initialChats) {
    chats = initialChats;
    notifyListeners();
  }

  void joinRoom(String chatId) {
    activeChatId = chatId;
    messages.clear();
    typingUsers.clear();
    hasMore = true;

    final index = chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      chats[index] = chats[index].copyWith(unreadCount: 0);
    }

    socket?.emit('mark_as_seen', {
      'chatId': chatId,
      'userId': userId,
    });

    socket?.emit('join_room', chatId);
    notifyListeners();
  }

  void updateOrAddChat(ChatModel newChat) {
    final index = chats.indexWhere((c) => c.id == newChat.id);
    if (index != -1) {
      chats[index] = newChat;
    } else {
      chats.insert(0, newChat);
    }
    notifyListeners();
  }

  void leaveChat(String chatId) {
    activeChatId = null;
    messages.clear();
    typingUsers.clear();
    socket?.emit('leave_room', chatId);

    Future.microtask(() {
      notifyListeners();
    });
  }

  Future<void> updateChatStatus(
      String chatId, Map<String, dynamic> data) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/chats/$chatId/status'),
        body: jsonEncode({...data, 'userId': userId}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final index = chats.indexWhere((c) => c.id == chatId);
        if (index != -1) {
          if (data.containsKey('isFavorite')) {
            chats[index].isFavorite = data['isFavorite'];
          }
          if (data.containsKey('isArchived')) {
            chats[index].isArchived = data['isArchived'];
          }

          chats.sort((a, b) {
            if (a.isFavorite && !b.isFavorite) return -1;
            if (!a.isFavorite && b.isFavorite) return 1;
            DateTime dateA = a.lastMessage?.createdAt ?? DateTime(2000);
            DateTime dateB = b.lastMessage?.createdAt ?? DateTime(2000);
            return dateB.compareTo(dateA);
          });
          notifyListeners();
        }
      }
    } catch (e) {
      print("Error updating chat status: $e");
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/chats/$chatId'),
        body: jsonEncode({"userId": userId}),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        chats.removeWhere((c) => c.id == chatId);
        notifyListeners();
      }
    } catch (e) {
      print("Error deleting chat: $e");
    }
  }

  Future<void> fetchMessages(String chatId, {bool isLoadMore = false}) async {
    if (isLoading || (!hasMore && isLoadMore)) return;
    isLoading = true;
    notifyListeners();

    try {
      String url =
          '${ApiConfig.baseUrl}/messages/paginated/$chatId?limit=$_limit';
      if (isLoadMore && messages.isNotEmpty) {
        url += '&before=${messages.last.rawTimestamp}';
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> history = jsonDecode(response.body);
        final List<MessageModel> newMessages =
            history.map((m) => MessageModel.fromJson(m)).toList();

        if (isLoadMore) {
          messages.addAll(newMessages);
        } else {
          messages = newMessages;
        }

        hasMore = newMessages.length == _limit;
        if (!isLoadMore) markAsSeen(chatId);
      }
    } catch (e) {
      print("Pagination Error: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> uploadImage(XFile? imageFile) async {
    if (imageFile == null) return null;
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/messages/upload');
      final request = http.MultipartRequest('POST', url);

      final extension = imageFile.name.split('.').last.toLowerCase();
      final mimeType =
          (extension == 'jpg' || extension == 'jpeg') ? 'jpeg' : 'png';

      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: imageFile.name,
          contentType: MediaType('image', 'jpeg'),
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return data['imageUrl'];
      } else {
        print("SERVER ERROR ${response.statusCode}: $responseBody");
        return null;
      }
    } catch (e) {
      print("Upload error: $e");
      return null;
    }
  }

  void sendMessage(String chatId, String text, {String? imageUrl}) {
    if (socket == null || userId == null) return;
    socket!.emit('send_message', {
      'chatId': chatId,
      'senderId': userId,
      'text': text,
      'imageUrl': imageUrl,
    });
  }

  void deleteMessage(String messageId, String chatId) async {
    try {
      final response = await http
          .delete(Uri.parse('${ApiConfig.baseUrl}/messages/$messageId'));
      if (response.statusCode == 200) {
        socket?.emit(
            'delete_message', {'chatId': chatId, 'messageId': messageId});
      }
    } catch (e) {
      print("Error deleting message: $e");
    }
  }

  void sendTypingUpdate(String chatId, String text) {
    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();

    _typingTimer = Timer(const Duration(milliseconds: 150), () {
      socket?.emit('typing_update', {
        'room': chatId,
        'sender': userName,
        'senderId': userId,
        'profilePicture': userProfilePic,
        'draft': text,
      });
    });
  }

  void markAsSeen(String chatId) {
    if (socket != null && userId != null && activeChatId == chatId) {
      socket!.emit('mark_as_seen', {'chatId': chatId, 'userId': userId});
    }
  }

  Future<String?> createGroup(String name, List<String> memberIds) async {
    try {
      final user = await _authService.getUser();
      if (user == null) return null;
      final allMembers = [...memberIds, user.id];

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chats'),
        headers: {'Content-Type': 'application/json'},
        body:
            jsonEncode({'name': name, 'members': allMembers, 'isGroup': true}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);

        final newChat = ChatModel.fromJson(data, currentUserId: user.id);

        // Check if chat already exists (from socket event)
        final existingIndex = chats.indexWhere((c) => c.id == newChat.id);

        if (existingIndex == -1) {
          // Add to beginning of list
          chats.insert(0, newChat);
        } else {
          // Update existing chat
          chats[existingIndex] = newChat;
        }

        notifyListeners();

        return newChat.id;
      }
      return null;
    } catch (e) {
      print("Error creating group: $e");
      return null;
    }
  }

  Future<bool> addMembersToGroup(String chatId, List<String> newUserIds) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chats/$chatId/add-members'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'newMemberIds': newUserIds}),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        final updatedChat =
            ChatModel.fromJson(data['finalChat'], currentUserId: userId);

        final index = chats.indexWhere((c) => c.id == chatId);

        if (index != -1) {
          chats[index] = updatedChat;

          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      print("Error adding members: $e");
      return false;
    }
  }

  Future<bool> leaveGroup(String chatId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chats/$chatId/leave'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        chats.removeWhere((c) => c.id == chatId);
        if (activeChatId == chatId) {
          leaveChat(chatId);
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print("Error leaving group: $e");
      return false;
    }
  }

  Future<ChatModel?> updateGroupInfo(String chatId,
      {String? name, String? profilePicture}) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/chats/$chatId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (name != null) 'name': name,
          if (profilePicture != null) 'profilePicture': profilePicture,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is Map<String, dynamic>) {
          final index = chats.indexWhere((c) => c.id == chatId);
          if (index != -1) {
            chats[index] = ChatModel.fromJson(data, currentUserId: userId);
            notifyListeners();
            return chats[index];
          }
        } else {
          // If data is just a String ID, we manually update our local list
          print("Backend returned a String ID. Updating local state manually.");
          final index = chats.indexWhere((c) => c.id == chatId);
          if (index != -1) {
            // Create a new copy with the updated fields
            chats[index] = chats[index].copyWith(
              name: name ?? chats[index].name,
              profilePicture: profilePicture ?? chats[index].profilePicture,
            );
            notifyListeners();
            return chats[index];
          }
        }
      }
      return null;
    } catch (e) {
      print("Error updating group info: $e");
      return null;
    }
  }

  Future<ChatModel?> fetchSingleChat(String chatId) async {
    try {
      final user = await _authService.getUser();
      if (user == null) {
        throw Exception("User session not found");
      }
      final userId = user.id;

      final url = Uri.parse(
          '${ApiConfig.baseUrl}/chats/single-chat/$chatId/user/$userId');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final chatJson = jsonDecode(response.body);
        return ChatModel.fromJson(chatJson, currentUserId: userId);
      } else {
        print('Failed to fetch chat: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching single chat: $e');
      return null;
    }
  }
}
