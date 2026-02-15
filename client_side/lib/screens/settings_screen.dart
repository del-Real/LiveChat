import 'package:flutter/material.dart';
import 'package:namer_app/services/contact_provider.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/user.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? _currentUser;
  final TextEditingController _nameController = TextEditingController();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await AuthService().getUser();
    if (user != null) {
      setState(() {
        _currentUser = user;
        _nameController.text = user.displayName ?? "";
      });
    }
  }

  Future<void> _updateProfilePic() async {
    final picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (mounted) setState(() => _isUpdating = true);

      final chatService = context.read<ChatService>();

      final imageUrl = await chatService.uploadImage(pickedFile);

      if (imageUrl != null) {
        _saveProfile(imageUrl: imageUrl);
      } else {
        if (mounted) {
          setState(() => _isUpdating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Upload failed. Verify server is running.")),
          );
        }
      }
    }
  }

  Future<void> _saveProfile({String? imageUrl}) async {
    if (mounted) setState(() => _isUpdating = true);

    final chatService = context.read<ChatService>();

    final updatedUser = await chatService.updateProfile(
      displayName: _nameController.text.trim(),
      profilePicture: imageUrl ?? _currentUser?.profilePicture,
    );

    if (mounted) {
      setState(() => _isUpdating = false);
      if (updatedUser != null) {
        setState(() => _currentUser = updatedUser);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayedName = _currentUser?.displayName != null &&
            _currentUser!.displayName!.trim().isNotEmpty
        ? _currentUser!.displayName!
        : _currentUser?.username ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.settings),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Profile & Settings',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: AppPrimaryColor,
                  backgroundImage: (_currentUser?.profilePicture != null &&
                          _currentUser!.profilePicture!.isNotEmpty)
                      ? NetworkImage(_currentUser!.profilePicture!)
                      : null,
                  child: (_currentUser?.profilePicture == null ||
                          _currentUser!.profilePicture!.isEmpty)
                      ? const Icon(Icons.person, size: 60, color: Colors.white)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: AppPrimaryColor,
                    radius: 20,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 20),
                      onPressed: _updateProfilePic,
                    ),
                  ),
                ),
                if (_isUpdating)
                  const Positioned.fill(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: Column(
              children: [
                Text(
                  displayedName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${_currentUser?.username ?? 'username'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          TextField(
            enabled: false,
            decoration: InputDecoration(
              labelText: 'Username',
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              hintText: _currentUser?.username ?? '',
              prefixIcon: const Icon(Icons.alternate_email),
              suffixIcon: Icon(
                Icons.lock,
                size: 18,
                color: Colors.grey[600],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
                ),
              ),
              filled: true,
              fillColor: isDark ? Colors.grey[850] : Colors.grey[200],
            ),
            controller:
                TextEditingController(text: _currentUser?.username ?? ''),
          ),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  Icons.lock,
                  size: 12,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'Username cannot be changed',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Display Name (Optional)',
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
              hintText: _currentUser?.displayName?.isEmpty ?? true
                  ? 'Same as username if left empty'
                  : 'How you appear in chats',
              prefixIcon: const Icon(Icons.badge_outlined),
              suffixIcon: _nameController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        setState(() {
                          _nameController.clear();
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: AppPrimaryColor,
                  width: 2,
                ),
              ),
            ),
            onChanged: (value) {
              setState(() {}); // Rebuild to show/hide clear button
            },
          ),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _nameController.text.trim().isEmpty
                  ? 'Others will see "@${_currentUser?.username ?? 'username'}"'
                  : 'Others will see "${_nameController.text.trim()}"',
              style: TextStyle(
                fontSize: 12,
                color: AppPrimaryColor.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Save Button
          ElevatedButton(
            onPressed: _isUpdating ? null : () => _saveProfile(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPrimaryColor,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _isUpdating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),

          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'PREFERENCES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Dark Mode Toggle
          Selector<ThemeProvider, bool>(
            selector: (_, provider) => provider.isDarkMode,
            builder: (context, isDark, _) {
              return SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: Text(
                  isDark ? 'Dark theme enabled' : 'Light theme enabled',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                secondary: Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                ),
                value: isDark,
                onChanged: (val) => context.read<ThemeProvider>().toggleTheme(val),
                activeThumbColor: AppPrimaryColor,
              );
            },
          ),

          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'ACCOUNT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(
              _currentUser?.email ?? 'Not available',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log Out'),
            subtitle: const Text(
              'Sign out of your account',
              style: TextStyle(fontSize: 12),
            ),
            textColor: Theme.of(context).colorScheme.error,
            iconColor: Theme.of(context).colorScheme.error,
            onTap: () async {
              // Show confirmation dialog
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Log Out'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Log Out',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (shouldLogout == true) {
                // Logout sequence
                context.read<ChatService>().logout();
                context.read<ContactProvider>().logout();
                await AuthService().clearUserData();

                if (mounted) {
                  context.go('/login');
                }
              }
            },
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
