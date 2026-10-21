import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:stylebite/core/utils/api_helper.dart';
import 'package:stylebite/core/utils/config.dart';
import 'package:stylebite/core/utils/local_storage.dart';

import '../models/memory_item_model.dart';

class MemoriesController extends GetxController {
  final memories = <Memories>[].obs;
  final isLoading = false.obs;
  final hasError = false.obs;
  final isMoreLoading = false.obs;

  final RxString currentFilter = 'all'.obs;
  final isSubmitting = false.obs;
  final RxnInt selectedMemoryId = RxnInt();
  final years = <String>[].obs;

  int _currentPage = 1;
  int _lastPage = 1;

  @override
  void onInit() {
    super.onInit();
    getMemories(isRefresh: true);
    
    // Auto-refresh data when filter changes (for server-side filtering)
    ever(currentFilter, (_) => refreshMemories());
  }

  Future<void> getMemories({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 1;
      isLoading.value = true;
    } else {
      if (isMoreLoading.value || _currentPage >= _lastPage) return;
      isMoreLoading.value = true;
    }

    try {
      hasError.value = false;
      
      // Construct API URL with date_filter if needed
      String endpoint = "memories?page=$_currentPage&per_page=10";
      if (currentFilter.value == 'last_week' || currentFilter.value == 'last_month') {
        endpoint += "&date_filter=${currentFilter.value}";
      }

      final response = await ApiHelper.fetchDataWithAuthorization(endpoint);

      if (response != null && response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final model = MemoriesModel.fromJson(responseData);

        if (isRefresh) {
          memories.assignAll(model.memories ?? []);
        } else {
          memories.addAll(model.memories ?? []);
        }

        _currentPage = model.pagination?.currentPage ?? _currentPage;
        _lastPage = model.pagination?.lastPage ?? 1;

        _updateYears();

        if (memories.isNotEmpty && isRefresh) {
          selectedMemoryId.value = memories.first.id;
        }
      } else {
        if (isRefresh) hasError.value = true;
      }
    } catch (e) {
      if (isRefresh) hasError.value = true;
    } finally {
      isLoading.value = false;
      isMoreLoading.value = false;
    }
  }

  void _updateYears() {
    final Set<String> yearSet = {};
    for (var memory in memories) {
      if (memory.memoryDate != null) {
        final match = RegExp(r'\d{4}').firstMatch(memory.memoryDate!);
        if (match != null) {
          yearSet.add(match.group(0)!);
        }
      }
    }
    final sortedYears = yearSet.toList()..sort((a, b) => b.compareTo(a));
    years.assignAll(sortedYears);
  }

  void loadMore() {
    if (_currentPage < _lastPage && !isMoreLoading.value) {
      _currentPage++;
      getMemories(isRefresh: false);
    }
  }

  void refreshMemories() => getMemories(isRefresh: true);

  List<Memories> get filteredMemories {
    // Local filtering for 'favorites' and 'years', 
    // while 'last_week'/'last_month' are now handled by API
    if (currentFilter.value == 'all' || 
        currentFilter.value == 'last_week' || 
        currentFilter.value == 'last_month') {
      return memories;
    }
    
    if (currentFilter.value == 'favorites') {
      return memories.where((item) => item.isFavorite ?? false).toList();
    }
    
    // For year filters
    return memories
        .where((item) => (item.memoryDate ?? '').contains(currentFilter.value))
        .toList();
  }

  Memories? get selectedMemory {
    final matches = filteredMemories.where(
      (m) => m.id == selectedMemoryId.value,
    );
    if (matches.isNotEmpty) {
      return matches.first;
    }
    return filteredMemories.isNotEmpty ? filteredMemories.first : null;
  }

  void setFilter(String filter) {
    currentFilter.value = filter;
  }

  void selectMemory(int? memoryId) {
    selectedMemoryId.value = memoryId;
  }

  Future<void> toggleFavorite(int? id) async {
    if (id == null) return;
    final index = memories.indexWhere((m) => m.id == id);
    if (index != -1) {
      final memory = memories[index];
      final bool originalStatus = memory.isFavorite ?? false;

      memory.isFavorite = !originalStatus;
      memories[index] = memory;
      memories.refresh();

      try {
        final response = await ApiHelper.postRequestWithAuthorization(
          "memories/$id/favorite",
        );
        if (response == null || response.statusCode != 200) {
          memory.isFavorite = originalStatus;
          memories[index] = memory;
          memories.refresh();
        }
      } catch (e) {
        memory.isFavorite = originalStatus;
        memories[index] = memory;
        memories.refresh();
      }
    }
  }

  Future<bool> deleteMemory(int id) async {
    try {
      final response = await ApiHelper.deleteRequestWithAuthorization(
        "memories/$id",
      );
      if (response != null && response.statusCode == 200) {
        memories.removeWhere((m) => m.id == id);
        if (selectedMemoryId.value == id) {
          selectedMemoryId.value = memories.isNotEmpty ? memories.first.id : null;
        }
        memories.refresh();
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  Future<bool> saveMemory({
    int? id,
    required Map<String, String> data,
    required List<XFile> images,
    List<int> deletedImageIds = const [],
  }) async {
    isSubmitting.value = true;
    try {
      final token = LocalStorage.getAccessKey();
      final normalizedBase = kcBaseAPIUrl.endsWith('/')
          ? kcBaseAPIUrl.substring(0, kcBaseAPIUrl.length - 1)
          : kcBaseAPIUrl;

      final url = Uri.parse("$normalizedBase/memories${id != null ? '/$id' : ''}");
      final request = http.MultipartRequest('POST', url);

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (id != null) request.fields['_method'] = 'PUT';
      request.fields.addAll(data);

      if (deletedImageIds.isNotEmpty) {
        for (var i = 0; i < deletedImageIds.length; i++) {
          request.fields['deleted_image_ids[$i]'] = deletedImageIds[i].toString();
        }
      }

      for (var image in images) {
        request.files.add(await http.MultipartFile.fromPath('images[]', image.path));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        refreshMemories();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }
}
