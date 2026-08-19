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
  const StockHistoryEntry({
    required this.fruits,
    this.mirageFruits = const [],
    this.updatedAt,
  });

  final List<String> fruits;
  final List<String> mirageFruits;
  final DateTime? updatedAt;

  bool get isEmpty => fruits.isEmpty && mirageFruits.isEmpty;

  factory StockHistoryEntry.fromJson(Map<String, dynamic> json) =>
      StockHistoryEntry(
        fruits: (json['fruits'] as List<dynamic>? ?? const [])
            .map((f) => f as String)
            .toList(),
        mirageFruits: (json['mirageFruits'] as List<dynamic>? ?? const [])
            .map((f) => f as String)
            .toList(),
        updatedAt: json['updatedAt'] is String
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
      );
}

/// One dealer's stock: fruit list plus when it was recorded and when the
/// next rotation is expected.
class DealerStock {
  const DealerStock({required this.fruits, this.updatedAt, this.nextResetAt});

  final List<Fruit> fruits;
  final DateTime? updatedAt;

  /// Epoch-millisecond time of the next stock rotation, UTC.
  final DateTime? nextResetAt;

  bool get isEmpty => fruits.isEmpty;

  factory DealerStock.fromJson(Map<String, dynamic> json) => DealerStock(
        fruits: (json['fruits'] as List<dynamic>? ?? const [])
            .map((f) => Fruit.fromJson(f as Map<String, dynamic>))
            .toList(),
        updatedAt: json['updatedAt'] is String
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
        nextResetAt: json['nextResetAt'] is num
            ? DateTime.fromMillisecondsSinceEpoch(
                (json['nextResetAt'] as num).toInt(),
                isUtc: true,
              )
            : null,
      );
}

/// Snapshot of the stock served by GET /stock.
class StockSnapshot {
  const StockSnapshot({
    required this.normal,
    required this.mirage,
    this.history = const [],
  });

  final DealerStock normal;
  final DealerStock mirage;

  /// Previous stock snapshots, newest first.
  final List<StockHistoryEntry> history;

  bool get isEmpty => normal.isEmpty && mirage.isEmpty;

  /// Parses the current backend shape; also tolerates the legacy shape
  /// (`fruits` at the top level) for older backends.
  factory StockSnapshot.fromJson(Map<String, dynamic> json) {
    final normal = json['normal'] is Map<String, dynamic>
        ? DealerStock.fromJson(json['normal'] as Map<String, dynamic>)
        : DealerStock(
            fruits: (json['fruits'] as List<dynamic>? ?? const [])
                .map((f) => Fruit.fromJson(f as Map<String, dynamic>))
                .toList(),
            updatedAt: json['updatedAt'] is String
                ? DateTime.tryParse(json['updatedAt'] as String)
                : null,
          );
    final mirage = json['mirage'] is Map<String, dynamic>
        ? DealerStock.fromJson(json['mirage'] as Map<String, dynamic>)
        : const DealerStock(fruits: []);
    return StockSnapshot(
      normal: normal,
      mirage: mirage,
      history: (json['history'] as List<dynamic>? ?? const [])
          .map((h) => StockHistoryEntry.fromJson(h as Map<String, dynamic>))
          .toList(),
    );
  }
}