// lib/screens/contacts_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:namer_app/services/chat_service.dart';
import 'package:namer_app/services/contact_provider.dart';
import 'package:provider/provider.dart';
import '../helpers/Input_field.dart';
import '../helpers/action_button.dart';
import '../helpers/search_bar.dart';
import '../helpers/contact_tile.dart';
import '../models/contact.dart';
import '../services/contacts_service.dart';
import '../theme/app_colors.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactService _contactService = ContactService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  String _searchQuery = "";
  bool _isSendingRequest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactProvider>().init();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  List<ContactModel> _getFilteredContacts(List<ContactModel> contacts) {
    if (_searchQuery.isEmpty) return contacts;
    return contacts
        .where((c) => c.contact.username
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Future<void> _sendContactRequest() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _showSnackBar('Please enter a username', isError: true);
      return;
    }
    setState(() => _isSendingRequest = true);
    try {
      // 1. Send request via service
      final message = await _contactService.sendContactRequest(username);
      
      // 2. Refresh the provider's sent requests list so it shows up immediately in the Sent tab
      if (mounted) {
        await context.read<ContactProvider>().fetchSentRequests();
      }

      if (mounted) {
        _usernameController.clear();
        _showSnackBar(message);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''),
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSendingRequest = false);
    }
  }

  Future<void> _startChatWithContact(ContactModel contact) async {
    try {
      final chat =
          await _contactService.startChatWithContact(contact.contact.id);
      if (mounted) {
        context.read<ChatService>().updateOrAddChat(chat);

        context.push('/home/chat/${chat.id}');
      }
    } catch (e) {
      _showSnackBar('Failed to start chat', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppErrorColor : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildHeader(ContactProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Contacts',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pending Requests (Received)
            if (provider.pendingCount > 0) ...[
              GestureDetector(
                onTap: () => context.push('/contacts/requests'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppPrimaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mark_email_unread_outlined, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text('${provider.pendingCount}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            
            // Sent Requests & All Requests Button
            GestureDetector(
              onTap: () => context.push('/contacts/requests'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border.all(color: AppPrimaryColor.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt_1,
                        color: Theme.of(context).primaryColor, size: 18),
                    const SizedBox(width: 8),
                    Text('Requests',
                        style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddContactSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Contact',
              style: TextStyle(
                  color: Theme.of(context).textTheme.titleMedium?.color,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InputField(
                  hintText: 'Enter username',
                  controller: _usernameController,
                  icon: Icons.person_search,
                  onSubmitted: _sendContactRequest,
                ),
              ),
              const SizedBox(width: 12),
              ActionButton(
                width: 100,
                color: AppPrimaryColor,
                text: 'Send',
                isLoading: _isSendingRequest,
                onPressed: _sendContactRequest,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader(int count) {
    return Row(
      children: [
        Text('All Contacts',
            style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Text('— $count',
            style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withOpacity(0.4),
                fontSize: 14)),
      ],
    );
  }

  void _showContactOptions(BuildContext context, ContactModel contact) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(contact.isFavorite ? Icons.star : Icons.star_border,
                  color: Colors.yellow),
              title: Text(
                  contact.isFavorite ? 'Remove Favorite' : 'Mark Favorite',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color)),
              onTap: () {
                Navigator.pop(context);
                _handleToggleFavorite(contact);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppErrorColor),
              title: const Text('Delete Contact',
                  style: TextStyle(color: AppErrorColor)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, contact);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ContactModel contact) {
    final contactProvider = context.read<ContactProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text("Delete Contact"),
        content: Text("Remove ${contact.contact.username} from contacts?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await contactProvider.deleteContact(contact.contact.id);

                if (!mounted) return;
                _showSnackBar('Contact removed');
              } catch (e) {
                if (!mounted) return;
                _showSnackBar('Delete failed', isError: true);
                debugPrint('Delete error: $e');
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleToggleFavorite(ContactModel contact) async {
    try {
      // Action happens in the Provider
      await context.read<ContactProvider>().toggleFavorite(contact);
    } catch (e) {
      _showSnackBar('Update failed', isError: true);
    }
  }

  Widget _buildEmptyState() {
    final isSearching = _searchController.text.isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        // Prevents overflow on small screens
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppPrimaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching ? Icons.search_off : Icons.person_search_rounded,
                size: 64,
                color: AppPrimaryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isSearching ? 'No results found' : 'No contacts yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactProvider = context.watch<ContactProvider>();
    final filteredContacts = _getFilteredContacts(contactProvider.contacts);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(contactProvider),
              const SizedBox(height: 20),
              _buildAddContactSection(),
              const SizedBox(height: 20),
              CustomSearchBar(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                hintText: 'Search contacts...',
              ),
              const SizedBox(height: 20),
              _buildListHeader(filteredContacts.length),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      contactProvider.init(), // Refresh the provider
                  color: AppPrimaryColor,
                  child: contactProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredContacts.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filteredContacts.length,
                              itemBuilder: (context, index) {
                                final contact = filteredContacts[index];
                                return ContactTile(
                                  contact: contact,
                                  onChat: () => _startChatWithContact(contact),
                                  onToggleFavorite: () =>
                                      _handleToggleFavorite(contact),
                                  onDelete: () =>
                                      _confirmDelete(context, contact),
                                  onMore: () =>
                                      _showContactOptions(context, contact),
                                  onLongPress: () =>
                                      _showContactOptions(context, contact),
                                );
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
