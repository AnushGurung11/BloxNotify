/// A single tradable item (fruit, gamepass or limited) from game.guide's
/// live value list.
class ValueItem {
  const ValueItem({
    this.id,
    required this.name,
    this.normalValue,
    this.permanentValue,
    this.demand,
    this.trend,
    this.category,
    this.rarity,
    this.fruitType,
    this.imageUrl,
  });

  final int? id;
  final String name;

  /// In-game trade value (null when unknown).
  final num? normalValue;

  /// Trade value of the permanent version of the item, in the same in-game
  /// units as [normalValue] (game.guide's "Perm" column) — null when the
  /// item has none.
  final num? permanentValue;

  final String? demand;
  final String? trend;
  final String? category;
  final String? rarity;
  final String? fruitType;
  final String? imageUrl;

  factory ValueItem.fromJson(Map<String, dynamic> json) => ValueItem(
        id: json['id'] as int?,
        name: json['name'] as String,
        normalValue: json['normalValue'] as num?,
        permanentValue: json['permanentValue'] as num?,
        demand: json['demand'] as String?,
        trend: json['trend'] as String?,
        category: json['category'] as String?,
        rarity: json['rarity'] as String?,
        fruitType: json['fruitType'] as String?,
        imageUrl: json['imageUrl'] as String?,
      );
}

/// Formats a raw value for display: 56.50B, 812.5K, 1.2M or plain
/// comma-grouped numbers.
String formatValue(num? value) {
  if (value == null) return '-';
  if (value >= 1e9) return '${_trim(value / 1e9)}B';
  if (value >= 1e6) return '${_trim(value / 1e6)}M';
  if (value >= 1e3) return '${_trim(value / 1e3)}K';
  return _group(value.toStringAsFixed(0));
}

String _trim(double n) {
  final text = n.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _group(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final fromEnd = digits.length - i;
    if (i > 0 && fromEnd % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}