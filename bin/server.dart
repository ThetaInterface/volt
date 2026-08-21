import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'utils/utils.dart';
import 'models/models.dart';
import 'engine/engine.dart';

class Server {
    static final List<Package> _pull = []; 

    static World? _world;
    static World? _lastWorldState;

    static Package? _job;
    static bool _exited = false;

    static Future<void> _processor() async {
        while (!_exited) {
            if (_pull.isNotEmpty) {
                final request = _pull.first;

                switch (request.action) {
                    case 'prompt':
                        if (_job == null) {
                            _prompt(request.content);
                        } else {
                            _printJobPendingAlert();
                        }
                    break;

                    case 'cancel_prompt':
                        if (_job != null && _job!.action == 'prompt') {
                            if (!Engine.isCanceled) {
                                Engine.cancelGeneration();

                                Engine.addNarration(
                                    '${await Global.currentLocale.getEntry('client.inGame_promptCancelPending')}\n\n\n'
                                );
                            } else {
                                Engine.addNarration(
                                    '${await Global.currentLocale.getEntry('client.inGame_promptAlreadyCanceled')}\n\n\n'
                                );
                            }
                        } else {
                            Engine.addNarration(
                                '${await Global.currentLocale.getEntry('client.inGame_noPromptsPending')}\n\n\n'
                            );
                        }
                    break;

                    case 'revert':
                        if (_job == null) {
                            _revert();
                        } else {
                            _printJobPendingAlert();
                        }
                    break;

                    case 'exit':
                        if (_job == null) {
                            _exited = true;

                            exit(0);
                        }
                    break;
                }

                _pull.remove(request);
            }
            
            await Future.delayed(Duration(milliseconds: 200));
        }
    }

    static Future<void> _revert() async {
        if (_lastWorldState != null && _world != null) {
            _job = Package(action: 'revert', content: '');

            _world = World.copy(_lastWorldState!);
            await write(_world!.savePath, content: encodeWithIndent(_world!.toJson()));

            await _printMessageHistory(
                _world!.messageHistory
                    .where((e) => e.role == Role.assistant)
                    .toList()
            );

            _job = null;
        }
    }

    static Future<void> _prompt(String prompt) async {
        try {
            _job = Package(action: 'prompt', content: prompt);

            Engine.addNarration('${await Global.currentLocale.getEntry('client.ingGame_generationPending')}\n\n\n');

            _lastWorldState = World.copy(_world!);

            final eventGeneration = await Engine.generateEventOnPlayerAction(prompt, _world!);
            
            if (eventGeneration.type == ResultType.done) {
                final event = eventGeneration.content as Map<String, dynamic>;

                final playerEvent = event['playerEvent'] as Map<String, dynamic>? ?? {};
                final localEvent = event['localEvent'] as Map<String, dynamic>? ?? {};

                _world!.applyChanges(playerEvent);
                _world!.applyChanges(localEvent);

                final currentNarration = _world!.getCurrentNarration();

                _world!.addMessageToHistory(role: Role.user, content: prompt);

                _world!.addMessageToHistory(
                    role: Role.assistant, 
                    content: '${_world!.currentTime.shortTime}: $currentNarration'
                );

                _world!.writeWorld();

                await _printMessageHistory(
                    _world!.messageHistory
                        .where((e) => e.role == Role.assistant)
                        .toList(),
                    lastSpecial: true
                );
            } else if (eventGeneration.type == ResultType.canceled) {
                Engine.addNarration('${await Global.currentLocale.getEntry('client.inGame_generationCanceled')}\n\n\n');
            } else {
                Engine.addNarration('${await Global.currentLocale.getEntry('client.inGame_generationFailed')}\n\n\n');
            }
            
            _job = null;
        } catch (innerError, stack) {
            print('\n[${await Global.currentLocale.getEntry('client.inGame_generationError')}]: $innerError -> $stack');

            _job = null;
        }
    }

    static Future<void> _printMessageHistory(List<ChatEntry> messages, {bool lastSpecial = false}) async {
        stdout.clearScreen();

        for (int i = 0; i < messages.length; i++) {
            final message = messages[i];
            final index = i + 1;

            if (lastSpecial && index == messages.length) {
                Engine.addNarration('$index. ${message.content}\n\n\n');
            } else {
                stdout.write('$index. ${message.content}');

                stdout.write('\n\n\n');
            }
        }
    }

    static Future<void> _printJobPendingAlert() async {
        if (_job != null) {
            final message = switch (_job!.action) {
                'prompt' => await Global.currentLocale.getEntry('client.inGame_promptPendingAlert'),
                'revert' => await Global.currentLocale.getEntry('client.inGame_revertPendingAlert'),

                _ => '' 
            };

            Engine.addNarration('$message\n\n\n');
        }
    }

    static Future<void> _launch(StreamIterator<dynamic> iterator) async {
        try {
            await _printMessageHistory(
                _world!.messageHistory
                    .where((e) => e.role == Role.assistant)
                    .toList()
            );

            _processor();

            while (await iterator.moveNext() && !_exited) {
                final package = Package.fromJson(jsonDecode(iterator.current));

                if (package.action == 'prompt') {
                    if (_job == null) {
                        _pull.add(package);

                        continue;
                    }
                }
                
                _pull.add(package);
            }
        } catch (e) {
            await Logger.createLog('Fatal error in iterator -> $e', LogType.fatal);
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
                    final String savePath = iterator.current.toString();

                    _world = World.fromJson(jsonDecode((await read(savePath)).$2));
                    _world!.savePath = savePath;

                    await _launch(iterator);

                    await iterator.cancel();
                    await socket.close();

                    return;
                }
            }
        }
    }
}