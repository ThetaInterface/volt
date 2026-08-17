import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:mistralai_client_dart/mistralai_client_dart.dart' hide Role;

import 'models.dart';
import '../data.dart' as data;
import '../utils/utils.dart';

class World {
    final String id;
    final String name;

    Time _currentTime;
    final String settingSummary;

    final List<Location> locations;
    final List<Actor> actors;

    final List<String> history;
    final List<String> currentEvents;
    final List<String> currentRumors;
    final List<HiddenHistoryEntry> hiddenHistory;

    final List<ChatEntry> messageHistory;
    final Map<String, dynamic> globalFlags;

    String? _currentNarration;
    
    Time get currentTime => _currentTime;

    World({
        required this.id,
        required this.name,
        required this._currentTime,
        required this.settingSummary,
        required this.locations,
        required this.actors,
        required this.history,
        required this.currentEvents,
        required this.currentRumors,
        required this.hiddenHistory,
        required this.messageHistory,
        required this.globalFlags,
    });

    String get savePath => path.join(Global.savesDirectoryPath, '$id.json');

    static Future<World?> worldGenerationRemote({
        required String mistralApiKey,
        required String settingSummary,
    }) async {
        final client = MistralAIClient(apiKey: mistralApiKey);

        try {
            stdout.clearScreen();
            print(await Global.currentLocale.getEntry('client.newWorldGenerationStart'));

            final response = await client.chatComplete(
                request: ChatCompletionRequest(
                model: 'mistral-large-latest',
                messages: [
                    SystemMessage(
                        content: Content.string(data.worldGenerationSystemPrompt()),
                    ),
                    UserMessage(
                        content: UserMessageContent.string(data.worldGenerationUserPrompt(settingSummary)),
                    ),
                ],
                temperature: 0.7,
                responseFormat: const ResponseFormat(
                        type: ResponseFormats.jsonObject,
                    ),
                ),
            );

            print(await Global.currentLocale.getEntry('client.newWorldGenerationFinish'));

            final rawJson = response.choices?.first.message.content?.value.toString();

            if (rawJson == null) {
                Logger.createLog('No response from mistral ai while world generation', LogType.warning);

                return null;
            }

            final world = World.fromJson(jsonDecode(rawJson));

            return world;
        } catch (e) {
            Logger.createLog(
                'Unexpected error while generating world with mistral ai -> $e',
                LogType.warning,
            );

            return null;
        }
    }

    String validate() {
        StringBuffer report = StringBuffer();

        try {
            for (final location in locations) {
                for (final connectedLocationId in location.connectedLocationIds) {
                    final connectedLocations = locations.where(
                        (l) => l.id == connectedLocationId,
                );

                if (connectedLocations.firstOrNull == null) {
                    // if location exist check
                    report.writeln('Location with id \'${location.id}\' connected to \'$connectedLocationId\' but it was not found!');
                } else if (connectedLocations.length > 1) {
                    // if location id is unique check
                    report.writeln('Multiple instances of location with id \'$connectedLocationId\' were found!');
                } else {
                    if (!connectedLocations.first.connectedLocationIds.contains(location.id)) {
                    // bidirectional connections check
                        report.writeln('Location with id \'${location.id}\' connected to \'$connectedLocationId\' but \'$connectedLocationId\' not connected to \'${location.id}\'!');
                    }
                }
                }

                if (location.connectedLocationIds.contains(location.id)) {
                // location self-connection check
                    report.writeln('Location with id \'${location.id}\' connects to itself!');
                }
            }

            for (final actor in actors) {
                for (final relationship in actor.relationships.entries) {
                    // relationship actor exist check
                    if (actors.where((a) => a.id == relationship.key).isEmpty) {
                        report.writeln(
                        'Actor with id\'${actor.id}\' has relationship with unkown actor \'${relationship.key}\'!',
                        );
                    }
                    }

                    if (locations.where((l) => l.id == actor.locationId).isEmpty) {
                    // if location exist check
                    report.writeln(
                        'Actor with id \'${actor.id}\' currenty in location with id \'${actor.locationId}\' that doesn\'t exist!',
                    );
                    }

                    if (!actor.status.containsKey('age')) {
                    // age field exist check
                    report.writeln(
                        'Actor with id \'${actor.id}\' have not \'age\' field it his status!',
                    );
                }
            }
        } catch (e) {
            Logger.createLog('World validation failed -> $e', LogType.warning);
        }

        return report.toString();
    }

