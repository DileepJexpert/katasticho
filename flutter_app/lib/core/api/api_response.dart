/// Maps the standard backend ApiResponse<T> wrapper.
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final Map<String, dynamic>? errors;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.errors,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse(
      success: json['success'] as bool? ?? false,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      message: json['message'] as String?,
      errors: json['errors'] as Map<String, dynamic>?,
    );
  }

  bool get hasError => !success || errors != null;
}

/// Pagination wrapper for list responses.
class PagedResponse<T> {
  final List<T> content;
  final int totalElements;
  final int totalPages;
  final int currentPage;
  final int pageSize;
  final bool hasNext;

  PagedResponse({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
    required this.hasNext,
  });

  factory PagedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final contentList = (json['content'] as List<dynamic>?)
            ?.map((e) => fromJsonT(e as Map<String, dynamic>))
            .toList() ??
        [];

    return PagedResponse(
      content: contentList,
      totalElements: json['totalElements'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      currentPage: json['number'] as int? ?? 0,
      pageSize: json['size'] as int? ?? 20,
      hasNext: !(json['last'] as bool? ?? true),
    );
  }
}
