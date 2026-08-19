/// A single predicted fruit with its model confidence and image.
class FruitPrediction {
  const FruitPrediction({required this.name, required this.confidence, this.imageUrl});

  final String name;
  final double confidence;
  final String? imageUrl;

  factory FruitPrediction.fromJson(Map<String, dynamic> json) =>
      FruitPrediction(
        name: json['name'] as String,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        imageUrl: json['imageUrl'] as String?,
      );
}

/// The model's backtested accuracy over the wiki history.
class PredictionRating {
  const PredictionRating({
    required this.top1Accuracy,
    required this.top3Accuracy,
    required this.testedRotations,
  });

  final double top1Accuracy;
  final double top3Accuracy;
  final int testedRotations;

  factory PredictionRating.fromJson(Map<String, dynamic> json) =>
      PredictionRating(
        top1Accuracy: (json['top1Accuracy'] as num?)?.toDouble() ?? 0,
        top3Accuracy: (json['top3Accuracy'] as num?)?.toDouble() ?? 0,
        testedRotations: (json['testedRotations'] as num?)?.toInt() ?? 0,
      );
}

/// A UTC rotation slot ranked by historical premium-fruit quality.
class BestSlot {
  const BestSlot({
    required this.hour,
    required this.premiumCount,
    required this.rotations,
    required this.score,
  });

  final int hour;
  final int premiumCount;
  final int rotations;
  final double score;

  factory BestSlot.fromJson(Map<String, dynamic> json) => BestSlot(
        hour: (json['hour'] as num?)?.toInt() ?? 0,
        premiumCount: (json['premiumCount'] as num?)?.toInt() ?? 0,
        rotations: (json['rotations'] as num?)?.toInt() ?? 0,
        score: (json['score'] as num?)?.toDouble() ?? 0,
      );
}

/// Response of GET /stock/predictions.
class PredictionResult {
  const PredictionResult({
    required this.predictions,
    this.nextResetAt,
    this.rating,
    this.bestSlots = const [],
  });

  final List<FruitPrediction> predictions;

  /// When the next rotation is expected, UTC.
  final DateTime? nextResetAt;

  final PredictionRating? rating;

  /// UTC slots ranked best first.
  final List<BestSlot> bestSlots;

  factory PredictionResult.fromJson(Map<String, dynamic> json) =>
      PredictionResult(
        predictions: (json['predictions'] as List<dynamic>? ?? const [])
            .map((p) => FruitPrediction.fromJson(p as Map<String, dynamic>))
            .toList(),
        nextResetAt: json['nextResetAt'] is num
            ? DateTime.fromMillisecondsSinceEpoch(
                (json['nextResetAt'] as num).toInt(),
                isUtc: true,
              )
            : null,
        rating: json['rating'] == null
            ? null
            : PredictionRating.fromJson(json['rating'] as Map<String, dynamic>),
        bestSlots: (json['bestSlots'] as List<dynamic>? ?? const [])
            .map((s) => BestSlot.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}