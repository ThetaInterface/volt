import 'models.dart';
import '../utils/utils.dart';

class Actor {
    final String id;
    final String name;
    final String type;
    final String locationId;
    final String position;

    final String bio;
    final List<String> traits;

    final Map<String, dynamic> status;
    final Map<String, int> relationships;
    final List<String> memories;
    final List<String> knowledge;
    final Needs needs;

    final Time birthTime;
    final Time? deathTime;

    final List<String> inventory;
    final Map<String, dynamic> flags;

    Actor({required this.id, required this.name, required this.type, required this.locationId, required this.position,
        required this.bio, required this.traits,
        required this.status, required this.relationships, required this.needs, 
        required this.memories, required this.knowledge, required this.deathTime, required this.birthTime,
        required this.inventory, required this.flags});


    void setRelationship(String targetId, int value) {
        relationships.remove(targetId);

        relationships.addEntries([MapEntry(targetId, value)]);
    }

    void changeRelationship(String targetId, int delta) {
        relationships[targetId] = (relationships[targetId] ?? 0) + delta;
    }

    void setStatus(String key, dynamic value) {
        if (key == 'age') {
            return;
        }

        removeStatus(key);

        status.addEntries([MapEntry(key, value)]);
    }

    void removeStatus(String key) {
        status.remove(key);
    }

    void addMemoryEntry(String content) {
        if (!memories.contains(content)) {
            if (memories.length > Global.currentConfig.getValueOrDefault(ConfigProperty.actorMemorySize)) {
                memories.removeAt(0);
            }

            memories.add(content);
        }
    }

    void removeMemoryEntry(String textContains) {
        memories.remove(memories.firstWhere((e) => e.contains(textContains)));
    }

    void addKnowledgeEntry(String content) {
        if (!knowledge.contains(content)) {
            if (knowledge.length > Global.currentConfig.getValueOrDefault(ConfigProperty.actorKnowledgeSize)) {
                knowledge.removeAt(0);
            }

            knowledge.add(content);
        }
    }

    void removeKnowledgeEntry(String textContains) {
        knowledge.remove(knowledge.firstWhere((e) => e.contains(textContains)));
    }

    void addInventoryItem(String itemName) {
        inventory.add(itemName);
    }

    void removeInventoryItem(String itemName) {
        inventory.remove(itemName);
    }

    void setFlag(String key, dynamic value) {
        flags[key] = value;
    }

    void removeFlag(String key) {
        flags.remove(key);
    }

    Actor modify(String key, dynamic value) {
        return Actor.fromJson(toJson()
            ..remove(key)
            ..addEntries([
                MapEntry(key, value)
            ])
        );
    } 

    factory Actor.fromJson(Map<String, dynamic> json) {
        return Actor(
            id: json['id'] as String? ?? '',
            name: json['name'] as String? ?? '',
            type: json['type'] as String? ?? '',
            locationId: json['locationId'] as String? ?? '',
            position: json['position'] as String? ?? '',
            
            bio: json['bio'] as String? ?? '',
            traits: List<String>.from(json['traits'] ?? []),

            status: Map<String, dynamic>.from(json['status'] ?? {}),
            relationships: (json['relationships'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as int? ?? 0)) ?? {},
            needs: Needs.fromJson(json['needs'] as Map<String, dynamic>? ?? {}),
            memories: List<String>.from(json['memories'] ?? []),
            knowledge: List<String>.from(json['knowledge'] ?? []),
            
            birthTime: Time.fromJson(json['birthTime'] as Map<String, dynamic>? ?? {}),
            deathTime: json['deathTime'] != null ? 
                Time.fromJson(json['deathTime'] as Map<String, dynamic>? ?? {})
                : null,

            inventory: List<String>.from(json['inventory'] ?? []),
            flags: Map<String, dynamic>.from(json['flags'] ?? {})
        );
    }

    Map<String, dynamic> toJson() {
        return {
            'id': id,
            'name': name,
            'type': type,
            'locationId': locationId,
            'position': position,

            'bio': bio,
            'traits': traits,

            'status': status,
            'relationships': relationships,
            'needs': needs.toJson(),
            'memories': memories,
            'knowledge': knowledge,
            
            'birthTime': birthTime.toJson(),
            'deathTime': deathTime?.toJson(),

            'inventory': inventory,
            'flags': flags
        };
    }
}