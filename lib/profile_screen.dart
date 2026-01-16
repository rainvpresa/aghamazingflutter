import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';

/// ProfileScreen
/// - Top-left custom back button (image asset)
/// - Circular profile avatar chosen from a local "avatar pool" (assets)
/// - Name field (editable) saved to SharedPreferences
/// - Email field (read-only) with a "Change" button that opens a dialog requiring password
/// - Reset password button (UI-only; backend TODO)
/// - Logout button + confirmation modal -> on confirm navigate to LoginScreen and remove all routes
class ProfileScreen extends StatefulWidget {
const ProfileScreen({Key? key}) : super(key: key);

static const _bg = 'assets/images/backgrounds/profile_screen.png';

// Replace with your back button asset
static const backButtonAsset = 'assets/images/pngs/back-btn.png';

@override
State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
final TextEditingController _nameController = TextEditingController();
final TextEditingController _emailController = TextEditingController();

// selected avatar asset path
String? _profileAvatarPath;
bool _loading = true;

// Local avatar pool — ensure these asset files exist and are declared in pubspec.yaml
static const List<String> _avatarPool = [
'assets/avatars/avatar1.png',
'assets/avatars/avatar2.png',
'assets/avatars/avatar3.png',
'assets/avatars/avatar4.png',
'assets/avatars/avatar5.png',
];

@override
void initState() {
super.initState();
_loadProfileFromPrefs();
}

Future<void> _loadProfileFromPrefs() async {
setState(() => _loading = true);
final prefs = await SharedPreferences.getInstance();
_nameController.text = prefs.getString('profile_name') ?? '';
_emailController.text = prefs.getString('profile_email') ?? '';
_profileAvatarPath = prefs.getString('profile_avatar_path');
setState(() => _loading = false);
}

Future<void> _saveNameToPrefs() async {
final prefs = await SharedPreferences.getInstance();
await prefs.setString('profile_name', _nameController.text.trim());
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Name saved')),
);
}

Future<void> _saveEmailToPrefs(String email) async {
final prefs = await SharedPreferences.getInstance();
await prefs.setString('profile_email', email.trim());
setState(() => _emailController.text = email.trim());
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Email updated locally')),
);

// TODO: call backend/auth API to change the user's email (reauth with password, verification, etc.)
}

Future<void> _saveProfileAvatarPath(String assetPath) async {
final prefs = await SharedPreferences.getInstance();
await prefs.setString('profile_avatar_path', assetPath);
setState(() => _profileAvatarPath = assetPath);
}

// Opens sheet to choose an avatar from the local pool
Future<void> _showAvatarSelectionSheet() async {
await showModalBottomSheet<void>(
context: context,
isScrollControlled: false,
builder: (ctx) {
return SafeArea(
child: Padding(
padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
const SizedBox(height: 8),
Container(
width: 40,
height: 4,
decoration: BoxDecoration(
color: Colors.grey.shade300,
borderRadius: BorderRadius.circular(4),
),
),
const SizedBox(height: 12),
const Text(
'Choose profile picture',
style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
),
const SizedBox(height: 12),
SizedBox(
height: 220,
child: GridView.builder(
itemCount: _avatarPool.length,
padding: const EdgeInsets.symmetric(vertical: 6),
gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
crossAxisCount: 4,
crossAxisSpacing: 12,
mainAxisSpacing: 12,
childAspectRatio: 1,
),
itemBuilder: (context, index) {
final asset = _avatarPool[index];
final selected = asset == _profileAvatarPath;
return GestureDetector(
onTap: () async {
Navigator.of(ctx).pop();
await _saveProfileAvatarPath(asset);
},
child: Stack(
alignment: Alignment.center,
children: [
CircleAvatar(
backgroundImage: AssetImage(asset),
radius: 36,
backgroundColor: Colors.grey.shade200,
),
if (selected)
Container(
width: 72,
height: 72,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: Colors.black.withOpacity(0.28),
border: Border.all(color: Colors.white, width: 2),
),
child: const Icon(Icons.check, color: Colors.white),
),
],
),
);
},
),
),
const SizedBox(height: 8),
TextButton(
onPressed: () {
Navigator.of(ctx).pop();
_saveProfileAvatarPath('');
},
child: const Text('Remove / Reset to default'),
),
const SizedBox(height: 8),
],
),
),
);
},
);
}

