import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mistralai_client_dart/mistralai_client_dart.dart' hide Role; 

import 'utils/utils.dart';
import 'models/models.dart';
import 'engine/engine.dart';

class Server {
    static bool _busy = false;

    static List<dynamic> convertToMistralChatHistory(List<ChatEntry> entries) {
        return entries.map((e) => switch (e.role) {
            Role.system => SystemMessage(content: Content.string(e.content)),
            Role.user => UserMessage(content: UserMessageContent.string(e.content)),
            Role.assistant => AssistantMessage(content: AssistantMessageContent.string(e.content)),
        }).toList();
    }

    static Future<void> launch(StreamIterator<dynamic> iterator, World world) async {
        World? lastWorldState;

        try {
            while (await iterator.moveNext()) {
                try {
                    final message = iterator.current.toString();

                    if (message == 'revert') {

                        if (!_busy) {
                            _busy = true;

                            if (lastWorldState != null) {
                                world = lastWorldState;

                                world.writeWorld();

                                print('reverted');
                            } else {
                                print('revert cancel');
                            }

                            _busy = false; 
                        } else {
                            print('busy');
                        }

                        continue;
                    }

                    if (!_busy) {
                        _busy = true;

                        lastWorldState = World.fromJson(world.toJson());

                        world.addMessageToHistory(role: Role.user, content: message);

                        final aiResponse = await Engine.generateEventOnPlayerAction(message, world);

                        final playerEvent = aiResponse['playerEvent'] as Map<String, dynamic>? ?? {};
                        final localEvent = aiResponse['localEvent'] as Map<String, dynamic>? ?? {};

                        world.applyChanges(playerEvent);
                        world.applyChanges(localEvent);

                        final currentNarration = world.getCurrentNarration();

                        world.addMessageToHistory(
                            role: Role.assistant, 
                            content: '${world.currentTime.shortTime}: $currentNarration'
                        );

                        world.writeWorld();

                        await Engine.printNarration(currentNarration);
                        print('\n');

                        _busy = false;
                    } else {
                        print('busy');
                    }
                } catch (innerError, stack) {
                    print('\n[Ошибка хода]: $innerError -> $stack');

                    _busy = false;
                }
            }
        } catch (e) {
            await Logger.createLog('Fatal error in iterator -> $e', LogType.fatal);
        } finally {
            exit(0);
        }
    }

    static Future<void> setup() async {
        final server = await HttpServer.bind(InternetAddress.anyIPv4, 9999);

        await for (HttpRequest request in server) {
            if (WebSocketTransformer.isUpgradeRequest(request)) {
                final socket = await WebSocketTransformer.upgrade(request);
                print(await Global.currentLocale.getEntry('clientConnected'));

                final iterator = StreamIterator(socket);

                if (await iterator.moveNext()) {
                    final clientInfo = iterator.current.toString();

                    final startData = jsonDecode(clientInfo) as Map<String, dynamic>;
                    final String savePath = startData['worldSaveFilePath'];
                    final String serverType = startData['serverType'];

                    final world = World.fromJson(jsonDecode((await read(savePath)).$2));

                    switch (serverType.trim()) {
                        case 'remote':
                            await launch(iterator, world);

                        case 'local':
                            throw UnimplementedError();

                        default:
                            await iterator.cancel();
                            await socket.close();

                            return;
                    }
                }
            }
        }
    }
}