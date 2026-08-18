/// A single predicted fruit with its model confidence.
class FruitPrediction {
  const FruitPrediction({required this.name, required this.confidence});

  final String name;
  final double confidence;

  factory FruitPrediction.fromJson(Map<String, dynamic> json) =>
      FruitPrediction(
        name: json['name'] as String,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
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

/// Response of GET /stock/predictions.
class PredictionResult {
  const PredictionResult({
    required this.predictions,
    this.nextResetAt,
    this.rating,
  });

  final List<FruitPrediction> predictions;

  /// When the next rotation is expected, UTC.
  final DateTime? nextResetAt;

  final PredictionRating? rating;

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
      );
}