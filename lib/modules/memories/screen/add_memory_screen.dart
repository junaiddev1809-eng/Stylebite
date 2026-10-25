import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/config.dart';
import '../controllers/memories_controller.dart';
import '../models/memory_item_model.dart';

class AddMemoryScreen extends StatefulWidget {
  final Memories? memory;
  const AddMemoryScreen({super.key, this.memory});

  @override
  State<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends State<AddMemoryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final MemoriesController _controller;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _shortTitleController = TextEditingController();
  final TextEditingController _shortDescController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  final List<XFile> _selectedImages = [];
  List<Images> _existingImages = [];
  final List<int> _deletedImageIds = [];
  final ImagePicker _picker = ImagePicker();

  List<dynamic> _locationSuggestions = [];
  Timer? _debounce;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<MemoriesController>();
    _existingImages = widget.memory?.images != null
        ? List.from(widget.memory!.images!)
        : [];
    if (widget.memory != null) {
      _titleController.text = widget.memory!.title ?? '';
      _shortTitleController.text = widget.memory!.shortTitle ?? '';
      _shortDescController.text = widget.memory!.shortDescription ?? '';
      _descController.text = widget.memory!.description ?? '';
      _dateController.text = widget.memory!.memoryDate ?? '';
      _locationController.text = widget.memory!.location ?? '';
      _cityController.text = widget.memory!.city ?? '';
      _countryController.text = widget.memory!.country ?? '';
      _latController.text = widget.memory!.lat?.toString() ?? '';
      _lngController.text = widget.memory!.lng?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        errorSnackBar(message: 'Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          errorSnackBar(message: 'Location permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        errorSnackBar(message: 'Location permissions are permanently denied.');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Keep memory location names in English even if the phone is Urdu.
      await setLocaleIdentifier('en_US');
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Construct a more readable location name
        String locationName = [
          place.name,
          place.subLocality,
          place.locality,
        ].where((e) => e != null && e.isNotEmpty).join(', ');

        setState(() {
          _locationController.text = locationName;
          _cityController.text = place.locality ?? '';
          _countryController.text = place.country ?? '';
          _latController.text = position.latitude.toString();
          _lngController.text = position.longitude.toString();
        });
      } else {
        errorSnackBar(message: 'Could not resolve address for this location.');
      }
    } catch (e) {
      errorSnackBar(message: 'Failed to get current location.');
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _fetchSuggestions(String input) async {
    if (input.trim().isEmpty) {
      setState(() => _locationSuggestions = []);
      return;
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {'input': input, 'key': googleMapsApiKey},
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() => _locationSuggestions = data['predictions'] ?? []);
        } else {
          debugPrint(
            "Places Autocomplete Error: ${data['status']} - ${data['error_message'] ?? ''}",
          );
          setState(() => _locationSuggestions = []);
        }
      } else {
        setState(() => _locationSuggestions = []);
      }
    } catch (e) {
      debugPrint("Suggestions Exception: $e");
      setState(() => _locationSuggestions = []);
    }
  }

  Future<void> _getPlaceDetails(String placeId) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {'place_id': placeId, 'key': googleMapsApiKey},
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] != 'OK') {
          debugPrint("Place Details Error: ${responseData['status']}");
          return;
        }

        final data = responseData['result'];
        final lat = data['geometry']['location']['lat'];
        final lng = data['geometry']['location']['lng'];

        String city = '';
        String country = '';
        final components = data['address_components'] as List;
        for (var c in components) {
          final types = c['types'] as List;
          // City can sometimes be in locality or administrative_area_level_2
          if (types.contains('locality') ||
              types.contains('administrative_area_level_2')) {
            city = c['long_name'];
          }
          if (types.contains('country')) country = c['long_name'];
        }

        setState(() {
          _locationController.text = data['name'] ?? data['formatted_address'];
          _cityController.text = city;
          _countryController.text = country;
          _latController.text = lat.toString();
          _lngController.text = lng.toString();
          _locationSuggestions = [];
        });
      }
    } catch (e) {}
  }

  void _showDeleteConfirmation(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            AppHeroIconData(
              Icons.delete_forever_rounded,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Delete Memory?',
              style: AppFonts.plusJakarta(size: 24, weight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'This will permanently remove this style moment. Are you sure?',
              textAlign: TextAlign.center,
              style: AppFonts.beVietnam(
                size: 15,
                color: AppColors.hintText,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: AppBackNavigation.handleBack,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppFonts.beVietnam(
                        size: 16,
                        weight: FontWeight.w700,
                        color: AppColors.hintText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        AppBackNavigation.handleBack();
                        final success = await _controller.deleteMemory(
                          widget.memory!.id!,
                        );
                        if (success) {
                          AppBackNavigation.handleBack(); // Return to memories list
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Delete',
                        style: AppFonts.beVietnam(
                          size: 16,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.memory != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          isEdit ? 'Edit Memory' : 'New Memory',
          style: AppFonts.plusJakarta(size: 18, weight: FontWeight.w800),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        actions: [
          if (isEdit)
            IconButton(
              onPressed: () => _showDeleteConfirmation(context),
              icon: const AppHeroIconData(Icons.delete_outline_rounded, color: Colors.red),
            ),
        ],
      ),
      body: Obx(
        () => Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Horizontal Image Picker
                    SizedBox(
                      height: 140,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final imgs = await _picker.pickMultiImage();
                              if (imgs.isNotEmpty)
                                setState(() => _selectedImages.addAll(imgs));
                            },
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                  width: 2,
                                ),
                              ),
                              child: const AppHeroIconData(
                                Icons.add_photo_alternate_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          ..._existingImages.map(
                            (img) => _imagePreview(
                              img.fileUrl ?? '',
                              isNetwork: true,
                              onRemove: () {
                                setState(() {
                                  _deletedImageIds.add(img.id!);
                                  _existingImages.removeWhere(
                                    (item) => item.id == img.id,
                                  );
                                });
                              },
                            ),
                          ),
                          ..._selectedImages.map(
                            (img) => _imagePreview(
                              img.path,
                              isNetwork: false,
                              onRemove: () =>
                                  setState(() => _selectedImages.remove(img)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      _titleController,
                      'Full Title',
                      Icons.title_rounded,
                    ),
                    _buildTextField(
                      _shortTitleController,
                      'Short Title',
                      Icons.short_text_rounded,
                    ),
                    _buildTextField(
                      _dateController,
                      'Memory Date',
                      Icons.calendar_today_rounded,
                      readOnly: true,
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null)
                          setState(
                            () => _dateController.text = picked
                                .toString()
                                .split(' ')[0],
                          );
                      },
                    ),
                    _buildTextField(
                      _shortDescController,
                      'Short Description',
                      Icons.notes_rounded,
                    ),
                    _buildTextField(
                      _descController,
                      'Full Description',
                      Icons.description_rounded,
                      maxLines: 3,
                    ),
                    Column(
                      children: [
                        _buildTextField(
                          _locationController,
                          'Location',
                          Icons.place_rounded,
                          onChanged: (val) {
                            if (_debounce?.isActive ?? false)
                              _debounce!.cancel();
                            _debounce = Timer(
                              const Duration(milliseconds: 600),
                              () {
                                _fetchSuggestions(val);
                              },
                            );
                          },
                          suffixIcon: IconButton(
                            onPressed: _isLocating ? null : _getCurrentLocation,
                            icon: _isLocating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : const AppHeroIconData(
                                    Icons.my_location_rounded,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                          ),
                        ),
                        if (_locationSuggestions.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _locationSuggestions.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                              itemBuilder: (context, index) {
                                final s = _locationSuggestions[index];
                                return ListTile(
                                  title: Text(
                                    s['description'],
                                    style: AppFonts.beVietnam(size: 13),
                                  ),
                                  onTap: () => _getPlaceDetails(s['place_id']),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _cityController,
                            'City',
                            Icons.location_city_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            _countryController,
                            'Country',
                            Icons.public_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;
                          final success = await _controller.saveMemory(
                            id: widget.memory?.id,
                            data: {
                              'title': _titleController.text,
                              'short_title': _shortTitleController.text,
                              'short_description': _shortDescController.text,
                              'description': _descController.text,
                              'memory_date': _dateController.text,
                              'location': _locationController.text,
                              'city': _cityController.text,
                              'country': _countryController.text,
                              'lat': _latController.text,
                              'lng': _lngController.text,
                            },
                            images: _selectedImages,
                            deletedImageIds: _deletedImageIds,
                          );
                          if (success) {
                            AppBackNavigation.handleBack();
                            Get.snackbar(
                              'Success',
                              'Memory ${isEdit ? 'updated' : 'created'} successfully',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.green.withValues(
                                alpha: 0.1,
                              ),
                              colorText: Colors.green[800],
                            );
                          } else {
                            Get.snackbar(
                              'Error',
                              'Failed to save memory. Please check your connection and try again.',
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        child: Text(
                          isEdit ? 'Update Memory' : 'Create Memory',
                          style: AppFonts.plusJakarta(
                            size: 16,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_controller.isSubmitting.value)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        style: AppFonts.beVietnam(
          size: 15,
          weight: FontWeight.w600,
          color: AppColors.text,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppFonts.beVietnam(size: 13, color: AppColors.hintText),
          prefixIcon: AppHeroIconData(icon, size: 22, color: AppColors.primary),
          filled: true,
          suffixIcon: suffixIcon,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _imagePreview(
    String path, {
    required bool isNetwork,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        Container(
          width: 100,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            image: DecorationImage(
              image: isNetwork
                  ? NetworkImage(path) as ImageProvider
                  : FileImage(File(path)),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 18,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: const AppHeroIconData(
                Icons.close_rounded,
                size: 16,
                color: Colors.redAccent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
