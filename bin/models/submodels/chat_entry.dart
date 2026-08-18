import 'package:mistralai_client_dart/mistralai_client_dart.dart' hide Role;

import '../models.dart';

class ChatEntry {
    final int id;
    final Role role;
    final String content;

    ChatEntry({this.id = 0, required this.role, required this.content});

    dynamic toMistralChatEntry() {
        switch (role) {
            case Role.system:
                return SystemMessage(content: Content.string(content));
            case Role.user:
                return UserMessage(content: UserMessageContent.string(content));
            case Role.assistant:
                return AssistantMessage(content: AssistantMessageContent.string(content));
        }
    }

    Map<String, dynamic> toCustomProviderChatEntry() {
        return {
            'role': role.toString(),
            'content': content
        };
    }

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