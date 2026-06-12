import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/loading_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _mobileController;
  late TextEditingController _dobController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  late TextEditingController _aadharController;
  late TextEditingController _panController;

  /// True when the user registered/logged in via phone — phone is their
  /// primary login credential so we show it read-only.
  bool _phoneIsReadOnly = false;

  /// Locally-picked & cropped avatar, shown immediately while it uploads.
  File? _pickedAvatar;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _mobileController = TextEditingController(text: user?.phone ?? '');
    _dobController = TextEditingController(text: user?.dateOfBirth ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _cityController = TextEditingController(text: user?.city ?? '');
    _stateController = TextEditingController(text: user?.state ?? '');
    _pincodeController = TextEditingController(text: user?.pincode ?? '');
    _aadharController = TextEditingController(text: user?.aadharNumber ?? '');
    _panController = TextEditingController(text: user?.panNumber ?? '');

    // If the user already has a phone number, mark it read-only — it is their
    // login credential and shouldn't be silently overwritten from the profile form.
    _phoneIsReadOnly = (user?.phone.isNotEmpty == true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _aadharController.dispose();
    _panController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final profileProvider = context.read<ProfileProvider>();
    final success = await profileProvider.updateProfile(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneIsReadOnly ? null : _mobileController.text.trim(),
      dateOfBirth: _dobController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      pincode: _pincodeController.text.trim(),
      aadharNumber: _aadharController.text.trim(),
      panNumber: _panController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      await context.read<AuthProvider>().fetchUserProfile();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(profileProvider.error ?? 'Failed to update profile'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  // ── Profile picture: pick → adjust circular crop size → upload ────────────
  Future<void> _changeProfilePicture() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 14, bottom: 4),
              child: Text(
                'Update profile picture',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppTheme.primaryColor),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppTheme.primaryColor),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (picked == null || !mounted) return;

    // Circular crop UI — the user can drag the corners to resize the
    // circle (the crop area) before confirming.
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust profile picture',
          toolbarColor: AppTheme.primaryColor,
          statusBarColor: AppTheme.primaryColor,
          toolbarWidgetColor: Colors.white,
          cropStyle: CropStyle.circle,
          initAspectRatio: CropAspectRatioPreset.square,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
          lockAspectRatio: true,
          hideBottomControls: false,
          showCropGrid: false,
        ),
        IOSUiSettings(
          title: 'Adjust profile picture',
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
          aspectRatioPickerButtonHidden: true,
          resetAspectRatioEnabled: false,
          resetButtonHidden: true,
        ),
      ],
    );
    if (cropped == null || !mounted) return;

    final file = File(cropped.path);
    setState(() {
      _pickedAvatar = file;
      _isUploadingAvatar = true;
    });

    final profileProvider = context.read<ProfileProvider>();
    final success = await profileProvider.uploadAvatar(file.path);

    if (!mounted) return;
    setState(() => _isUploadingAvatar = false);

    if (success) {
      // Clear cached image so profile page always shows the new avatar
      await CachedNetworkImage.evictFromCache(
        context.read<AuthProvider>().user?.avatarUrl ?? '',
      );
      await context.read<AuthProvider>().fetchUserProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      setState(() => _pickedAvatar = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(profileProvider.error ?? 'Failed to update profile picture'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Widget _buildAvatarPicker() {
    final user = context.watch<AuthProvider>().user;
    final initials = (user?.fullName.isNotEmpty == true)
        ? user!.fullName.trim()[0].toUpperCase()
        : '?';

    ImageProvider? imageProvider;
    if (_pickedAvatar != null) {
      imageProvider = FileImage(_pickedAvatar!);
    } else if ((user?.avatarUrl ?? '').isNotEmpty) {
      imageProvider = NetworkImage(user!.avatarUrl!);
    }

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : null,
          ),
          if (_isUploadingAvatar)
            const Positioned.fill(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: Colors.black38,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: -2,
            right: -2,
            child: GestureDetector(
              onTap: _isUploadingAvatar ? null : _changeProfilePicture,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt,
                    size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatarPicker(),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Tap the camera icon to update your photo',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader('Personal Information'),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _nameController,
                label: 'Full Name',
                prefixIcon: Icons.person_outline,
                validator: Validators.validateName,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _emailController,
                label: 'Email Address',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                validator: Validators.validateEmail,
              ),
              const SizedBox(height: 16),

              // ── Mobile number ────────────────────────────────────────────────
              if (_phoneIsReadOnly)
                // Already linked — show as display-only with a badge
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          color: Color(0xFF9CA3AF), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mobile Number',
                              style: TextStyle(
                                
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _mobileController.text,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF374151),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Login Number',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF065F46),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                CustomTextField(
                  controller: _mobileController,
                  label: 'Mobile Number',
                  hint: '10-digit mobile number',
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  validator: (val) {
                    if (val == null || val.isEmpty) return null; // optional
                    if (!RegExp(r'^\d{10}$').hasMatch(val)) {
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _dobController,
                label: 'Date of Birth',
                hint: 'DD/MM/YYYY',
                prefixIcon: Icons.cake_outlined,
              ),

              const SizedBox(height: 24),
              _SectionHeader('Address'),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _addressController,
                label: 'Address',
                maxLines: 2,
                prefixIcon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _cityController,
                      label: 'City',
                      prefixIcon: Icons.location_city_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _stateController,
                      label: 'State',
                      prefixIcon: Icons.map_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _pincodeController,
                label: 'Pincode',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.pin_drop_outlined,
              ),

              const SizedBox(height: 24),
              _SectionHeader('KYC Documents'),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _aadharController,
                label: 'Aadhar Number',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.badge_outlined,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _panController,
                label: 'PAN Number',
                prefixIcon: Icons.credit_card_outlined,
              ),

              const SizedBox(height: 32),

              Consumer<ProfileProvider>(
                builder: (context, provider, _) {
                  return LoadingButton(
                    isLoading: provider.isUpdating,
                    onPressed: _saveProfile,
                    label: 'Save Changes',
                  );
                },
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
      ),
    );
  }
}
