/// Custom exception for when a user is not registered for a specific category
class CategoryNotRegisteredException implements Exception {
  final String message;
  final String categoryName;
  final String categoryId;

  CategoryNotRegisteredException(
    this.message,
    this.categoryName,
    this.categoryId,
  );

  @override
  String toString() => message;
}
