/// Builds the fruit image URL from a fruit name using FruityBlox's asset
/// rule: lowercase, spaces to dashes, `.webp`. Not every fruit has an image
/// (e.g. `lightning`), so callers must render an `errorBuilder` fallback.
String fruitImageUrl(String name) {
  final slug = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
  return 'https://fruityblox.com/images/fruits/$slug.webp';
}

/// First letter of the fruit name, used as the fallback avatar.
String fruitInitial(String name) => name.isEmpty ? '?' : name[0].toUpperCase();