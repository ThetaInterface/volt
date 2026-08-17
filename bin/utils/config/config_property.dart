import '../global.dart';

enum ConfigProperty {
    language,
    exitPhrase,
    logRotation,
    logRotationLimit,
    mistralApiKey,
    messageHistorySize,
    worldHistorySize,
    worldEventsSize,
    worldRumorsSize,
    actorMemorySize,
    actorKnowledgeSize,
    textSpeed;

    factory ConfigProperty.fromString(String string) {
        return switch (string.trim()) {
            'language' => language,
            'exitPhrase' => exitPhrase,
            'logRotation' => logRotation,
            'logRotationLimit' => logRotationLimit,
            'mistralApiKey' => mistralApiKey,
            'messageHistorySize' => messageHistorySize,
            'worldHistorySize' => worldHistorySize,
            'worldEventsSize' => worldEventsSize,
            'worldRumorsSize' => worldRumorsSize,
            'actorMemorySize' => actorMemorySize,
            'actorKnowledgeSize' => actorKnowledgeSize,
            'textSpeed' => textSpeed,
            _ => throw UnsupportedError('Unexpected config entry \'$string\'')
        };    
    }

    String toJsonKey() {
        return switch (this) {
            ConfigProperty.language => 'language',
            ConfigProperty.exitPhrase => 'exitPhrase',
            ConfigProperty.logRotation => 'logRotation',
            ConfigProperty.logRotationLimit => 'logRotationLimit',
            ConfigProperty.mistralApiKey => 'mistralApiKey',
            ConfigProperty.messageHistorySize => 'messageHistorySize',
            ConfigProperty.worldHistorySize => 'worldHistorySize',
            ConfigProperty.worldEventsSize => 'worldEventsSize',
            ConfigProperty.worldRumorsSize => 'worldRumorsSize',
            ConfigProperty.actorMemorySize => 'actorMemorySize',
            ConfigProperty.actorKnowledgeSize => 'actorKnowledgeSize',
            ConfigProperty.textSpeed => 'textSpeed',
        };
    }

    Future<String> toFormattedString() async {
        return switch (this) {
            ConfigProperty.language => await Global.currentLocale.getEntry('configProperty.language'),
            ConfigProperty.exitPhrase => await Global.currentLocale.getEntry('configProperty.exitPhrase'),
            ConfigProperty.logRotation => await Global.currentLocale.getEntry('configProperty.logRotation'),
            ConfigProperty.logRotationLimit => await Global.currentLocale.getEntry('configProperty.logRotationLimit'),
            ConfigProperty.mistralApiKey => await Global.currentLocale.getEntry('configProperty.mistralApiKey'),
            ConfigProperty.messageHistorySize => await Global.currentLocale.getEntry('configProperty.messageHistorySize'),
            ConfigProperty.worldHistorySize => await Global.currentLocale.getEntry('configProperty.worldHistorySize'),
            ConfigProperty.worldEventsSize => await Global.currentLocale.getEntry('configProperty.worldEventsSize'),
            ConfigProperty.worldRumorsSize => await Global.currentLocale.getEntry('configProperty.worldRumorsSize'),
            ConfigProperty.actorMemorySize => await Global.currentLocale.getEntry('configProperty.actorMemorySize'),
            ConfigProperty.actorKnowledgeSize => await Global.currentLocale.getEntry('configProperty.actorKnowledgeSize'),
            ConfigProperty.textSpeed => await Global.currentLocale.getEntry('configProperty.textSpeed'),
        };
    }
}