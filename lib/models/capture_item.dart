class CaptureItem {
  final String id;
  final String imagePath; // final annotated PNG path
  final String extractedText;
  final DateTime createdAt;

  CaptureItem({
    required this.id,
    required this.imagePath,
    required this.extractedText,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': imagePath,
      'extractedText': extractedText,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory CaptureItem.fromMap(Map<String, dynamic> map) {
    return CaptureItem(
      id: map['id'] as String,
      imagePath: map['imagePath'] as String,
      extractedText: map['extractedText'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}