// Change email dialog — requires password for validation
Future<void> _showEditEmailDialog() async {
final TextEditingController emailCtrl = TextEditingController(text: _emailController.text);
final TextEditingController passwordCtrl = TextEditingController();
final formKey = GlobalKey<FormState>();

await showDialog<void>(
context: context,
builder: (ctx) {
return AlertDialog(
title: const Text('Change email'),
content: Form(
key: formKey,
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
TextFormField(
controller: emailCtrl,
keyboardType: TextInputType.emailAddress,
decoration: const InputDecoration(
labelText: 'New email',
hintText: 'you@example.com',
),
validator: (v) {
if (v == null || v.trim().isEmpty) return 'Enter an email';
if (!v.contains('@')) return 'Enter a valid email';
return null;
},
),
const SizedBox(height: 12),
TextFormField(
controller: passwordCtrl,
obscureText: true,
decoration: const InputDecoration(
labelText: 'Password',
hintText: 'Enter current password',
),
validator: (v) {
if (v == null || v.isEmpty) return 'Enter your password';
if (v.length < 6) return 'Password too short';
return null;
},
),
],
),
),
actions: [
TextButton(
onPressed: () => Navigator.of(ctx).pop(),
child: const Text('Cancel'),
),
ElevatedButton(
onPressed: () async {
if (!formKey.currentState!.validate()) {
return;
}
final newEmail = emailCtrl.text.trim();
final password = passwordCtrl.text;
Navigator.of(ctx).pop();

// TODO: call backend to re-authenticate with password and change email.
await _saveEmailToPrefs(newEmail);
},
child: const Text('Save'),
),
],
);
},
);
}

// Reset password modal (UI-only)
Future<void> _showResetPasswordDialog() async {
final TextEditingController emailCtrl = TextEditingController(text: _emailController.text);
final formKey = GlobalKey<FormState>();

await showDialog<void>(
context: context,
builder: (ctx) {
return AlertDialog(
title: const Text('Reset password'),
content: Form(
key: formKey,
child: TextFormField(
controller: emailCtrl,
keyboardType: TextInputType.emailAddress,
decoration: const InputDecoration(
labelText: 'Email to send reset link',
),
validator: (v) {
if (v == null || v.trim().isEmpty) return 'Enter an email';
if (!v.contains('@')) return 'Enter a valid email';
return null;
},
),
),
actions: [
TextButton(
onPressed: () => Navigator.of(ctx).pop(),
child: const Text('Cancel'),
),
ElevatedButton(
onPressed: () async {
if (!formKey.currentState!.validate()) return;
Navigator.of(ctx).pop();

// TODO: call password reset API here
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Password reset link sent (mock)')),
);
},
child: const Text('Send'),
),
],
);
},
);
}

// Logout confirmation modal.
// If user confirms, clear local prefs and navigate to LoginScreen (removing all routes).
// If user cancels, they remain on ProfileScreen.
Future<void> _confirmLogout() async {
final should = await showDialog<bool>(
context: context,
builder: (ctx) {
return AlertDialog(
title: const Text('Logout'),
content: const Text('Are you sure you want to log out?'),
actions: [
TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes')),
],
);
},
);

if (should == true) {
final prefs = await SharedPreferences.getInstance();
await prefs.clear();

// TODO: call session/logout API to invalidate server session

if (!mounted) return;
// Navigate to LoginScreen and remove all previous routes.
Navigator.of(context).pushAndRemoveUntil(
MaterialPageRoute(builder: (_) => const LoginScreen()),
(route) => false,
);
}
// if should is false or null, do nothing and remain on this screen
}

Widget _buildProfileAvatar(double size) {
final placeholder = CircleAvatar(
radius: size / 2,
backgroundColor: Colors.grey.shade200,
child: Icon(
Icons.person,
size: size * 0.5,
color: Colors.grey.shade600,
),
);

Widget avatar;
if (_profileAvatarPath == null || _profileAvatarPath!.isEmpty) {
avatar = placeholder;
} else {
avatar = CircleAvatar(
radius: size / 2,
backgroundImage: AssetImage(_profileAvatarPath!),
backgroundColor: Colors.transparent,
);
}

return GestureDetector(
onTap: _showAvatarSelectionSheet,
child: Stack(
alignment: Alignment.bottomRight,
children: [
avatar,
_editBadge(),
],
),
);
}

