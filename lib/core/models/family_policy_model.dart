class FamilyPolicyModel {
  final String title;
  final String description;

  FamilyPolicyModel({required this.title, required this.description});

  factory FamilyPolicyModel.fromMap(Map<String, dynamic> map) {
    return FamilyPolicyModel(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
    };
  }
}
