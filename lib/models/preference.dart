class Preference {
  final String id;
  final String name; // e.g., Beaches, Nature, History, Adventure, Food
  final String iconName;
  final bool isSelected;

  Preference({
    required this.id,
    required this.name,
    required this.iconName,
    this.isSelected = false,
  });

  Preference copyWith({
    String? id,
    String? name,
    String? iconName,
    bool? isSelected,
  }) {
    return Preference(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'iconName': iconName,
    'isSelected': isSelected,
  };

  factory Preference.fromJson(Map<String, dynamic> json) => Preference(
    id: json['id'],
    name: json['name'],
    iconName: json['iconName'],
    isSelected: json['isSelected'] ?? false,
  );
}