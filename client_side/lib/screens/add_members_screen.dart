import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../models/contact.dart';
import '../services/contacts_service.dart';
import '../services/chat_service.dart';
import '../theme/app_colors.dart';
import '../helpers/search_bar.dart';
import '../helpers/filter_helper.dart';
import '../helpers/action_button.dart';

class AddMembersScreen extends StatefulWidget {
  final ChatModel chat; // The group we are adding people to

  const AddMembersScreen({super.key, required this.chat});

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ContactService _contactService = ContactService();

  List<ContactModel> _availableContacts = [];
  List<ContactModel> _filteredContacts = [];
  final Set<String> _selectedUserIds = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchAndFilterContacts();
  }

  Future<void> _fetchAndFilterContacts() async {
    try {
      final allContacts = await _contactService.getContacts();

      // Get IDs of people already in this group
      final existingMemberIds = widget.chat.members.map((m) => m.id).toSet();

      setState(() {
        // Only show contacts who are NOT already members
        _availableContacts = allContacts
            .where((c) => !existingMemberIds.contains(c.contact.id))
            .toList();

        _filteredContacts = _availableContacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error loading contacts", isError: true);
    }
  }

  void _runFilter(String query) {
    setState(() {
      _filteredContacts = filterItems<ContactModel>(
        _availableContacts,
        query,
        (contact) => contact.contact.username,
      );
    });
  }

  Future<void> _handleAddMembers() async {
    if (_selectedUserIds.isEmpty) return;

    setState(() => _isSaving = true);

    final success = await context
        .read<ChatService>()
        .addMembersToGroup(widget.chat.id, _selectedUserIds.toList());

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context); // Go back to chat settings/info
        _showSnackBar("Members added successfully!");
      } else {
        _showSnackBar("Failed to add members", isError: true);
      }
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppErrorColor : Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).appBarTheme.foregroundColor),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Add Members",
                style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor, fontSize: 18)),
            Text(widget.chat.name,
                style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor?.withOpacity(0.6), fontSize: 12)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppPrimaryColor))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CustomSearchBar(
                    controller: _searchController,
                    onChanged: _runFilter,
                    hintText: "Search contacts...",
                  ),
                ),
                Expanded(
                  child: _filteredContacts.isEmpty
                      ? _buildNoContactsView()
                      : _buildContactList(),
                ),
                _buildBottomButton(),
              ],
            ),
    );
  }

  Widget _buildNoContactsView() {
    return Center(
      child: Text(
        _searchController.text.isEmpty
            ? "All your contacts are already in this group"
            : "No contacts found",
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),)
      ),
    );
  }

  Widget _buildContactList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredContacts.length,
      itemBuilder: (context, index) {
        final contact = _filteredContacts[index];
        final isSelected = _selectedUserIds.contains(contact.contact.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedUserIds.remove(contact.contact.id);
                } else {
                  _selectedUserIds.add(contact.contact.id);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
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
                  CircleAvatar(
                    backgroundColor: AppPrimaryColor,
                    child: Text(contact.contact.username[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  Text(contact.contact.username,
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Icon(
                    isSelected ? Icons.check_circle : Icons.add_circle_outline,
                    color: isSelected ? AppPrimaryColor : Colors.white24,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ActionButton(
        text: "Add Selected (${_selectedUserIds.length})",
        color: AppPrimaryColor,
        isLoading: _isSaving,
        onPressed: _selectedUserIds.isEmpty ? null : _handleAddMembers,
      ),
    );
  }
}
