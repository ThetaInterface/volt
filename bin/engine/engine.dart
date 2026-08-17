import 'dart:convert';
import 'dart:io';

import 'package:mistralai_client_dart/mistralai_client_dart.dart';
import 'package:path/path.dart' as path;

import '../data.dart' as data;
import '../models/models.dart';
import '../utils/utils.dart';

class Engine {
    final MistralAIClient client;

    Engine(this.client);

    Future<Map<String, dynamic>> generateEventOnPlayerAction(final String playerAction, final World world) async {
        final playerEventRaw = await _sendRequest([
            SystemMessage(content: 
                Content.string(data.playerActionEventGenerationSystemPrompt())
            ),
            UserMessage(content: 
                UserMessageContent.string(data.playerActionEventGenerationUserPrompt( 
                        encodeWithIndent(
                            world.toPlayerActionInfo()
                                ..addEntries([MapEntry(
                                    'playerCommand', playerAction
                                )])
                        )
                    )
                )
            )
        ]);

        if (playerEventRaw.isEmpty) {
            Logger.createLog('Empty response while generation event on player actions', LogType.warning);

            return {};
        }

        final playerEventJson = Map<String, dynamic>.from(jsonDecode(playerEventRaw));
        await write(path.join(Global.programPath, 'player_action.json'), content: encodeWithIndent(playerEventJson)); // temp

        if ((playerEventJson['commandType'] as String? ?? '') != 'meta_question' && 
            (playerEventJson['actionScale'] as String? ?? '') != 'none') {

            final localEventRaw = await _sendRequest([
                SystemMessage(content: 
                    Content.string(data.localEventGenerationSystemPrompt())
                ),
                UserMessage(content: 
                    UserMessageContent.string(data.localEventGenerationUserPrompt(
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
                )
            ]);

            if (localEventRaw.isEmpty) {
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

    Future<void> printNarration(String narration) async {
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

    Future<String> _sendRequest(List<dynamic> messages) async {
        final response = await client.chatComplete(
            request: ChatCompletionRequest(
                model: 'mistral-large-latest', 
                messages: messages,
                temperature: 0.7,
                responseFormat: ResponseFormat(type: ResponseFormats.jsonObject)
            )
        );

        return response.choices?.first.message.content?.value.toString() ?? '';
    }
}