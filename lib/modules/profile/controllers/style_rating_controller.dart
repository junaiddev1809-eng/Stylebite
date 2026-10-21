import 'dart:convert';
import 'package:get/get.dart';
import '../../../core/utils/api_helper.dart';
import '../models/style_rating_model.dart';

class StyleRatingController extends GetxController {
  StyleRatingController({required this.username});

  final String username;
  final Rxn<StyleRatingModel> ratingData = Rxn<StyleRatingModel>();
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchRatingDistribution();
  }

  Future<void> fetchRatingDistribution() async {
    isLoading.value = true;
    hasError.value = false;
    errorMessage.value = '';

    try {
      final endpoint = 'profiles/$username/ratings-distribution';
      final response = await ApiHelper.fetchDataWithAuthorization(endpoint);

      if (response != null) {
        final payload = jsonDecode(response.body);
        final statusCode = payload['status_code'];

        if (response.statusCode == 200 && statusCode == 1) {
          ratingData.value = StyleRatingModel.fromJson(payload['data'] ?? {});
        } else {
          hasError.value = true;
          errorMessage.value = payload['message'] ?? 'Unable to fetch rating distribution';
        }
      } else {
        hasError.value = true;
        errorMessage.value = 'No response from server';
      }
    } catch (e) {
      hasError.value = true;
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  double getPercentage(int stars) {
    if (ratingData.value == null || ratingData.value!.totalRatings == 0) return 0.0;
    final count = ratingData.value!.distribution[stars] ?? 0;
    return count / ratingData.value!.totalRatings;
  }
}
