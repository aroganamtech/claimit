import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/error_handler.dart';
import '../models/feedback_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FeedbackService — talks to POST /feedback, GET /feedback/my on the main
// backend. No manual user_id fallback needed (unlike BillService) — this is
// the same backend the app already authenticates against, so ApiClient's
// existing Bearer-token interceptor is sufficient.
// ─────────────────────────────────────────────────────────────────────────────

class FeedbackService {
  FeedbackService._();
  static final instance = FeedbackService._();

  final _client = ApiClient();

  /// Submit new feedback/complaint/suggestion.
  Future<FeedbackModel> submitFeedback({
    required String category, // feedback | complaint | suggestion
    required String subject,
    required String message,
  }) async {
    final response = await _client.post(
      AppConstants.submitFeedback,
      data: {
        'category': category,
        'subject': subject,
        'message': message,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return FeedbackModel.fromJson(response.data as Map<String, dynamic>);
    }
    AppError.friendly(Exception('Feedback submit HTTP ${response.statusCode}'), '', context: 'FeedbackSubmit');
    throw Exception('Unable to submit your feedback. Please try again.');
  }

  /// Fetch the current user's own past submissions (with any admin reply).
  Future<List<FeedbackModel>> fetchMyFeedback() async {
    final response = await _client.get(AppConstants.myFeedback);
    if (response.statusCode == 200) {
      return (response.data as List)
          .cast<Map<String, dynamic>>()
          .map(FeedbackModel.fromJson)
          .toList();
    }
    AppError.friendly(Exception('Feedback fetch HTTP ${response.statusCode}'), '', context: 'FeedbackFetch');
    throw Exception('Unable to load your feedback. Please try again.');
  }
}
