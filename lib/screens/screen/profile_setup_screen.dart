import 'dart:convert';
import 'dart:io';

import 'package:Bloomee/theme_data/default.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  File? _avatarFile;
  bool _saving = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _avatarFile = File(result.files.single.path!);
      });
    }
  }

  Future<String?> _uploadToImgBB(File file) async {
    // NOTE: For production, do not hardcode keys in client apps. The user requested direct use.
    const imgbbKey = '15d66c3fa337b4736e001f9230b6509c';
    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);
    final uri = Uri.parse('https://api.imgbb.com/1/upload?key=$imgbbKey');
    final resp = await http.post(uri, body: {
      'image': base64Image,
    });
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['data']?['url'] ?? data['data']?['display_url']) as String?;
      }
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        _showSnack('Not authenticated.');
        return;
      }

      String? avatarUrl;
      if (_avatarFile != null) {
        avatarUrl = await _uploadToImgBB(_avatarFile!);
        if (avatarUrl == null) {
          _showSnack('Upload failed. Please try another image.');
          return;
        }
      }

      final payload = {
        'id': user.id,
        'username': _usernameCtrl.text.trim(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Upsert into a 'profiles' table (create this in Supabase with id uuid PK)
      await supabase.from('profiles').upsert(payload);

      if (mounted) {
        _showSnack('Profile saved');
        context.go('/Explore');
      }
    } on PostgrestException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Unexpected error.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: Default_Theme.secondoryTextStyle,
        ),
        backgroundColor: Default_Theme.accentColor2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      appBar: AppBar(
        backgroundColor: Default_Theme.themeColor,
        title: Text(
          'Profile Setup',
          style: Default_Theme.primaryTextStyle.merge(
            const TextStyle(color: Default_Theme.primaryColor1),
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Default_Theme.themeColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Default_Theme.primaryColor2.withOpacity(0.2),
                            backgroundImage: _avatarFile != null ? FileImage(_avatarFile!) : null,
                            child: _avatarFile == null
                                ? const Icon(
                                    Icons.person,
                                    size: 48,
                                    color: Default_Theme.primaryColor1,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Material(
                              color: Default_Theme.accentColor2,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _saving ? null : _pickAvatar,
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: Default_Theme.primaryColor2,
                                  ),
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _usernameCtrl,
                      style: Default_Theme.secondoryTextStyle.merge(
                        const TextStyle(color: Default_Theme.primaryColor1),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: Default_Theme.secondoryTextStyle,
                        filled: true,
                        fillColor: Default_Theme.themeColor.withOpacity(0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Default_Theme.primaryColor2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Default_Theme.primaryColor2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Default_Theme.accentColor2, width: 2),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Username required';
                        if (v.trim().length < 3) return 'Min 3 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Default_Theme.accentColor2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _saving ? null : _saveProfile,
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.8,
                                  valueColor: AlwaysStoppedAnimation<Color>(Default_Theme.primaryColor2),
                                ),
                              )
                            : Text(
                                'Save Profile',
                                style: Default_Theme.primaryTextStyle.merge(
                                  const TextStyle(
                                    color: Default_Theme.primaryColor2,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
