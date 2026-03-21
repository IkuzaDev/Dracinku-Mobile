class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResponse({required this.success, this.data, this.error});

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      success: json['success'] ?? false,
      data: json['data'],
      error: json['error'] is String
          ? json['error']
          : (json['error']?['message'] ?? 'Unknown error'),
    );
  }

  factory ApiResponse.error(String message) {
    return ApiResponse(success: false, error: message);
  }
}
