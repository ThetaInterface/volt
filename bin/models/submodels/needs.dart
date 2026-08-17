class Needs {
    final int hunger;
    final int thirst;
    final int exhaustion;

    final int stress;
    final int comfort;
    final int boredom;
    final int loneliness;

    final int hygiene;
    
    final Map<String, int> other;

    Needs({required this.hunger, required this.thirst, required this.exhaustion, 
        required this.stress, required this.comfort, required this.boredom, required this.loneliness,
        required this.hygiene, required this.other}); 

    Needs changeStandard(String need, int value, {bool delta = false}) {
        final old = toJson();

        final change = delta ? (old['need'] as int? ?? 0) + value: value;
        
        return Needs.fromJson(
            old
                ..remove(need)
                ..addEntries([
                    MapEntry(need, change)
                ])
        );
    }

    Needs changeOther(String need, int value, {bool delta = false}) {
        final change = delta ? (other['need'] ?? 0) + value: value;

        final newOther = Map.of(other)
            ..remove(need)
            ..addEntries([MapEntry(need, change)]);

        return Needs.fromJson(
            toJson()
                ..remove('other')
                ..addEntries([MapEntry('other', newOther)])
        );
    }

    factory Needs.fromJson(Map<String, dynamic> json) {
        return Needs(
            hunger: json['hunger'] as int? ?? 0, 
            thirst: json['thirst'] as int? ?? 0, 
            exhaustion: json['exhaustion'] as int? ?? 0, 

            stress: json['stress'] as int? ?? 0, 
            comfort: json['comfort'] as int? ?? 0, 
            boredom: json['boredom'] as int? ?? 0, 
            loneliness: json['loneliness'] as int? ?? 0, 

            hygiene: json['hygiene'] as int? ?? 0, 

            other: (json['other'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, int.tryParse(v.toString()) ?? 0)) ?? {}
        );
    }

    Map<String, dynamic> toJson() {
        return {
            'hunger': hunger,
            'thirst': thirst,
            'exhaustion': exhaustion,

            'stress': stress,
            'comfort': comfort,
            'boredom': boredom,
            'loneliness': loneliness,

            'hygiene': hygiene,

            'other': other
        };
    }
}