class Category {
  String id;
  String name;
  int order; // Add this field

  Category({required this.id, required this.name, required this.order});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'order': order};
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(id: map['id'], name: map['name'], order: map['order'] ?? 0);
  }
}
