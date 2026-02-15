import 'package:flutter/material.dart';
import 'package:namer_app/models/contact.dart';
import 'package:namer_app/services/contact_provider.dart';
import 'package:namer_app/theme/app_colors.dart';
import 'package:provider/provider.dart';

typedef RequestId = String;

/// Screen responsible for handling incoming contact requests.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final Set<RequestId> _processingIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ContactProvider>();
      provider.fetchPendingRequests();
      provider.fetchSentRequests();
    });
  }

  // Processing helpers

  void _setProcessing(RequestId id, bool processing) {
    setState(() {
      if (processing) {
        _processingIds.add(id);
      } else {
        _processingIds.remove(id);
      }
    });
  }

  bool _isProcessing(RequestId id) {
    return _processingIds.contains(id);
  }

  // Action handlers

  Future<void> _handleAccept(
    ContactProvider provider,
    ContactModel request,
  ) async {
    _setProcessing(request.id, true);
    try {
      await provider.acceptRequest(request);
      if (mounted) {
        _showSnackBar('Request accepted!');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('Failed to accept', isError: true);
      }
    } finally {
      if (mounted) {
        _setProcessing(request.id, false);
      }
    }
  }

  Future<void> _handleReject(
    ContactProvider provider,
    ContactModel request,
  ) async {
    _setProcessing(request.id, true);
    try {
      await provider.rejectRequest(request);
      if (mounted) {
        _showSnackBar('Request declined');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('Failed to reject', isError: true);
      }
    } finally {
      if (mounted) {
        _setProcessing(request.id, false);
      }
    }
  }

  Future<void> _handleCancelRequest(
    ContactProvider provider,
    ContactModel request,
  ) async {
    _setProcessing(request.id, true);
    try {
      await provider.cancelSentRequest(request);
      if (mounted) {
        _showSnackBar('Request cancelled');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('Failed to cancel request', isError: true);
      }
    } finally {
      if (mounted) {
        _setProcessing(request.id, false);
      }
    }
  }

  // UI helpers
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppErrorColor : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Build profile picture widget
  Widget _buildProfilePicture(ContactModel request) {
    final hasProfilePicture = request.contact.hasProfilePicture;
    final username = request.contact.username;

    if (hasProfilePicture) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(request.contact.profilePicture!),
        backgroundColor: Colors.grey[300],
        onBackgroundImageError: (_, __) {
          // Fallback handled by errorBuilder in child
        },
        child: null,
      );
    } else {
      return CircleAvatar(
        radius: 24,
        backgroundColor: AppPrimaryColor,
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  // Build
  @override
  Widget build(BuildContext context) {
    final contactProvider = context.watch<ContactProvider>();
    final List<ContactModel> receivedRequests = contactProvider.pendingRequests;
    final List<ContactModel> sentRequests = contactProvider.sentRequests;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Contact Requests',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            labelColor: AppPrimaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppPrimaryColor,
            tabs: [
              Tab(
                  text:
                      'Received ${receivedRequests.isNotEmpty ? "(${receivedRequests.length})" : ""}'),
              Tab(text: 'Sent'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              // RECEIVED TAB
              RefreshIndicator(
                onRefresh: () => contactProvider.fetchPendingRequests(),
                child: receivedRequests.isEmpty
                    ? _buildEmptyState("No pending requests", "New requests will show up here")
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: receivedRequests.length,
                        itemBuilder: (context, index) {
                          final request = receivedRequests[index];
                          return _buildReceivedRequestTile(
                            contactProvider,
                            request,
                          );
                        },
                      ),
              ),

              // SENT TAB
              RefreshIndicator(
                onRefresh: () => contactProvider.fetchSentRequests(),
                child: sentRequests.isEmpty
                    ? _buildEmptyState("No sent requests", "Requests you send will appear here")
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: sentRequests.length,
                        itemBuilder: (context, index) {
                          final request = sentRequests[index];
                          return _buildSentRequestTile(
                            contactProvider,
                            request,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceivedRequestTile(
    ContactProvider provider,
    ContactModel request,
  ) {
    final bool isProcessing = _isProcessing(request.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPrimaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildProfilePicture(request),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.contact.resolvedName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (request.contact.displayName != null &&
                        request.contact.displayName!.isNotEmpty)
                      Text(
                        '@${request.contact.username}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    Text(
                      request.contact.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _handleAccept(
                            provider,
                            request,
                          ),
                  icon: isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _handleReject(
                            provider,
                            request,
                          ),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppErrorColor,
                    side: const BorderSide(color: AppErrorColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentRequestTile(
    ContactProvider provider,
    ContactModel request,
  ) {
    final bool isProcessing = _isProcessing(request.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildProfilePicture(request),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.contact.resolvedName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Sent request',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
               if (isProcessing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.grey),
                  onPressed: () => _handleCancelRequest(provider, request), 
                  tooltip: "Cancel Request",
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mark_email_read_outlined,
            size: 80,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleMedium?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

//Extensions

extension RequestsScreenExtensions on RequestsScreen {
  /// Screen identifier (useful for analytics/logging)
  String get screenName => 'RequestsScreen';
}