    String getCurrentNarration() {
        final copy = _currentNarration ?? '';

        _currentNarration = null;

        return copy;
    }

    void addMessageToHistory({required Role role, required String content}) {
        if (messageHistory.length > Global.currentConfig.getValueOrDefault(ConfigProperty.messageHistorySize)) {
            messageHistory.removeAt(0);
        }

        final nextId = messageHistory.isEmpty ? 0 : messageHistory.last.id + 1;

        messageHistory.add(ChatEntry(id: nextId, role: role, content: content));
    }

    void addHistoryEntry(String content) {
        if (history.length > Global.currentConfig.getValueOrDefault(ConfigProperty.worldHistorySize)) {
            history.removeAt(0);
        }

        history.add(content);
    }

    void removeHistoryEntry(String textContains) {
        history.remove(history.firstWhere((e) => e.contains(textContains)));
    }

    void addEventEntry(String content) {
        if (currentEvents.length > Global.currentConfig.getValueOrDefault(ConfigProperty.worldEventsSize)) {
            currentEvents.removeAt(0);
        }

        currentEvents.add(content);
    }

    void removeEventEntry(String textContains) {
        currentEvents.remove(currentEvents.firstWhere((e) => e.contains(textContains)));
    }

    void addRumorEntry(String content) {
        if (currentRumors.length > Global.currentConfig.getValueOrDefault(ConfigProperty.worldRumorsSize)) {
            currentRumors.removeAt(0);
        }

        currentRumors.add(content);
    }

    void removeRumorEntry(String textContains) {
        currentRumors.remove(currentRumors.firstWhere((e) => e.contains(textContains)));
    }

    Actor get playerActor => actors.firstWhere((a) => a.status.containsValue("player"));

    bool locationExist(String locationId) {
        return locations.any((a) => a.id == locationId);
    }

    Location getLocationById(String locationId) {
        return locations.firstWhere((l) => l.id == locationId);
    }

    List<Location> getConnectedLocations(String locationId) {
        final ids = getLocationById(locationId).connectedLocationIds;

        return ids.map((i) => getLocationById(i)).toList();
    }

    List<Location> getLocationsInAreaByOtherLocation(Location location) {
        return locations
            .where((l) => l.locationArea == location.locationArea && l.id != location.id)
            .toList();
    }

    bool actorExist(String actorId) {
        return actors.any((a) => a.id == actorId);
    }

    Actor getActorById(String actorId) {
        return actors.firstWhere((a) => a.id == actorId);
    }

    List<Actor> getActorsByLocationId(String locationId, {String playerId = ''}) {
        return actors
            .where((a) => a.locationId == locationId && a.id != playerId)
            .toList();
    }

    List<Actor> getActorsInArea(String areaId, {String playerId = ''}) {
        return actors
            .where((a) => a.locationId.contains(areaId) && a.id != playerId)
            .toList();
    }

    void modifyActorIfExist(
        String actorId, {
        required String key,
        required dynamic value,
    }) {
        if (actorExist(actorId)) {
            final actorToModify = getActorById(actorId);

            actors[actors.indexOf(actorToModify)] = actorToModify.modify(key, value);
        }
    }

    void modifyLocationIfExist(
        String locationId, {
        required String key,
        required dynamic value,
    }) {
        if (locationExist(locationId)) {
            final locationToModify = getLocationById(locationId);

            locations[locations.indexOf(locationToModify)] = locationToModify.modify(
                key,
                value,
            );
        }
    }

    List<String> getRecentNarration({int count = 7}) {
        final allAssistantMessages = messageHistory
            .where((e) => e.role == Role.assistant)
            .map((e) => e.content)
            .toList();

        final List<String> recentAssisantMessages = [];

        for (int i = allAssistantMessages.length - 1, b = 0; i >= 0; i--) {
            if (b == count) {
                break;
            }

            recentAssisantMessages.add(allAssistantMessages[i]);

            b++;
        }

        return recentAssisantMessages.reversed.toList();
    }

