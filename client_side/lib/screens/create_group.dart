import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:namer_app/theme/app_colors.dart';
import 'package:namer_app/helpers/Input_field.dart';
import 'package:namer_app/helpers/action_button.dart';
import 'package:namer_app/helpers/search_bar.dart';
import 'package:namer_app/helpers/filter_helper.dart';
import 'package:namer_app/models/contact.dart';
import 'package:namer_app/services/contacts_service.dart';
import 'package:namer_app/services/chat_service.dart';

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ContactService _contactService = ContactService();

  List<ContactModel> _allContacts = [];
  List<ContactModel> _foundContacts = [];
  final Set<String> _selectedUserIds = {}; // Track IDs of selected users
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    try {
      final contacts = await _contactService.getContacts();
      setState(() {
        _allContacts = contacts;
        _foundContacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load contacts")));
    }
  }

  void _runFilter(String query) {
    setState(() {
      _foundContacts = filterItems<ContactModel>(
        _allContacts,
        query,
        (contact) => contact.contact.username,
      );
    });
  }

  Future<void> _handleCreateGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a group name")));
      return;
    }
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select at least one member")));
      return;
    }

    setState(() => _isCreating = true);

    final chatId = await context.read<ChatService>().createGroup(
          name,
          _selectedUserIds.toList(),
        );

    if (mounted) {
      // // Navigate to home and remove all previous routes
      // context.go('/home');
      Navigator.of(context).popUntil((route) => route.isFirst);

      setState(() => _isCreating = false);
      if (chatId != null) {
        // Success  Go to the new chat
        context.go('/home/chat/$chatId');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error creating group")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('New Group',
            style: TextStyle(
                color: Theme.of(context).appBarTheme.foregroundColor,
                fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppPrimaryColor))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      InputField(
                        hintText: 'Group Name',
                        icon: Icons.group_outlined,
                        controller: _groupNameController,
                      ),
                      const SizedBox(height: 10),
                      CustomSearchBar(
                        controller: _searchController,
                        onChanged: _runFilter,
                        hintText: "Search contacts...",
                      ),
                    ],
                  ),
                ),
                _buildHeaderLabel(
                    'SELECT MEMBERS (${_selectedUserIds.length})'),
                Expanded(child: _buildContactList()),
                _buildCreateButton(),
              ],
            ),
    );
  }

  Widget _buildHeaderLabel(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 20, top: 15, bottom: 8),
      child: Text(text,
          style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildContactList() {
    if (_foundContacts.isEmpty) {
      return const Center(
          child: Text("No contacts found",
              style: TextStyle(color: Colors.white54)));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _foundContacts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final contact = _foundContacts[index];
        final isSelected = _selectedUserIds.contains(contact.contact.id);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedUserIds.remove(contact.contact.id);
              } else {
                _selectedUserIds.add(contact.contact.id);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(color: AppPrimaryColor, width: 2)
                  : null,
            ),
            child: Row(
              children: [
                // Profile Picture
                _buildContactAvatar(contact),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.contact.resolvedName,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.titleMedium?.color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (contact.contact.displayName != null &&
                          contact.contact.displayName!.isNotEmpty)
                        Text(
                          '@${contact.contact.username}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: AppPrimaryColor),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactAvatar(ContactModel contact) {
    final hasProfilePicture = contact.contact.hasProfilePicture;
    final username = contact.contact.username;

    if (hasProfilePicture) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(contact.contact.profilePicture!),
        backgroundColor: Colors.grey[300],
        onBackgroundImageError: (_, __) {
          // Fallback is handled automatically by showing backgroundColor
        },
      );
    } else {
      return CircleAvatar(
        radius: 24,
        backgroundColor: AppPrimaryColor,
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  Widget _buildCreateButton() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ActionButton(
        text: 'Create Group',
        color: AppPrimaryColor,
        isLoading: _isCreating,
        onPressed: _handleCreateGroup,
      ),
    );
  }
}
