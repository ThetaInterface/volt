import 'dart:convert';
import 'dart:io';

import 'package:mistralai_client_dart/mistralai_client_dart.dart' hide Role;
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

import '../data.dart' as data;
import '../models/models.dart';
import '../utils/utils.dart';

class Engine {
    static Future<World?> worldGeneration(String settingSummary) async {
        try {
            stdout.clearScreen();
            print(await Global.currentLocale.getEntry('client.newWorldGenerationStart'));

            final messages = [
                ChatEntry(
                    role: Role.system,
                    content: data.worldGenerationSystemPrompt(),
                ),
                ChatEntry(
                    role: Role.user,
                    content: data.worldGenerationUserPrompt(settingSummary),
                ),
            ];
            
            final rawJson = await _sendRequest(messages, Global.currentConfig.getValueOrDefault(ConfigProperty.aiProviderInUse));

            print(await Global.currentLocale.getEntry('client.newWorldGenerationFinish'));

            if (rawJson == null || rawJson.isEmpty) {
                Logger.createLog('No response from ai while world generation', LogType.warning);

                return null;
            }

            final world = World.fromJson(jsonDecode(rawJson));

            return world;
        } catch (e) {
            Logger.createLog('Unexpected error while generating world with mistral ai -> $e',LogType.warning);

            return null;
        }
    }

    static Future<Map<String, dynamic>> generateEventOnPlayerAction(final String playerAction, final World world) async {
        final provider = Global.currentConfig.getValueOrDefault(ConfigProperty.aiProviderInUse);
        
        final playerEventRaw = await _sendRequest([
                ChatEntry(
                    role: Role.system, 
                    content: data.playerActionEventGenerationSystemPrompt()
                ),
                ChatEntry(
                    role: Role.user, 
                    content: data.playerActionEventGenerationUserPrompt( 
                        encodeWithIndent(
                            world.toPlayerActionInfo()
                                ..addEntries([MapEntry(
                                    'playerCommand', playerAction
                                )])
                        )
                    )
                )
            ], 
            provider
        );

        if (playerEventRaw == null || playerEventRaw.isEmpty) {
            Logger.createLog('Empty response while generation event on player actions', LogType.warning);

            return {};
        }

        final playerEventJson = Map<String, dynamic>.from(jsonDecode(playerEventRaw));
        await write(path.join(Global.programPath, 'player_action.json'), content: encodeWithIndent(playerEventJson)); // temp

        if ((playerEventJson['commandType'] as String? ?? '') != 'meta_question' && 
            (playerEventJson['actionScale'] as String? ?? '') != 'none') {

            final localEventRaw = await _sendRequest([
                    ChatEntry(
                        role: Role.system,
                        content: data.localEventGenerationSystemPrompt()
                    ),
                    ChatEntry(
                        role: Role.user,
                        content: data.localEventGenerationUserPrompt(
                            encodeWithIndent(
                                world.toLocalEventInfo()
                                    ..addEntries([
                                        MapEntry(
                                            'playerEvent', playerEventJson
                                        ), MapEntry(
                                            'timePassed', 
                                            world.parseSecondsFromAdvanceTime(
                                                (playerEventJson['stateChanges'] as List<dynamic>? ?? [])
                                                .where((s) => (s as Map<String, dynamic>? ?? {}).containsKey('advanceTime'))
                                                .toList()
                                                .firstOrNull ?? {}
                                            ) ?? 0
                                        )
                                    ])
                            )
                        )
                    )
                ], provider
            );

            if (localEventRaw == null || localEventRaw.isEmpty) {
                Logger.createLog('Empty response while generation local event', LogType.warning);

                return {};
            }

            final localEventJson = Map<String, dynamic>.from(jsonDecode(localEventRaw));
            await write(path.join(Global.programPath, 'final_event.json'), content: encodeWithIndent(localEventJson)); // temp

            return {
                'playerEvent': playerEventJson,
                'localEvent': localEventJson
            };
        }

        return {
            'playerEvent': playerEventJson
        };
    }

    static Future<void> printNarration(String narration) async {
        final regex = RegExp(r'^\p{P}$', unicode: true);
        final textSpeed = 1 - (Global.currentConfig.getValueOrDefault(ConfigProperty.textSpeed) as num).toDouble();

        for (final symbol in narration.split('')) {
            stdout.write(symbol);

            if (regex.hasMatch(symbol)) {
                await Future.delayed(Duration(milliseconds: (400 * textSpeed).toInt()));
            } else {
                await Future.delayed(Duration(milliseconds: (80 * textSpeed).toInt()));
            }
        }
    }

    static Future<String?> _sendRequest(List<ChatEntry> messages, String provider) async {
        return switch (provider) {
            'mistral' => await _sendRequestToMistalAI(messages),
            
            'custom' => await _sendRequestToCustomProvider(messages),

            _ => null
        };
    }

    static Future<String?> _sendRequestToMistalAI(List<ChatEntry> messages) async {
        final client = MistralAIClient(apiKey: Global.currentConfig.getValueOrDefault(ConfigProperty.mistralApiKey));

        final response = await client.chatComplete(
            request: ChatCompletionRequest(
                model: 'mistral-large-latest', 
                messages: messages.map((m) => m.toMistralChatEntry()).toList(),
                temperature: Global.currentConfig.getValueOrDefault(ConfigProperty.temperature),
                responseFormat: ResponseFormat(type: ResponseFormats.jsonObject)
            )
        );

        client.endSession();

        return response.choices?.first.message.content?.value.toString();
    }

    static Future<String?> _sendRequestToCustomProvider(List<ChatEntry> messages) async {
        final url = Uri.parse(Global.currentConfig.getValueOrDefault(ConfigProperty.customOpenAICompatibleProviderUrl));

        final client = http.Client();

        try {
            final request = http.Request('POST', url)
                ..headers['Content-Type'] = 'application/json'
                ..headers['Authorization'] = 'Bearer ${Global.currentConfig.getValueOrDefault(ConfigProperty.customOpenAICompatibleApiKey)}'
                ..body = jsonEncode({
                    'model': Global.currentConfig.getValueOrDefault(ConfigProperty.customOpenAICompatibleModel),
                    'temperature': Global.currentConfig.getValueOrDefault(ConfigProperty.temperature),
                    'stream': true,
                    'messages':  messages.map((m) => m.toCustomProviderChatEntry()).toList()
                });

            final response = await client.send(request);

            if (response.statusCode == 200) {
                StringBuffer fullResponseBuffer = StringBuffer();

                await response.stream.transform(utf8.decoder).transform(const LineSplitter())
                    .listen((String line) {
                        if (line.startsWith('data: ') && !line.contains('[DONE]')) {
                            final jsonString = line.substring(6); // Отрезаем префикс "data: "
                            
                            try {
                                final Map<String, dynamic> parsedChunk = jsonDecode(jsonString);
                                final String? chunkContent = parsedChunk['choices']?[0]?['delta']?['content'];
                                
                                if (chunkContent != null) {
                                    fullResponseBuffer.write(chunkContent);
                                }
                            } catch (_) {

                            }
                        }
                }).asFuture();

                return fullResponseBuffer.toString().trim();
            } else {
                Logger.createLog('Error while using custom provider. err code -> ${response.statusCode}', LogType.warning);

                return null;
            }
        } catch (e) {
            Logger.createLog('Network errror while using custom provider -> $e', LogType.fatal);

            return null;
        } finally {
            client.close();
        }
    }
}