Widget _editBadge() {
return Container(
decoration: BoxDecoration(
color: Theme.of(context).colorScheme.primary,
shape: BoxShape.circle,
border: Border.all(color: Colors.white, width: 2),
),
padding: const EdgeInsets.all(6),
child: const Icon(
Icons.edit,
size: 16,
color: Colors.white,
),
);
}

@override
void dispose() {
_nameController.dispose();
_emailController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
const horizontalPadding = 20.0;
final theme = Theme.of(context);

return Scaffold(
appBar: AppBar(
elevation: 0,
backgroundColor: theme.scaffoldBackgroundColor,
leading: GestureDetector(
onTap: () => Navigator.of(context).pop(),
  child: Padding(
    padding: const EdgeInsets.only(left: 8.0), // optional: add left padding if needed
    child: Image.asset(
      ProfileScreen.backButtonAsset,
      height: 100, // 👈 ADJUST THIS TO MAKE IT BIGGER
      fit: BoxFit.cover, // preserves aspect ratio
    ),
  ),
),
title: const Text('Profile'),
centerTitle: true,
),
body: Container(
decoration: BoxDecoration(
image: DecorationImage(
image: AssetImage(ProfileScreen._bg),
fit: BoxFit.cover,
opacity: 1,
),
),
child: _loading
? const Center(child: CircularProgressIndicator())
    : SingleChildScrollView(
padding: const EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.center,
children: [
Container(
width: double.infinity,
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: theme.cardColor,
borderRadius: BorderRadius.circular(12),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(0.04),
blurRadius: 8,
offset: const Offset(0, 2),
),
],
),
child: Column(
children: [
Center(child: _buildProfileAvatar(120)),
const SizedBox(height: 12),
Text(
_nameController.text.isEmpty ? 'Your name' : _nameController.text,
style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
),
const SizedBox(height: 8),
Text(
_emailController.text.isEmpty ? 'your.email@example.com' : _emailController.text,
style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
),
],
),
),

const SizedBox(height: 18),

Align(
alignment: Alignment.centerLeft,
child: Text('Full name', style: theme.textTheme.bodySmall),
),
const SizedBox(height: 6),
TextFormField(
controller: _nameController,
decoration: const InputDecoration(
hintText: 'Your full name',
border: OutlineInputBorder(),
contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
),
),
const SizedBox(height: 14),

Align(
alignment: Alignment.centerLeft,
child: Text('Email', style: theme.textTheme.bodySmall),
),
const SizedBox(height: 6),
Row(
children: [
Expanded(
child: TextFormField(
controller: _emailController,
readOnly: true,
decoration: const InputDecoration(
hintText: 'your.email@example.com',
border: OutlineInputBorder(),
contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
),
),
),
const SizedBox(width: 8),
ElevatedButton.icon(
onPressed: _showEditEmailDialog,
icon: const Icon(Icons.edit, size: 18),
label: const Text('Change'),
),
],
),

const SizedBox(height: 12),

Align(
alignment: Alignment.centerLeft,
child: Text('Security', style: theme.textTheme.bodySmall),
),
const SizedBox(height: 6),
Row(
children: [
Expanded(
child: OutlinedButton(
onPressed: _showResetPasswordDialog,
child: const Padding(
padding: EdgeInsets.symmetric(vertical: 12),
child: Text('Reset password'),
),
),
),
const SizedBox(width: 12),
Expanded(
child: ElevatedButton(
onPressed: () async {
await _saveNameToPrefs();
},
child: const Padding(
padding: EdgeInsets.symmetric(vertical: 12),
child: Text('Save profile'),
),
),
),
],
),

const SizedBox(height: 24),

SizedBox(
width: double.infinity,
child: OutlinedButton(
style: OutlinedButton.styleFrom(
foregroundColor: Colors.red,
side: const BorderSide(color: Colors.red),
padding: const EdgeInsets.symmetric(vertical: 14),
),
onPressed: _confirmLogout,
child: const Text('Logout'),
),
),
],
),
),
),
);
}
}