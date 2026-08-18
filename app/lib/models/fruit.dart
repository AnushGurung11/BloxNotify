/// A single fruit in the current stock.
class Fruit {
  const Fruit({required this.name, this.imageUrl});

  final String name;
  final String? imageUrl;

  factory Fruit.fromJson(Map<String, dynamic> json) => Fruit(
        name: json['name'] as String,
        imageUrl: json['imageUrl'] as String?,
      );
}

/// A past stock snapshot from the backend's history.
class StockHistoryEntry {
  const StockHistoryEntry({required this.fruits, this.updatedAt});

  final List<String> fruits;
  final DateTime? updatedAt;

  factory StockHistoryEntry.fromJson(Map<String, dynamic> json) =>
      StockHistoryEntry(
        fruits: (json['fruits'] as List<dynamic>? ?? const [])
            .map((f) => f as String)
            .toList(),
        updatedAt: json['updatedAt'] is String
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
      );
}

/// Snapshot of the stock served by GET /stock.
class StockSnapshot {
  const StockSnapshot({
    required this.fruits,
    this.updatedAt,
    this.history = const [],
  });

  final List<Fruit> fruits;
  final DateTime? updatedAt;

  /// Previous stock snapshots, newest first.
  final List<StockHistoryEntry> history;

  bool get isEmpty => fruits.isEmpty;

  factory StockSnapshot.fromJson(Map<String, dynamic> json) => StockSnapshot(
        fruits: (json['fruits'] as List<dynamic>? ?? const [])
            .map((f) => Fruit.fromJson(f as Map<String, dynamic>))
            .toList(),
        updatedAt: json['updatedAt'] is String
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
        history: (json['history'] as List<dynamic>? ?? const [])
            .map((h) => StockHistoryEntry.fromJson(h as Map<String, dynamic>))
            .toList(),
      );
}