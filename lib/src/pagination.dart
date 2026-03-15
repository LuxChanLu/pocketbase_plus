/// A paginated result wrapper that includes pagination metadata.
///
/// This class wraps a list of items with pagination information
/// returned by PocketBase's getList method.
class PaginatedResult<T> {
  /// The list of items on the current page.
  final List<T> items;

  /// The current page number (1-indexed).
  final int page;

  /// The number of items per page.
  final int perPage;

  /// The total number of items across all pages.
  final int totalItems;

  /// The total number of pages.
  final int totalPages;

  const PaginatedResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
  });

  /// Returns true if there is a next page.
  bool get hasNextPage => page < totalPages;

  /// Returns true if there is a previous page.
  bool get hasPrevPage => page > 1;

  /// Returns true if this is the first page.
  bool get isFirstPage => page == 1;

  /// Returns true if this is the last page.
  bool get isLastPage => page == totalPages;

  /// Returns true if the result is empty.
  bool get isEmpty => items.isEmpty;

  /// Returns true if the result is not empty.
  bool get isNotEmpty => items.isNotEmpty;

  /// Returns the number of items on this page.
  int get length => items.length;

  @override
  String toString() {
    return 'PaginatedResult<${T.toString()}>('
        'items: ${items.length}, '
        'page: $page/$totalPages, '
        'totalItems: $totalItems)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PaginatedResult<T>) return false;
    return page == other.page &&
        perPage == other.perPage &&
        totalItems == other.totalItems &&
        totalPages == other.totalPages &&
        _listEquals(items, other.items);
  }

  @override
  int get hashCode => Object.hash(page, perPage, totalItems, totalPages, items);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
