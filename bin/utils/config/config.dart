import 'dart:convert';

import '../utils.dart';

class Config {
    static final Map<ConfigProperty, dynamic> defaultFields = {
        ConfigProperty.language: 'en',
        ConfigProperty.exitPhrase: 'exit',
        ConfigProperty.logRotation: true,
        ConfigProperty.logRotationLimit: 1000,
        ConfigProperty.aiProviderInUse: 'mistral',
        ConfigProperty.mistralApiKey: '',
        ConfigProperty.customOpenAICompatibleProviderUrl: '',
        ConfigProperty.customOpenAICompatibleApiKey: '',
        ConfigProperty.customOpenAICompatibleModel: '',
        ConfigProperty.temperature: 0.7,
        ConfigProperty.messageHistorySize: 30,
        ConfigProperty.worldHistorySize: 50,
        ConfigProperty.worldRumorsSize: 50,
        ConfigProperty.worldEventsSize: 50,
        ConfigProperty.actorMemorySize: 20,
        ConfigProperty.actorKnowledgeSize: 20,
        ConfigProperty.textSpeed: 0.5,
        ConfigProperty.generateLocalEvents: true,
        ConfigProperty.regenerateAttemptCount: 1
    };

    final Map<ConfigProperty, dynamic> _fields;

    Config(this._fields);

    factory Config.fromJson(Map<String, dynamic> json) {
        final Map<ConfigProperty, dynamic> processedJson = {};
        
        for (var entry in json.entries) {
            processedJson.addEntries(
                [MapEntry<ConfigProperty, dynamic>(ConfigProperty.fromString(entry.key), entry.value)]
            );
        }

        return Config({
            ConfigProperty.language: processedJson[ConfigProperty.language] as String? ?? 'en',
            ConfigProperty.exitPhrase: processedJson[ConfigProperty.exitPhrase] as String? ?? 'exit',
            ConfigProperty.logRotation: processedJson[ConfigProperty.logRotation] as bool? ?? true,
            ConfigProperty.logRotationLimit: processedJson[ConfigProperty.logRotationLimit] as int? ?? 1000,
            ConfigProperty.aiProviderInUse: processedJson[ConfigProperty.aiProviderInUse] as String? ?? 'mistral',
            ConfigProperty.mistralApiKey: processedJson[ConfigProperty.mistralApiKey] as String? ?? '',
            ConfigProperty.customOpenAICompatibleProviderUrl: processedJson[ConfigProperty.customOpenAICompatibleProviderUrl] as String? ?? '',
            ConfigProperty.customOpenAICompatibleApiKey: processedJson[ConfigProperty.customOpenAICompatibleApiKey] as String? ?? '',
            ConfigProperty.customOpenAICompatibleModel: processedJson[ConfigProperty.customOpenAICompatibleModel] as String? ?? '',
            ConfigProperty.temperature: (processedJson[ConfigProperty.temperature] as num?)?.toDouble() ?? 0.7,
            ConfigProperty.messageHistorySize: processedJson[ConfigProperty.messageHistorySize] as int? ?? 30,
            ConfigProperty.worldHistorySize: processedJson[ConfigProperty.worldHistorySize] as int? ?? 50,
            ConfigProperty.worldRumorsSize: processedJson[ConfigProperty.worldRumorsSize] as int? ?? 50,
            ConfigProperty.worldEventsSize: processedJson[ConfigProperty.worldEventsSize] as int? ?? 50,
            ConfigProperty.actorMemorySize: processedJson[ConfigProperty.actorMemorySize] as int? ?? 20,
            ConfigProperty.actorKnowledgeSize: processedJson[ConfigProperty.actorKnowledgeSize] as int? ?? 20,
            ConfigProperty.textSpeed: (processedJson[ConfigProperty.textSpeed] as num?)?.toDouble() ?? 0.5,
            ConfigProperty.generateLocalEvents: processedJson[ConfigProperty.generateLocalEvents] as bool? ?? true,
            ConfigProperty.regenerateAttemptCount: processedJson[ConfigProperty.regenerateAttemptCount] as int? ?? 1
        });
    }

    Map<String, dynamic> toJson() {
        return Map.fromEntries(_fields.entries.map((e) => MapEntry<String, dynamic>(e.key.toJsonKey(), e.value)));
    }


    
    static Future<Config> readConfig() async {
        final file = await read(Global.configFilePath);

        if (!file.$1) {
            await Config(defaultFields).writeConfig();

            return Config(defaultFields);
        }

        try {
            return Config.fromJson(jsonDecode(file.$2));
        } catch (e) {
            await Logger.createLog('Broken config -> $e', LogType.warning);

            final defaultConfig = Config(defaultFields);

            defaultConfig.writeConfig();
            return defaultConfig;
        }
    }

    void repairConfig() {
        for (var entry in defaultFields.entries) {
            if (!_fields.containsKey(entry.key)) {
                _fields.addEntries([MapEntry(entry.key, entry.value)]);
            }
        }
    }

    dynamic getValueOrDefault(ConfigProperty property) => _fields[property] ?? defaultFields[property]!;

    Future<void> writeConfig() async {
        await write(Global.configFilePath, content: JsonEncoder.withIndent('    ').convert(this));
    }
}