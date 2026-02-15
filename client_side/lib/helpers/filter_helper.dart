List<T> filterItems<T>(
    List<T> allItems, String query, String Function(T) getName) {
  // If search is empty return everything
  if (query.isEmpty) {
    return allItems;
  }

  return allItems.where((item) {
    // Get the name using the function you pass in
    final name = getName(item).toLowerCase();
    final search = query.toLowerCase();

    // Check if it starts with the search text
    return name.startsWith(search);
  }).toList();
}
