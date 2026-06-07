class ClassRoom {
  const ClassRoom({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int memberCount;
  final DateTime createdAt;

  factory ClassRoom.fromJson(Map<String, dynamic> json) {
    return ClassRoom(
      id: json['id'] as String,
      name: json['name'] as String,
      memberCount: (json['member_count'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
