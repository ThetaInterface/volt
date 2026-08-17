class Location {
    final String id;
    final String name;
    final String description;

    final String status;
    final List<String> connectedLocationIds;
    final Map<String, String> environmentAndItems;
 
    final Map<String, dynamic> flags;

    Location({required this.id, required this.name, required this.description, 
        required this.status, required this.connectedLocationIds, required this.environmentAndItems,
        required this.flags});

    String get locationArea => id.replaceFirst(RegExp(r'loc_'), '').split('_').first;

    void addConnection(String connectionLocationId) {
        if (!connectedLocationIds.contains(connectionLocationId)) {
            connectedLocationIds.add(connectionLocationId);
        }
    }

    void removeConnection(String connectionLocationId) {
        connectedLocationIds.removeWhere((c) => c == connectionLocationId);
    }

    void setFlag(String key, dynamic value) {
        flags[key] = value;
    }

    void removeFlag(String key) {
        flags.remove(key);
    }

    void addEnvironmentOrItem(String key, String value) {
        environmentAndItems.addEntries([MapEntry(key, value)]);
    }

    void removeEnvironmentOrItem(String key) {
        environmentAndItems.remove(key);
    }

    Location modify(String key, dynamic value) {
        return Location.fromJson(
            toJson()
                ..remove(key)
                ..addEntries([
                    MapEntry(key, value)
                ])
        );
    }

    factory Location.fromJson(Map<String, dynamic> json) {
        return Location(
            id: json['id'] as String? ?? '',
            name: json['name'] as String? ?? '',
            description: json['description'] as String? ?? '',
            status: json['status'] as String? ?? '',
            connectedLocationIds: List<String>.from(json['connectedLocationIds'] ?? []),
            environmentAndItems: (json['environmentAndItems'] as Map<String, dynamic>?)
                ?.map((key, value) => MapEntry(key, value as String? ?? '')) ?? {},
            flags: json['flags'] as Map<String, dynamic>? ?? {},
        );
    }

    Map<String, dynamic> toJson() {
        return {
            'id': id,
            'name': name,
            'description': description,
            
            'status': status,
            'connectedLocationIds': connectedLocationIds,
            'environmentAndItems' : environmentAndItems,
            
            'flags': flags
        };
    }
}