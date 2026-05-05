class CursorPagination {
  const CursorPagination({
    required this.limit,
    required this.hasMore,
    this.nextCursor,
  });

  final int limit;
  final bool hasMore;
  final String? nextCursor;

  factory CursorPagination.fromMap(Map<String, dynamic> map) {
    return CursorPagination(
      limit: map['limit'] is num ? (map['limit'] as num).toInt() : 20,
      hasMore: map['hasMore'] == true || map['has_more'] == true,
      nextCursor:
          map['nextCursor']?.toString() ?? map['next_cursor']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'limit': limit, 'hasMore': hasMore, 'nextCursor': nextCursor};
  }
}