    Map<String, dynamic> toPlayerActionInfo() {
        final player = playerActor;
        final currentLocation = locations.firstWhere((l) => l.id == player.locationId);

        return {
            'settingSummary': settingSummary,
            'time': _currentTime.toJson(),
            'player': player.toJson(),
            'currentLocation': currentLocation.toJson(),
            'connectedLocations': getLocationsInAreaByOtherLocation(currentLocation)
                .map((e) => e.toJson())
                .toList(),
            'nearbyActors': getActorsInArea(currentLocation.locationArea, playerId: player.id)
                .map((a) => a.toJson())
                .toList(),
            'recentHistory': history.getLastEntriesOfList(20),
            'hiddenHistory': hiddenHistory.map((e) => e.toJson()).toList(),
            'currentEvents': currentEvents.getLastEntriesOfList(10),
            'currentRumors': currentRumors.getLastEntriesOfList(10),
            'takenActorIds': actors.map((a) => a.id).toList(),
            'takenLocationIds': locations.map((l) => l.id).toList(),
            'existingAreas': locations.map((l) => l.locationArea).toSet().toList(),
            'recentNarration': getRecentNarration(),
            'globalFlags': globalFlags,
        };
    }

    Map<String, dynamic> toLocalEventInfo() {
        final player = playerActor;
        final playerLocationId = player.locationId;

        final nearbyLocations = getLocationsInAreaByOtherLocation(getLocationById(playerLocationId));

        final actors = getActorsInArea(getLocationById(playerLocationId).locationArea);
        final actorIds = actors.map((a) => a.id).toList();

        return {
            'settingSummary': settingSummary,
            'time': _currentTime.toJson(),
            'centerLocationId': player.locationId,
            'locations': nearbyLocations.map((l) => l.toJson()).toList(),
            'actors': actors.map((a) => a.toJson()).toList(),
            'recentHistory': history.getLastEntriesOfList(20),
            'hiddenHistory': hiddenHistory
                .where((e) => e.relatedActorIds.containsOneOf(actorIds))
                .map((e) => e.toJson())
                .toList(),
            'currentEvents': currentEvents.getLastEntriesOfList(10),
            'currentRumors': currentRumors.getLastEntriesOfList(10),
            'takenActorIds': actors.map((a) => a.id).toList(),
            'takenLocationIds': locations.map((l) => l.id).toList(),
            'existingAreas': locations.map((l) => l.locationArea).toSet().toList(),
            'recentNarration': getRecentNarration(),
            'globalFlags': globalFlags,
        };
    }

    void applyChanges(Map<String, dynamic> json) {
        String narration = '';
        String? narrationChange;

        for (final entry in json.entries) {
            switch (entry.key) {
                case 'commandType':
                    continue;

                case 'actionScale':
                    continue;

                case 'narration':
                    narration = entry.value as String? ?? '';

                break;

                case 'narrationChange':
                    narrationChange = entry.value as String?;

                break;

                case 'stateChanges':
                    applyStates(
                        (entry.value as List<dynamic>?)
                                ?.map((e) => e as Map<String, dynamic>? ?? {})
                                .toList() ?? [],
                    );

                break;

                default:
                    Logger.createLog('Unknown entry while applying changes to the world -> ${entry.key}', LogType.warning);
            }
        }

        if (narrationChange != null && narration.isNotEmpty) {
            if (narrationChange.isNotEmpty) {
                switch (narrationChange) {
                    case 'add':
                        _currentNarration = '$_currentNarration $narration'.trim();
                    break;

                    case 'replace':
                        _currentNarration = narration.trim();
                    break;
                }
            }
            
        } else if (narrationChange == null && narration.isNotEmpty) {
            _currentNarration = narration.trim();
        }
    }

