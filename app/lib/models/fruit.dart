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

/// Snapshot of the stock served by GET /stock.
class StockSnapshot {
  const StockSnapshot({required this.fruits, this.updatedAt});

  final List<Fruit> fruits;
  final DateTime? updatedAt;

  bool get isEmpty => fruits.isEmpty;

  factory StockSnapshot.fromJson(Map<String, dynamic> json) => StockSnapshot(
        fruits: (json['fruits'] as List<dynamic>? ?? const [])
            .map((f) => Fruit.fromJson(f as Map<String, dynamic>))
            .toList(),
        updatedAt: json['updatedAt'] is String
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
      );
}