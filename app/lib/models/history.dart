/// A single fruit in a stock history event.
class StockHistoryItem {
  const StockHistoryItem({
    required this.name,
    this.imageUrl,
    this.price,
    this.robux,
  });

  final String name;

  /// Absolute image URL from the source site (bloxvalues), may be null.
  final String? imageUrl;

  /// Beli price at that rotation (null when unknown).
  final num? price;

  final num? robux;

  bool get isFree => (price ?? 0) <= 0;

  factory StockHistoryItem.fromJson(Map<String, dynamic> json) =>
      StockHistoryItem(
        name: json['name'] as String,
        imageUrl: json['imageUrl'] as String?,
        price: json['price'] as num?,
        robux: json['robux'] as num?,
      );
}

/// One stock rotation event: a Normal or Mirage dealer restock.
class StockHistoryEvent {
  const StockHistoryEvent({
    required this.type,
    required this.timestamp,
    required this.time,
    this.items = const [],
  });

  /// 'Normal' or 'Mirage'.
  final String type;

  /// Unix seconds (UTC).
  final int timestamp;

  /// The rotation moment, UTC.
  final DateTime time;

  final List<StockHistoryItem> items;

  bool get isMirage => type == 'Mirage';

  factory StockHistoryEvent.fromJson(Map<String, dynamic> json) {
    final timestamp = (json['timestamp'] as num?)?.toInt() ?? 0;
    return StockHistoryEvent(
      type: json['type'] as String? ?? 'Normal',
      timestamp: timestamp,
      time: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000,
          isUtc: true),
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((i) => StockHistoryItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Response of GET /stock/history.
class StockHistory {
  const StockHistory({required this.events, this.source, this.updatedAt});

  /// Rotation events, newest first.
  final List<StockHistoryEvent> events;

  /// 'bloxvalues' or 'local'.
  final String? source;

  /// When the history was last updated (epoch milliseconds).
  final DateTime? updatedAt;

  factory StockHistory.fromJson(Map<String, dynamic> json) => StockHistory(
        events: (json['events'] as List<dynamic>? ?? const [])
            .map((e) => StockHistoryEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        source: json['source'] as String?,
        updatedAt: json['updatedAt'] is num
            ? DateTime.fromMillisecondsSinceEpoch(
                (json['updatedAt'] as num).toInt(),
                isUtc: true,
              )
            : null,
      );
}

/// Formats a Beli price like the reference site: `$2,700,000` or `Free`.
String formatBeli(num? price) {
  if (price == null) return '';
  if (price <= 0) return 'Free';
  return '\$${_group(price.toStringAsFixed(0))}';
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
