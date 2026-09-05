import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import '../../domain/entities/assistant_api_models.dart';
import '../../domain/entities/assistant_message.dart';
import '../../domain/entities/financial_profile.dart';
import '../../domain/repositories/assistant_repository.dart';

/// [AssistantRepository] backed by the FastAPI multi-agent backend.
///
/// Sends a typed [AssistantApiRequest] (message, language code, optional
/// financial_context built from the saved profile) to
/// `POST /v1/assistant/chat` and parses the typed [AssistantApiReply].
/// Every failure is normalized into an [AssistantApiException] carrying a
/// user-safe error kind — raw Dio/backend details never reach the UI.
class ApiAssistantRepository implements AssistantRepository {
  ApiAssistantRepository({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? ApiConfig.baseUrl,
                // The multi-agent pipeline (with LLM fallbacks) can take a
                // while; only connection setup is expected to be quick.
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 90),
              ),
            );

  final Dio _dio;

  /// Human-readable labels for the backend's persona context — matching the
  /// wording of the Financial Profile screen.
  static const Map<Persona, String> _personaLabels = {
    Persona.student: 'Student',
    Persona.salaried: 'Salaried Employee',
    Persona.businessOwner: 'Business Owner',
    Persona.shopOwner: 'Shop Owner',
  };

  static const Map<PrimaryGoal, String> _goalLabels = {
    PrimaryGoal.emergencyFund: 'Emergency Fund',
    PrimaryGoal.saveMore: 'Save More',
    PrimaryGoal.education: 'Education',
    PrimaryGoal.newDevice: 'New Device',
    PrimaryGoal.businessGrowth: 'Business Growth',
    PrimaryGoal.reduceSpending: 'Reduce Spending',
    PrimaryGoal.other: 'Other',
  };

  @override
  Future<AssistantReply> respond(
    String question,
    AssistantContext context, {
    String language = 'en',
  }) async {
    final request = AssistantApiRequest(
      message: question,
      language: language,
      financialContext: _financialContext(context),
    );

    try {
      final response = await _dio.post(
        ApiConfig.assistantChatPath,
        data: request.toJson(),
      );
      final data = response.data;
      if (data is! Map) {
        throw const AssistantApiException(AssistantErrorKind.malformed);
      }
      final apiReply = AssistantApiReply.fromJson(
          data.map((key, value) => MapEntry('$key', value)));
      return AssistantReply(
        intent: AssistantIntent.general,
        params: const {},
        followUps: const [],
        confidence: 1,
        api: apiReply,
      );
    } on AssistantApiException {
      rethrow;
    } on FormatException {
      throw const AssistantApiException(AssistantErrorKind.malformed);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  /// Builds the optional `financial_context` from the profile fields of the
  /// assistant context — only values the user actually saved are included
  /// (an incomplete profile omits keys instead of blocking the request).
  /// `monthly_expenses` uses the key the backend calculators read.
  static Map<String, Object?>? _financialContext(AssistantContext context) {
    final map = <String, Object?>{
      if (context.persona != null) 'persona': _personaLabels[context.persona],
      if (context.profileIncome != null)
        'monthly_income': context.profileIncome,
      if (context.profileExpenses != null)
        'monthly_expenses': context.profileExpenses,
      if (context.profileSavings != null)
        'total_savings': context.profileSavings,
      if (context.primaryGoal != null)
        'primary_goal': _goalLabels[context.primaryGoal],
    };
    return map.isEmpty ? null : map;
  }

  static AssistantApiException _mapDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AssistantApiException(AssistantErrorKind.timeout);
      case DioExceptionType.badCertificate:
      case DioExceptionType.connectionError:
      case DioExceptionType.cancel:
        return const AssistantApiException(AssistantErrorKind.network);
      case DioExceptionType.badResponse:
        return const AssistantApiException(AssistantErrorKind.server);
      case DioExceptionType.unknown:
        // Socket failures and interceptors surface here.
        return const AssistantApiException(AssistantErrorKind.network);
    }
  }
}
