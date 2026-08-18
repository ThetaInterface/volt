import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

import 'utils/utils.dart';
import 'user_interface.dart' as ui;
import 'models/models.dart';
import 'engine/engine.dart';

Future<void> menu() async {
    final welcomeText = '1) ${await Global.currentLocale.getEntry('client.runServerRemotely')}\n'
        '2) ${await Global.currentLocale.getEntry('client.manageSaves')}\n'        
        '3) ${await Global.currentLocale.getEntry('client.openSettings')}\n'
        '4) ${await Global.currentLocale.getEntry('client.exitGame')}\n\n'
        '${await Global.currentLocale.getEntry('client.actionRequest')} ';

    final action = ui.getNumber(1, 4, textToShow: welcomeText, disableExit: true);

    switch (action.$2) {
        case 1:
            World? loadedWorld = await chooseSave();

            if (loadedWorld != null) {
                final isReady = ui.getBool(textToShow: '${await Global.currentLocale.getEntry('client.startGameRequest')} ', disableExit: true);

                if (isReady.$2) {
                    await Global.selfStartWithArgs('--remote-server');
                    await startGame(loadedWorld.savePath, 'remote');
                }
            }
        case 2:
            await chooseSave(remoteGeneration: false);

        case 4:
            exit(0);

        case 0:
            Logger.createLog('input err', LogType.fatal);
            exit(1);
    }
}

Future<World?> chooseSave({bool remoteGeneration = true}) async {                                                               
    var savesText = '1) ${await Global.currentLocale.getEntry('client.createNewSave')}\n';

    final saveDir = Directory(Global.savesDirectoryPath);
    final saveFilePaths = await saveDir.list().map((s) => s.path).toList();
    final saveNames = saveFilePaths.map((f) => path.basenameWithoutExtension(f)).toList();

    for (int i = 1; i <= saveNames.length; i++) {
        savesText += '${i + 1}) ${saveNames[i - 1]}\n';
    }

    savesText += '\n${await Global.currentLocale.getEntry('client.saveIndexRequest')} ';

    final saveIndex = ui.getNumber(1, saveNames.length + 1, textToShow: savesText);

    if (!saveIndex.$1) {
        return null;
    }

    if (saveIndex.$2 == 1) {
        final summary = await ui.getString(textToShow: '${await Global.currentLocale.getEntry('client.newWorldSummaryRequest')} ');

        if (!summary.$1) {
            return null;
        }

        if (remoteGeneration) {
            final newWorld = await Engine.worldGeneration(summary.$2);

            if (newWorld != null) {
                await write(newWorld.savePath, content: encodeWithIndent(newWorld.toJson()));
            }

            return newWorld;
        } else {
            return null; // fix: localy world generation support
        }
    } else {
        final content = await read(saveFilePaths[saveIndex.$2 - 2]);

        if (!content.$1) {
            return null;
        }

        return World.fromJson(jsonDecode(content.$2));
    }
}

Future<void> startGame(String worldSaveFilePath, String serverType) async {
    stdout.clearScreen();

    final socket = await connectToServer(worldSaveFilePath, serverType);
    await gameCycle(socket);
}

Future<void> gameCycle(WebSocket socket) async {
    stdout.clearScreen();

    while (true) {
        final userInput = (await ui.getString(textToShow: '> ', clearScreen: false));

        if (!userInput.$1) {
            socket.close();

            return;
        }

        final prompt = userInput.$2.trim();

        print(prompt);

        if (prompt.isEmpty) {
            continue;
        }

        socket.add(prompt);
    }
}


Future<WebSocket> connectToServer(String worldSaveFilePath, String serverType) async {
    final url = 'ws://127.0.0.1:9999';
    stdout.write(await Global.currentLocale.getEntry('client.connectionPending'));

    while (true) {
        try {
            final socket = await WebSocket.connect(url);

            stdout.clearScreen();
            socket.add(jsonEncode({
                'worldSaveFilePath': worldSaveFilePath,
                'serverType': serverType
            }));

            return socket;
        } catch (e) {
            stdout.write('.');

            await Future.delayed(const Duration(seconds: 1));
        }
    }
}