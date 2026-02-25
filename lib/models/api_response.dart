/// 统一 API 响应模型
class ApiResponse<T> {
  final int code;
  final String msg;
  final T? data;
  final int timestamp;

  ApiResponse({
    required this.code,
    required this.msg,
    this.data,
    this.timestamp = 0,
  });

  bool get isSuccess => code == 0;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromData,
  ) {
    return ApiResponse<T>(
      code: json['code'] ?? -1,
      msg: json['msg'] ?? '',
      data: json['data'] != null && fromData != null
          ? fromData(json['data'])
          : json['data'] as T?,
      timestamp: json['timestamp'] ?? 0,
    );
  }
}

/// 分页数据
class PageData<T> {
  final List<T> list;
  final int page;
  final int pageSize;
  final int total;
  final int? lastPage;

  PageData({
    required this.list,
    required this.page,
    required this.pageSize,
    required this.total,
    this.lastPage,
  });

  bool get hasMore => page < (lastPage ?? (total / pageSize).ceil());

  factory PageData.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromItem,
  ) {
    final rawList = json['list'] as List? ?? [];
    return PageData<T>(
      list: rawList.map((e) => fromItem(e as Map<String, dynamic>)).toList(),
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? 20,
      total: json['total'] ?? 0,
      lastPage: json['last_page'],
    );
  }
}
