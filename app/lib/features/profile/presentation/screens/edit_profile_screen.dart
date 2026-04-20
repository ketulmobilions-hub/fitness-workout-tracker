import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/profile_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Issue #8: controllers are initialized eagerly so dispose() is always safe.
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _avatarController;

  bool _profileLoaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _avatarController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            displayName: _nameController.text.trim(),
            avatarUrl: _avatarController.text.trim().isEmpty
                ? null
                : _avatarController.text.trim(),
            bio: _bioController.text.trim().isEmpty
                ? null
                : _bioController.text.trim(),
          );
      // Issue #10: no ref.invalidate here — updateProfile already upserts to
      // Drift, which causes the keepAlive watchProfile stream to emit the new
      // row automatically. Invalidating would cause a spurious loading flash.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Issue #8: watching the stream causes build() to re-run when data arrives.
    // We fill the controllers on the first build where profile data is present,
    // guarded by _profileLoaded so user edits are not overwritten by later emits.
    final profile = ref.watch(profileStreamProvider).value;
    if (!_profileLoaded && profile != null) {
      _nameController.text = profile.displayName ?? '';
      _bioController.text = profile.bio ?? '';
      _avatarController.text = profile.avatarUrl ?? '';
      _profileLoaded = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'How should we call you?',
              ),
              maxLength: 50,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Display name is required';
                }
                // Issue #9: enforce minimum 2 chars (was an unreachable
                // duplicate isEmpty check before).
                if (v.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell us about yourself (optional)',
              ),
              maxLength: 500,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _avatarController,
              decoration: const InputDecoration(
                labelText: 'Avatar URL',
                hintText: 'https://example.com/avatar.jpg (optional)',
              ),
              keyboardType: TextInputType.url,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final uri = Uri.tryParse(v.trim());
                if (uri == null || !uri.hasScheme || uri.scheme != 'https') {
                  return 'Must be a valid HTTPS URL';
                }
                if (v.trim().length > 2048) return 'URL is too long';
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
