import '../models.dart';

class ChatEntry {
    final int id;
    final Role role;
    final String content;

    ChatEntry({required this.id, required this.role, required this.content});

    factory ChatEntry.fromJson(Map<String, dynamic> json) {
        return ChatEntry(
            id: json['id'] as int,
            role: Role.from(json['role']), 
            content: json['content'] as String
        );
    }

    Map<String, dynamic> toJson() {
        return {
            'id': id,
            'role': role.toString(),
            'content': content
        };
    }
} 