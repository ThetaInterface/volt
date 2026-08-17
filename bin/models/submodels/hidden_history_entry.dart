import '../models.dart';

class HiddenHistoryEntry {
    final String id;
    final String summary;
    final List<String> facts;
    final List<String> unawareActorIds;
    
    final Time timestamp;
    final List<String> relatedLocationIds;
    final List<String> relatedActorIds;

    final Map<String, dynamic> flags;

    HiddenHistoryEntry({
        required this.id,
        required this.summary,
        required this.facts,
        required this.unawareActorIds,

        required this.timestamp,
        required this.relatedLocationIds,
        required this.relatedActorIds,

        required this.flags,
    });

    factory HiddenHistoryEntry.fromJson(Map<String, dynamic> json) {
        return HiddenHistoryEntry(
            id: json['id'] as String? ?? '',
            summary: json['summary'] as String? ?? '',
            facts: List<String>.from(json['facts'] ?? []),
            unawareActorIds: List<String>.from(json['unawareActorIds'] ?? []),
            
            timestamp: Time.fromJson(json['timestamp'] as Map<String, dynamic>? ?? {}),
            relatedLocationIds: List<String>.from(json['relatedLocationIds'] ?? []),
            relatedActorIds: List<String>.from(json['relatedActorIds']),

            flags: Map<String, dynamic>.from(json['flags'] ?? {}),
        );
    }

    Map<String, dynamic> toJson() {
        return {
            'id': id,
            'summary': summary,
            'facts': facts,
            'unawareActorIds': unawareActorIds,
            
            'timestamp': timestamp.toJson(),
            'relatedLocationIds': relatedLocationIds,
            'relatedActorIds': relatedActorIds,

            'flags': flags,
        };
    }
}