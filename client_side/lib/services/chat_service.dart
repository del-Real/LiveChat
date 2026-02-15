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
  List<MessageModel> pinnedMessages = [];
  List<String> blockedUsers = [];

  String? userId;
  String? userName;
  String? activeChatId;
  String? userProfilePic;

  Map<String, Map<String, String>> typingUsers = {};
  Map<String, bool> userPresence = {};
  Map<String, DateTime> userLastSeen = {};
  String otherUserTyping = "";
  String otherUserDraft = "";

  bool isLoading = false;
  bool hasMore = true;
  final int _limit = 20;
  Timer? _typingTimer;

  int get typingCount => typingUsers.length;

  ChatService(this.contactProvider);

  Future<void> init() async {
    final user = await _authService.getUser();
    if (user == null) {
      print("[ChatService] No user found, clearing state.");
      logout();
      return;
    }

    // Only re-init if the user changed or socket is dead
    if (userId == user.id && socket != null && socket!.connected) {
      print("[ChatService] Already initialized for ${user.username}");
      return;
    }

    if (socket != null) {
      socket!.disconnect();
      socket!.dispose();
      socket = null;
    }

    userId = user.id;
    userName = (user.displayName != null && user.displayName!.isNotEmpty)
        ? user.displayName
        : user.username;
    userProfilePic = user.profilePicture;

    print("[ChatService] Initializing socket for $userName ($userId)");

    socket = IO.io(
        ApiConfig.baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setQuery({'userId': userId})
            .enableForceNew()
            .enableAutoConnect()
            .build());

    _setupSecurityAndLifeCycle();
    _setupMessageHandlers();
    _setupUserStatusHandlers();
    _setupChatActionHandlers();
    _setupContactHandlers();
  }


  void _setupSecurityAndLifeCycle() {
    socket!.onConnect((_) {
      print('[Communication] Secured gateway connection');
      contactProvider.setSocket(socket);
      fetchBlockedUsers();
    });

    socket!.on('chat_status', (data) {
      final String chatId = data['chatId'];
      final bool isDisabled = data['isMessagingDisabled'];
      final index = chats.indexWhere((c) => c.id == chatId);
      if (index != -1) {
        chats[index].isMessagingDisabled = isDisabled;
        notifyListeners();
      }
    });
    socket!.on('user_block_update', (data) {
      final String targetId = data['targetUserId'] ?? "";
      final bool isBlocked = data['isBlocked'] == true;
      final bool isBlockedByOther = data['isBlockedByOther'] == true;

      if (isBlocked || isBlockedByOther) {
        userPresence.remove(targetId);
        userLastSeen.remove(targetId);
        if (isBlocked && !blockedUsers.contains(targetId)) {
          blockedUsers.add(targetId);
        }
      } else if (isBlocked == false) {
        blockedUsers.remove(targetId);
        
        if (data['presence'] != null) {
          final p = data['presence'];
          userPresence[targetId] = p['isOnline'] == true;
          if (p['lastSeen'] != null) {
            userLastSeen[targetId] = DateTime.parse(p['lastSeen']);
          }
        }
      }
      notifyListeners();
    });
  }

  void _setupMessageHandlers() {
    socket!.on('receive_message', (data) {
      final newMessage = MessageModel.fromJson(data);
      if (data['chatId'] == activeChatId) {
        // Remove optimistic message(s) that might match this new one
        messages.removeWhere((m) => 
          m.id.startsWith('temp_') && 
          m.senderId == newMessage.senderId &&
          (m.text == newMessage.text || (m.imageUrl.isNotEmpty && m.imageUrl == newMessage.imageUrl) || (m.audioUrl.isNotEmpty && m.audioUrl == newMessage.audioUrl))
        );

        messages.insert(0, newMessage);
        messages = List.from(messages);
        notifyListeners();
      }
    });

    socket!.on('messages_seen_update', (data) {
      final chId = data['chatId'];
      bool changed = false;
      if (activeChatId == chId) {
        for (var i = 0; i < messages.length; i++) {
          if (messages[i].status != 'seen') {
            messages[i] = messages[i].copyWith(status: 'seen');
            changed = true;
          }
        }
        if (changed) {
          messages = List.from(messages);
        }
      }
      
      final chatIdx = chats.indexWhere((c) => c.id == chId);
      if (chatIdx != -1) {
        if (chats[chatIdx].lastMessage != null && chats[chatIdx].lastMessage!.status != 'seen') {
            chats[chatIdx] = chats[chatIdx].copyWith(
              lastMessage: chats[chatIdx].lastMessage!.copyWith(status: 'seen'),
              unreadCount: 0,
            );
            changed = true;
        }
      }
      if (changed) notifyListeners();
    });




    socket!.on('receive_message_global', (data) async {
      try {
        final String incomingChatId = data['chatId'];
        print("[ChatService] Global message received for chat: $incomingChatId");
        final int index = chats.indexWhere((c) => c.id == incomingChatId);

        if (index != -1) {
          // Update existing chat
          chats[index] = chats[index].copyWith(
            lastMessage: LastMessage.fromJson(data),
            unreadCount: (data['sender'].toString() != userId && incomingChatId != activeChatId) 
                ? chats[index].unreadCount + 1 
                : chats[index].unreadCount,
            updatedAt: DateTime.now(),
          );
          
          _sortChats();
          notifyListeners();
          print("[ChatService] Updated existing chat $incomingChatId, unread: ${chats[index].unreadCount}");
        } else {
          // New chat received
          print("[ChatService] New chat detected $incomingChatId, fetching details...");
          final newChat = await fetchSingleChat(incomingChatId);
          if (newChat != null) {
            newChat.lastMessage = LastMessage.fromJson(data);
            newChat.unreadCount = (incomingChatId == activeChatId) ? 0 : 1;
            
            chats.add(newChat); // Add to list then sort
            _sortChats();
            notifyListeners();
            print("[ChatService] Added new chat $incomingChatId to list.");
          }
        }
      } catch (e) {
        print("Error in receive_message_global: $e");
      }
    });


    socket!.on('current_draft', (data) {
      final String id = data['senderId'] ?? "";
      final String name = data['sender'] ?? "User";
      if (id.isNotEmpty && id != userId) {
        if ((data['draft'] ?? "").toString().isEmpty) {
          typingUsers.remove(id);
        } else {
          typingUsers[id] = {
            'name': name,
            'draft': data['draft'],
            'profilePicture': data['profilePicture']
          };
        }
      }
      otherUserTyping = name;
      otherUserDraft = data['draft'] ?? "";
      notifyListeners();
    });
  }

  void _setupUserStatusHandlers() {
    socket!.on('user_status_update', (data) {
      final String uId = data['userId'];
      userPresence[uId] = data['isOnline'];
      if (data['lastSeen'] != null) {
        userLastSeen[uId] = DateTime.parse(data['lastSeen']);
      }
      notifyListeners();
    });

    socket!.on('user_typing_global', (data) {
      final index = chats.indexWhere((c) => c.id == data['chatId']);
      if (index != -1) {
        chats[index].isTyping = data['isTyping'];
        notifyListeners();
      }
    });

    socket!.on('room_presence', (data) {
      (data as Map).forEach((key, value) {
        if (value is Map) {
          userPresence[key] = value['isOnline'] ?? false;
          if (value['lastSeen'] != null) {
            userLastSeen[key] = DateTime.parse(value['lastSeen']);
          }
        } else {
          userPresence[key] = value as bool;
        }
      });
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
  }

  void _setupChatActionHandlers() {
    socket!.on('chat_created', (data) {
      final nc = ChatModel.fromJson(data['chat'], currentUserId: userId);
      if (!chats.any((c) => c.id == nc.id)) {
        chats.insert(0, nc);
        notifyListeners();
      }
    });

    socket!.on('added_to_group', (data) {
      final nc = ChatModel.fromJson(data['chat'], currentUserId: userId);
      final idx = chats.indexWhere((c) => c.id == nc.id);
      if (idx == -1) {
        chats.insert(0, nc);
      } else {
        chats[idx] = nc;
      }
      notifyListeners();
    });



    socket!.on('message_deleted', (data) {
      messages.removeWhere((m) => m.id == data['messageId']);
      messages = List.from(messages);
      notifyListeners();
    });

    socket!.on('message_edited', (data) {
      final String mId = data['messageId'];
      final String txt = data['text'];
      final idx = messages.indexWhere((m) => m.id == mId);
      if (idx != -1) {
        messages[idx].text = txt;
        messages[idx].isEdited = true;
        messages = List.from(messages);
      }
      for (var c in chats) {
        if (c.lastMessage?.id == mId) {
          c.lastMessage = c.lastMessage!.copyWith(text: txt);
          break;
        }
      }
      notifyListeners();
    });

    socket!.on('message_pinned', (data) {
      final String mId = data['messageId'];
      final bool pinned = data['isPinned'];
      final idx = messages.indexWhere((m) => m.id == mId);
      if (idx != -1) {
        messages[idx].isPinned = pinned;
        messages = List.from(messages);
      }
      if (pinned) {
        if (!pinnedMessages.any((m) => m.id == mId)) {
          if (idx != -1) pinnedMessages.insert(0, messages[idx]);
          else fetchPinnedMessages(activeChatId ?? '');
        }
      } else {
        pinnedMessages.removeWhere((m) => m.id == mId);
      }
      pinnedMessages = List.from(pinnedMessages);
      notifyListeners();
    });

    socket!.on('chat_status_updated', (data) {
      final String cId = data['chatId'];
      final idx = chats.indexWhere((c) => c.id == cId);
      if (idx != -1) {
        if (data['isPinned'] != null) chats[idx].isPinned = data['isPinned'];
        if (data['isFavorite'] != null) chats[idx].isFavorite = data['isFavorite'];
        if (data['isArchived'] != null) chats[idx].isArchived = data['isArchived'];
        _sortChats();
        notifyListeners();
      }
    });

    socket?.on('members_added', (data) {
      final String chId = data['chatId'];
      final sysMsg = data['systemMessage'];
      final idx = chats.indexWhere((c) => c.id == chId);
      if (idx != -1) {
        final List<User> users = (data['newMembers'] as List).map((m) => User.fromJson(m)).toList();
        for (var u in users) {
          if (!chats[idx].members.any((m) => m.id == u.id)) chats[idx].members.add(u);
        }
        if (sysMsg != null) chats[idx].lastMessage = LastMessage.fromJson(sysMsg);
        if (activeChatId == chId && sysMsg != null) {
          messages.insert(0, MessageModel.fromJson(sysMsg));
          messages = List.from(messages);
        }
        notifyListeners();
      }
    });

    socket?.on('member_left', (data) {
      final String chId = data['chatId'];
      final sysMsg = data['systemMessage'];
      final idx = chats.indexWhere((c) => c.id == chId);
      if (idx != -1) {
        chats[idx].members.removeWhere((m) => m.id == data['userId']);
        if (sysMsg != null) chats[idx].lastMessage = LastMessage.fromJson(sysMsg);
        if (activeChatId == chId && sysMsg != null) {
          messages.insert(0, MessageModel.fromJson(sysMsg));
          messages = List.from(messages);
        }
        notifyListeners();
      }
    });
  }

  void _setupContactHandlers() {
    socket?.on('contact:request_received', (data) => contactProvider.addPendingRequest(ContactModel.fromJson(data)));
    socket?.on('contact:request_accepted', (data) => contactProvider.addAcceptedContact(ContactModel.fromJson(data)));
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
    for (var chat in chats) {
      for (var member in chat.members) {
        if (member.lastSeen != null) {
          userLastSeen[member.id] = member.lastSeen!;
        }
      }
    }
    _sortChats();
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
    fetchPinnedMessages(chatId);
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
        final List<MessageModel> fetchedMessages =
            history.map((m) => MessageModel.fromJson(m)).toList();

        if (isLoadMore) {
          messages.addAll(fetchedMessages);
        } else {
          // Keep our local optimistic (sending) messages
          final tempMessages = messages.where((m) => m.id.startsWith('temp_')).toList();
          
          // Remove from fetched messages any that we already have (to avoid duplicates)
          fetchedMessages.removeWhere((fm) => messages.any((m) => m.id == fm.id));
          
          messages = [...tempMessages, ...fetchedMessages];
        }

        hasMore = fetchedMessages.length == _limit;
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
          contentType: MediaType('image', mimeType),
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', mimeType),
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

  Future<String?> uploadAudio(String filePath) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/messages/upload-audio');
      final request = http.MultipartRequest('POST', url);
       
      if (kIsWeb) {
          final response = await http.get(Uri.parse(filePath));
          final bytes = response.bodyBytes;
           
          request.files.add(http.MultipartFile.fromBytes(
            'audio',
            bytes,
            filename: 'audio.webm', // Web usually records to webm/opus
            contentType: MediaType('audio', 'webm'),
          ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'audio',
          filePath,
          contentType: MediaType('audio', 'm4a'), // Mobile usually m4a/aac
        ));
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return data['audioUrl'];
      }
      print("SERVER ERROR ${response.statusCode}: $responseBody");
      return null;
    } catch (e) {
      print("Audio Upload error: $e");
      return null;
    }
  }

  void sendMessage(String chatId, String text, {String? imageUrl, String? audioUrl}) {
    if (socket == null || userId == null) {
      print("[ChatService] Cannot send message: socket or userId is null");
      return;
    }
    
    print("[ChatService] Sending message to $chatId: '$text'");

    // Optimistic Update for messages list (ChatScreen)
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final newMessage = MessageModel(
      id: tempId,
      senderId: userId!,
      senderName: userName ?? 'Me',
      text: text,
      imageUrl: imageUrl ?? '',
      audioUrl: audioUrl ?? '',
      timestamp: DateTime.now().toLocal().toString().substring(11, 16),
      rawTimestamp: DateTime.now().toIso8601String(),
      status: 'sending',
    );

    if (activeChatId == chatId) {
      messages.insert(0, newMessage);
      messages = List.from(messages);
      print("[ChatService] Optimistically added message to current chat.");
    }

    // Optimistic Update for chats list (Sidebar/Home)
    final index = chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      final chat = chats[index];
      
      String previewText = text;
      if (text.isEmpty) {
        if (imageUrl != null && imageUrl.isNotEmpty) previewText = 'Photo';
        else if (audioUrl != null && audioUrl.isNotEmpty) previewText = 'Voice Message';
      }

      chats[index] = chat.copyWith(
        lastMessage: LastMessage(
          id: tempId,
          text: previewText,
          sender: userName ?? 'Me', 
          status: 'sending',
          createdAt: DateTime.now(),
        ),
        updatedAt: DateTime.now(),
      );
      _sortChats();
      print("[ChatService] Optimistically updated chat preview.");
    }
    notifyListeners();


    socket!.emit('send_message', {
      'chatId': chatId,
      'senderId': userId,
      'text': text,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
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

  void editMessage(String messageId, String chatId, String newText) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/messages/$messageId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': newText}),
      );

      if (response.statusCode == 200) {
        socket?.emit('edit_message', {
          'chatId': chatId,
          'messageId': messageId,
          'text': newText,
        });
      }
    } catch (e) {
      print("Error editing message: $e");
    }
  }

  Future<void> togglePinnedChat(String chatId, bool pin) async {
    try {
      final user = await _authService.getUser();
      if (user == null) return;

      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/chats/$chatId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': user.id, 'isPinned': pin}),
      );

      if (response.statusCode == 200) {
        final index = chats.indexWhere((c) => c.id == chatId);
        if (index != -1) {
          chats[index].isPinned = pin;

          // Re-sort chats: Pinned first, then by last message/updatedAt
          _sortChats();
          notifyListeners();
        }
      }
    } catch (e) {
      print("Error pinning chat: $e");
    }
  }

  void _sortChats() {
    chats.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      final dateA = a.lastMessage?.createdAt ?? a.updatedAt ?? DateTime(2000);
      final dateB = b.lastMessage?.createdAt ?? b.updatedAt ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });
    // Create new list reference so context.select notifications work correctly
    chats = List.from(chats);
  }


  Future<void> fetchPinnedMessages(String chatId) async {
    if (chatId.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/messages/pinned/$chatId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        pinnedMessages = data.map((m) => MessageModel.fromJson(m)).toList();
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching pinned messages: $e");
    }
  }

  Future<void> togglePinnedMessage(String chatId, String messageId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/messages/pin/$messageId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool pinned = data['isPinned'];

        // Update locally immediately for better responsiveness
        final index = messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          messages[index].isPinned = pinned;
          messages = List.from(messages);
        }

        // Update pinnedMessages list
        if (pinned) {
          if (!pinnedMessages.any((m) => m.id == messageId)) {
            if (index != -1) {
              pinnedMessages.insert(0, messages[index]);
            } else {
              await fetchPinnedMessages(chatId);
            }
          }
        } else {
          pinnedMessages.removeWhere((m) => m.id == messageId);
        }

        pinnedMessages = List.from(pinnedMessages);
        notifyListeners();

        socket?.emit('pin_message', {
          'chatId': chatId,
          'messageId': messageId,
          'isPinned': pinned,
        });
      }
    } catch (e) {
      print("Error pinning message: $e");
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
      final uniqueMembers = allMembers.toSet().toList();

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chats'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'members': uniqueMembers, 'isGroup': true}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        ChatModel newChat = ChatModel.fromJson(data, currentUserId: user.id);
        
        if (name.trim().isNotEmpty && newChat.name != name.trim()) {
           newChat = newChat.copyWith(name: name.trim());
        }

        final existingIndex = chats.indexWhere((c) => c.id == newChat.id);
        if (existingIndex == -1) {
          chats.add(newChat);
        } else {
          chats[existingIndex] = newChat;
        }
        _sortChats();

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
        final chat = ChatModel.fromJson(chatJson, currentUserId: userId);
        for (var member in chat.members) {
          if (member.lastSeen != null) {
            userLastSeen[member.id] = member.lastSeen!;
          }
        }
        return chat;
      } else {
        print('Failed to fetch chat: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching single chat: $e');
      return null;
    }
  }

  Future<void> fetchBlockedUsers() async {
    if (userId == null) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/blocked/$userId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        blockedUsers = data.map((u) => u['_id'].toString()).toList();
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching blocked users: $e");
    }
  }

  Future<void> blockUser(String targetUserId) async {
    if (userId == null) return;
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/users/block'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'targetUserId': targetUserId,
        }),
      );
      if (response.statusCode == 200) {
        if (!blockedUsers.contains(targetUserId)) {
          blockedUsers.add(targetUserId);
          notifyListeners();
        }
      }
    } catch (e) {
      print("Error blocking user: $e");
    }
  }

  Future<void> unblockUser(String targetUserId) async {
    if (userId == null) return;
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/users/unblock'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'targetUserId': targetUserId,
        }),
      );
      if (response.statusCode == 200) {
        blockedUsers.remove(targetUserId);
        notifyListeners();
      }
    } catch (e) {
      print("Error unblocking user: $e");
    }
  }

}

