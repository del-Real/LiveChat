import 'package:flutter/material.dart';
import 'package:namer_app/models/contact.dart';
import 'package:namer_app/services/contacts_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

typedef ContactId = String;

class ContactProvider extends ChangeNotifier {
  final ContactService _contactService = ContactService();

  // Add socket reference
  IO.Socket? socket;

  List<ContactModel> _contacts = [];
  List<ContactModel> _pendingRequests = [];
  List<ContactModel> _sentRequests = []; // Stores requests I sent
  bool _isLoading = false;

  // Public getters
  List<ContactModel> get contacts => _contacts;
  List<ContactModel> get pendingRequests => _pendingRequests;
  List<ContactModel> get sentRequests => _sentRequests;

  int get pendingCount => _pendingRequests.length;
  int get sentCount => _sentRequests.length;
  bool get isLoading => _isLoading;

  bool get hasContacts => _contacts.isNotEmpty;
  bool get hasPendingRequests => _pendingRequests.isNotEmpty;
  bool get hasSentRequests => _sentRequests.isNotEmpty;

  // Add method to set socket
  void setSocket(IO.Socket? newSocket) {
    socket = newSocket;
    _setupSocketListeners();
  }

  // Setup socket listeners
  void _setupSocketListeners() {
    if (socket == null) return;

    // Listen for new contact requests
    socket!.on('contact:request_received', (data) {
      try {
        final newRequest = ContactModel.fromJson(data);
        addPendingRequest(newRequest);
      } catch (e) {
        print('Error parsing contact request: $e');
      }
    });

    // Listen for accepted requests
    socket!.on('contact:request_accepted', (data) {
      try {
        final acceptedContact = ContactModel.fromJson(data);
        _pendingRequests.removeWhere((r) => r.id == acceptedContact.id);

        // Also remove from sent requests if present (e.g. if the other person accepted MY request)
        // Wait, if they accept, I get 'contact:request_accepted' too?
        // Yes, verify server code.
        _sentRequests
            .removeWhere((r) => r.contact.id == acceptedContact.contact.id);

        if (!_contacts.any((c) => c.contact.id == acceptedContact.contact.id)) {
          _contacts.insert(0, acceptedContact);
        }

        notifyListeners();
      } catch (e) {
        print('Error parsing accepted contact: $e');
      }
    });

    // NEW: Listen for contact deletion
    socket!.on('contact:deleted', (data) {
      try {
        final String deletedByUserId = data['userId'];

        // Remove from contacts list
        _contacts.removeWhere((c) => c.contact.id == deletedByUserId);

        // Also clean up requests if any
        _pendingRequests.removeWhere((r) => r.contact.id == deletedByUserId);
        _sentRequests.removeWhere((r) => r.contact.id == deletedByUserId);

        notifyListeners();

        print('Contact removed: $deletedByUserId removed you');
      } catch (e) {
        print('Error handling contact deletion: $e');
      }
    });
  }

  // Lifecycle
  Future<void> init() async {
    _setLoading(true);
    await Future.wait([
      fetchContacts(),
      fetchPendingRequests(),
      fetchSentRequests(),
    ]);
    _setLoading(false);
  }

  // Clears all contact data when user logs out
  void logout() {
    _contacts = [];
    _pendingRequests = [];
    _sentRequests = [];
    _isLoading = false;
    socket = null;
    notifyListeners();
  }

  // Fetch operations
  Future<void> fetchContacts() async {
    _contacts = await _contactService.getContacts();
    notifyListeners();
  }

  Future<void> fetchPendingRequests() async {
    _pendingRequests = await _contactService.getContactRequests();
    notifyListeners();
  }

  Future<void> fetchSentRequests() async {
    try {
      _sentRequests = await _contactService.getSentContactRequests();
      notifyListeners();
    } catch (e) {
      print("Error fetching sent requests: $e");
    }
  }

  // Contact requests
  Future<void> sendRequest(String username) async {
    await _contactService.sendContactRequest(username);
    // Refresh sent requests list optimistically or by fetching
    await fetchSentRequests();
  }

  void addPendingRequest(ContactModel request) {
    if (!_pendingRequests.any((r) => r.id == request.id)) {
      _pendingRequests.insert(0, request);
      notifyListeners();
    }
  }

  void removePendingRequest(ContactId requestId) {
    _pendingRequests.removeWhere((r) => r.id == requestId);
    notifyListeners();
  }

  // Cancel a sent request
  Future<void> cancelSentRequest(ContactModel request) async {
    // Deleting the contact record deletes the request
    await _contactService.deleteContact(request.contact.id);
    _sentRequests.removeWhere((r) => r.id == request.id);
    notifyListeners();
  }

  // Accept / Reject logic
  Future<void> acceptRequest(ContactModel request) async {
    await _contactService.acceptRequest(request.contact.id);
    removePendingRequest(request.id);
    await fetchContacts();
  }

  Future<void> rejectRequest(ContactModel request) async {
    await _contactService.rejectRequest(request.requesterId);
    removePendingRequest(request.id);
  }

  // Contact management
  Future<void> deleteContact(ContactId contactId) async {
    await _contactService.deleteContact(contactId);
    _contacts.removeWhere((c) => c.contact.id == contactId);
    notifyListeners();
  }

  void addAcceptedContact(ContactModel newFriend) {
    if (!_contacts.any((c) => c.contact.id == newFriend.contact.id)) {
      _contacts.insert(0, newFriend);
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(ContactModel contact) async {
    final bool newStatus = !contact.isFavorite;

    await _contactService.updateContactStatus(
      contact.id,
      {'isFavorite': newStatus},
    );

    final int index = _contacts.indexWhere((c) => c.id == contact.id);

    if (index != -1) {
      _contacts[index] = contact.copyWith(isFavorite: newStatus);
      notifyListeners();
    }
  }

  // Internal helpers
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

// Extensions
extension ContactProviderExtensions on ContactProvider {
  bool get isIdle => !isLoading;
}