    int? parseSecondsFromAdvanceTime(Map<String, dynamic> json) {
        if ((json['type'] as String? ?? '') == 'advanceTime') {
            final years = json['years'] as int? ?? 0;
            final months = json['months'] as int? ?? 0;
            final days = json['days'] as int? ?? 0;
            final hours = json['hours'] as int? ?? 0;
            final minutes = json['minutes'] as int? ?? 0;
            final seconds = json['seconds'] as int? ?? 0;

            return
                years * _currentTime.daysInYear * _currentTime.hoursInDay * 60 * 60 +
                months * _currentTime.daysInMonth * _currentTime.hoursInDay * 60 * 60 +
                days * _currentTime.hoursInDay * 60 * 60 +
                hours * 60 * 60 +
                minutes * 60 +
                seconds;
        } else {
            return null;
        }
    }

    void applyStates(List<Map<String, dynamic>> states) {
        for (final addLocation in states.where((s) => s.containsValue('addLocation'))) {
            final json = Map<String, dynamic>.from(addLocation['location'] ?? {});

            locations.add(Location.fromJson(json));
        }

        for (final addActor in states.where((s) => s.containsValue('addActor'))) {
            final json = Map<String, dynamic>.from(addActor['actor'] ?? {});

            if (!actors.any((a) => a.id != (json['id'] as String? ?? ''))) {
                actors.add(Actor.fromJson(json));
            }
        }

        for (final updateActor in states.where((s) => s.containsValue('updateActor'))) {
            final json = Map<String, dynamic>.from(updateActor['actor'] ?? {});

            if (actorExist(json['id'] as String? ?? '')) {
                actors[actors.indexOf(getActorById(json['id']))] = Actor.fromJson(json);
            }
        }

        for (final state in states) {
            final type = state['type'] as String? ?? '';

            switch (type) {
                case 'advanceTime':
                    final totalSeconds = parseSecondsFromAdvanceTime(state);

                    if (totalSeconds != null && totalSeconds > 0) {
                        _currentTime = _currentTime.addSeconds(totalSeconds);
                    }

                break;

                case 'moveActor':
                    final locationId = state['locationId'] as String? ?? '';

                    if (locationExist(locationId)) {
                        modifyActorIfExist(
                        state['actorId'] as String? ?? '',
                        key: 'locationId',
                        value: locationId,
                        );
                    }

                break;

                case 'addLocation':
                    break;

                case 'removeLocation':
                    final locationId = state['locationId'] as String? ?? '';

                    locations.removeWhere((l) => l.id == locationId);

                break;

                case 'addActor':
                    break;

                case 'removeActor':
                    final actorId = state['actorId'] as String? ?? '';

                    actors.removeWhere((a) => a.id == actorId);

                break;

                case 'updateActor':
                    break;

                case 'setActorDeathTime':
                    final actorId = state['actorId'] as String? ?? '';
                    final deathTime = Time.fromJson(state['deathTime'] as Map<String, dynamic>? ?? {});

                    modifyActorIfExist(
                        actorId,
                        key: 'deathTime',
                        value: deathTime.toJson(),
                    );
                break;

                case 'addConnection':
                    final fromLocationId = state['fromLocationId'] as String? ?? '';
                    final toLocationId = state['toLocationId'] as String? ?? '';
                    final bidirectional = state['bidirectional'] as bool? ?? false;

                    if (locationExist(fromLocationId) && locationExist(toLocationId)) {
                        getLocationById(fromLocationId).addConnection(toLocationId);

                        if (bidirectional) {
                            getLocationById(toLocationId).addConnection(fromLocationId);
                        }
                    }

                break;

                case 'removeConnection':
                    final fromLocationId = state['fromLocationId'] as String? ?? '';
                    final toLocationId = state['toLocationId'] as String? ?? '';
                    final bidirectional = state['bidirectional'] as bool? ?? false;

                    if (locationExist(fromLocationId) && locationExist(toLocationId)) {
                        getLocationById(fromLocationId).removeConnection(toLocationId);

                        if (bidirectional) {
                            getLocationById(toLocationId).removeConnection(fromLocationId);
                        }
                    }

                break;

                case 'setActorStatus':
                    final actorId = state['actorId'] as String? ?? '';

                    if (actorExist(actorId)) {
                        final actor = getActorById(actorId);
                        final key = state['key'] as String? ?? '';
                        final value = state['value'] as dynamic ?? '';

                        if (key.isNotEmpty) {
                            actor.setStatus(key, value);
                        }
                    }

                break;

                case 'removeActorStatus':
                    final actorId = state['actorId'] as String? ?? '';

                    if (actorExist(actorId)) {
                        final actor = getActorById(actorId);
                        final key = state['key'] as String? ?? '';

                        if (key.isNotEmpty) {
                            actor.removeStatus(key);
                        }
                    }

                break;

                case 'setRelationship':
                    final actorId = state['actorId'] as String? ?? '';

                    if (actorExist(actorId)) {
                        final actor = getActorById(actorId);
                        final targetActorId = state['targetActorId'] as String? ?? '';
                        final value = state['value'] as int? ?? 0;

                        if (actorExist(targetActorId)) {
                            actor.setRelationship(targetActorId, value);
                        }
                    }

                break;

                case 'changeRelationship':
                    final actorId = state['actorId'] as String? ?? '';

                    if (actorExist(actorId)) {
                        final actor = getActorById(actorId);
                        final targetActorId = state['targetActorId'] as String? ?? '';
                        final delta = state['delta'] as int?;

                        if (actorExist(targetActorId) && delta != null) {
                            actor.changeRelationship(targetActorId, delta);
                        }
                    }

                break;

                case 'setLocationStatus':
                    final locationId = state['locationId'] as String? ?? '';
                    final value = state['status'] as String? ?? '';

                    if (value.isNotEmpty) {
                        modifyLocationIfExist(locationId, key: 'status', value: value);
                    }

                break;

                case 'setLocationFlag':
                    final locationId = state['locationId'] as String? ?? '';

                    if (locationExist(locationId)) {
                        final location = getLocationById(locationId);
                        final key = state['key'] as String? ?? '';
                        final value = state['value'] as dynamic ?? '';

                        if (key.isNotEmpty) {
                            location.setFlag(key, value);
                        }
                    }

                break;

                case 'removeLocationFlag':
                    final locationId = state['locationId'] as String? ?? '';

                    if (locationExist(locationId)) {
                        final location = getLocationById(locationId);
                        final key = state['key'] as String? ?? '';

                        location.removeFlag(key);
                    }

                break;

                case 'addLocationEnvironmentItem':
                    final locationId = state['locationId'] as String? ?? '';

                    if (locationExist(locationId)) {
                        final location = getLocationById(locationId);
                        final id = state['id'] as String? ?? '';
                        final item = state['item'] as String? ?? '';

                        if (item.isNotEmpty && id.isNotEmpty) {
                            location.addEnvironmentOrItem(id, item);
                        }
                    }

                break;

                case 'removeLocationEnvironmentItem':
                    final locationId = state['locationId'] as String? ?? '';

                    if (locationExist(locationId)) {
                        final location = getLocationById(locationId);
                        final id = state['id'] as String? ?? '';

                        if (id.isNotEmpty) {
                            location.removeEnvironmentOrItem(id);
                        }
                    }

                break;

                case 'setActorFlag':
                    final actorId = state['actorId'] as String? ?? '';

                    if (actorExist(actorId)) {
                        final actor = getActorById(actorId);
                        final key = state['key'] as String? ?? '';
                        final value = state['value'] as dynamic ?? '';

                        if (key.isNotEmpty) {
                            actor.setFlag(key, value);
                        }
                    }

                break;

                case 'removeActorFlag':
                    final actorId = state['actorId'] as String? ?? '';

                    if (actorExist(actorId)) {
                        final actor = getActorById(actorId);
                        final key = state['key'] as String? ?? '';

                        actor.removeFlag(key);
                    }

                break;

                case 'setGlobalFlag':
                    final key = state['key'] as String? ?? '';
                    final value = state['value'] as dynamic ?? '';

                    if (key.isNotEmpty) {
                        setGlobalFlag(key, value);
                    }

                break;

                case 'removeGlobalFlag':
                    final key = state['key'] as String? ?? '';

                    removeGlobalFlag(key);
                break;

                case 'setNeed':
                case 'changeNeed':
                    final delta = type == 'changeNeed';

                    final actorId = state['actorId'] as String? ?? '';

                    if (actorExist(actorId)) {
                        final actorNeeds = getActorById(actorId).needs;
                        final need = state['need'] as String? ?? '';
                        final change = delta
                            ? state['delta'] as int? ?? 0
                            : state['value'] as int? ?? 0;

                        if (need.isNotEmpty) {
                            bool other = need.contains('other.');

                            if (other) {
                                modifyActorIfExist(
                                actorId,
                                key: 'needs',
                                value: actorNeeds.changeOther(
                                        need.replaceFirst(RegExp(r'other.'), ''),
                                        change,
                                        delta: delta,
                                    ).toJson(),
                                );
                            } else {
                                modifyActorIfExist(
                                actorId,
                                key: 'needs',
                                value: actorNeeds
                                    .changeStandard(need, change, delta: delta)
                                    .toJson(),
                                );
                            }
                        }
                    }

                break;

                case 'addMemory':
                    final actorId = state['actorId'] as String? ?? '';

                    if (actorExist(actorId)) {
                        final actor = getActorById(actorId);
                        final text = state['text'] as String? ?? '';

                        if (text.isNotEmpty) {
                            actor.addMemoryEntry(text);
                        }
                    }
                break;

                case 'removeMemory':
                    final actorId = state['actorId'] as String? ?? '';

                    if (actorExist(actorId)) {
                        final actor = getActorById(actorId);
                        final textContains = state['textContains'] as String? ?? '';

                        if (textContains.isNotEmpty) {
                            actor.removeMemoryEntry(textContains);
                        }
                    }
                break;

                case 'addKnowledge':
                    final actorId = state['actorId'] as String? ?? '';

                    if (actorExist(actorId)) {
                        final actor = getActorById(actorId);
                        final text = state['text'] as String? ?? '';

                        if (text.isNotEmpty) {
                            actor.addKnowledgeEntry(text);
                        }
                    }
                break;

                case 'removeKnowledge':
                    final actorId = state['actorId'] as String? ?? '';

                    if (actorExist(actorId)) {
                        final actor = getActorById(actorId);
                        final textContains = state['textContains'] as String? ?? '';

                        if (textContains.isNotEmpty) {
                            actor.removeKnowledgeEntry(textContains);
                        }
                    }
                break;

                case 'addHistory':
                    final text = state['text'] as String? ?? '';

                    if (text.isNotEmpty) {
                        addHistoryEntry(text);
                    }
                break;

                case 'removeHistory':
                    final textContains = state['textContains'] as String? ?? '';

                    if (textContains.isNotEmpty) {
                        removeHistoryEntry(textContains);
                    }
                break;

                case 'addHiddenHistory':
                    final entryJson = Map<String, dynamic>.from(state['entry'] ?? {});

                    if (entryJson.isNotEmpty) {
                        addHiddenHistory(HiddenHistoryEntry.fromJson(entryJson));
                    }
                break;

                case 'updateHiddenHistory':
                    final entryJson = Map<String, dynamic>.from(state['entry'] ?? {});

                    if (entryJson.isNotEmpty) {
                        updateHiddenHistory(HiddenHistoryEntry.fromJson(entryJson));
                    }
                break;

                case 'removeHiddenHistory':
                    final id = state['id'] as String? ?? '';

                    removeHiddenHistory(id);
                break;

                case 'addCurrentEvent':
                    final text = state['text'] as String? ?? '';

                    if (text.isNotEmpty) {
                        addEventEntry(text);
                    }
                break;

                case 'removeCurrentEvent':
                    final textContains = state['textContains'] as String? ?? '';

                    if (textContains.isNotEmpty) {
                        removeEventEntry(textContains);
                    }
                break;

                case 'addRumor':
                    final text = state['text'] as String? ?? '';

                    if (text.isNotEmpty) {
                        addRumorEntry(text);
                    }
                break;

                case 'removeRumor':
                    final textContains = state['textContains'] as String? ?? '';

                    if (textContains.isNotEmpty) {
                        removeRumorEntry(textContains);
                    }
                break;

                case 'addInventoryItem':
                    final actorId = state['actorId'] as String? ?? '';

                    if (actorExist(actorId)) {
                        final actor = getActorById(actorId);
                        final itemName = state['item'] as String? ?? '';

                        if (itemName.isNotEmpty) {
                            actor.addInventoryItem(itemName);
                        }
                    }
                break;

                case 'removeInventoryItem':
                    final actorId = state['actorId'] as String? ?? '';

                    if (actorExist(actorId)) {
                        final actor = getActorById(actorId);
                        final itemName = state['item'] as String? ?? '';

                        if (itemName.isNotEmpty) {
                            actor.removeInventoryItem(itemName);
                        }
                    }
                break;

                case 'setInventory':
                    final actorId = state['actorId'] as String? ?? '';

                    if (actorExist(actorId)) {
                        final list = List<String>.from(state['inventory'] ?? []);

                        modifyActorIfExist(actorId, key: 'inventory', value: list);
                    }
                break;

                case 'setActorPosition':
                    final actorId = state['actorId'] as String? ?? '';

                    if (actorExist(actorId)) {
                        final text = state['text'] as String? ?? '';

                        if (text.isNotEmpty) {
                            modifyActorIfExist(actorId, key: 'position', value: text);
                        }
                    }
                break;

                default:
                    Logger.createLog('Unknown state type while applying changes to the world -> $type', LogType.warning);
            }
        }
    }

    void setGlobalFlag(String key, dynamic value) {
        globalFlags[key] = value;
    }

    void removeGlobalFlag(String key) {
        globalFlags.remove(key);
    }

    void addHiddenHistory(HiddenHistoryEntry entry) {
        if (!hiddenHistory.any((h) => h.id == entry.id)) {
        hiddenHistory.add(entry);
        }
    }

    void updateHiddenHistory(HiddenHistoryEntry entry) {
        if (hiddenHistory.any((h) => h.id == entry.id)) {
        final existingHistories = hiddenHistory.where((e) => e.id == entry.id);

        if (existingHistories.length == 1) {
            final existingHistory = existingHistories.first;

            hiddenHistory[hiddenHistory.indexOf(existingHistory)] = entry;
        }
        }
    }

    void removeHiddenHistory(String id) {
        hiddenHistory.removeWhere((h) => h.id == id);
    }

    Future<void> writeWorld() async {
        await write(savePath, content: encodeWithIndent(toJson()));
    }

    factory World.fromJson(Map<String, dynamic> json) {
        return World(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',

        currentTime: Time.fromJson(
            json['currentTime'] as Map<String, dynamic>? ?? {},
        ),
        settingSummary: json['settingSummary'] as String? ?? '',

        locations:
            (json['locations'] as List<dynamic>?)
                ?.map((e) => Location.fromJson(e as Map<String, dynamic>? ?? {}))
                .toList() ??
            [],
        actors:
            (json['actors'] as List<dynamic>?)
                ?.map((e) => Actor.fromJson(e as Map<String, dynamic>? ?? {}))
                .toList() ??
            [],

        history: List<String>.from(json['history'] ?? []),
        currentEvents: List<String>.from(json['currentEvents'] ?? []),
        currentRumors: List<String>.from(json['currentRumors'] ?? []),
        hiddenHistory:
            (json['hiddenHistory'] as List<dynamic>?)
                ?.map(
                    (e) => HiddenHistoryEntry.fromJson(
                    e as Map<String, dynamic>? ?? {},
                    ),
                )
                .toList() ??
            [],

        messageHistory:
            (json['messageHistory'] as List<dynamic>?)
                ?.map((e) => ChatEntry.fromJson(e as Map<String, dynamic>? ?? {}))
                .toList() ??
            [],
        globalFlags: Map<String, dynamic>.from(json['globalFlags'] ?? {}),
        );
    }

    Map<String, dynamic> toJson() {
        return {
        'id': id,
        'name': name,

        'currentTime': _currentTime.toJson(),
        'settingSummary': settingSummary,

        'locations': locations.map((e) => e.toJson()).toList(),
        'actors': actors.map((e) => e.toJson()).toList(),

        'history': history,
        'currentEvents': currentEvents,
        'currentRumors': currentRumors,
        'hiddenHistory': hiddenHistory.map((e) => e.toJson()).toList(),

        'messageHistory': messageHistory.map((e) => e.toJson()).toList(),
        'globalFlags': globalFlags,
        };
    }
}
