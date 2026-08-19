import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

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

    final action = ui.getInt(1, 4, textToShow: welcomeText, disableExit: true);

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

        break;

        case 2:
            await chooseSave(remoteGeneration: false);

        break;    

        case 3:
            await editConfig();

        break;

        case 4:
            exit(0);

        default:
            Logger.createLog('input err', LogType.fatal);
            exit(1);
    }
}

Future<void> editConfig() async {
    var fields = Global.currentConfig.toJson().map((k, v) => MapEntry(k, v)).entries.toList();

    while (true) {
        stdout.clearScreen();
        
        final formated = await Future.wait(
            fields.map((e) async {
                    final key = ConfigProperty.fromString(e.key);

                    return MapEntry(
                        await key.toFormatedString(), 
                        key.isSecret() ? '' : '(${e.value})'
                    );
                }   
            )
        );

        final StringBuffer buffer = StringBuffer();

        for (int i = 0; i < formated.length; i++) {
            buffer.writeln('${i + 1}) ${formated[i].key} ${formated[i].value}');
        }

        buffer.writeln('${formated.length + 1}) ${await Global.currentLocale.getEntry('client.editConfig_reset')}');
        buffer.writeln('${formated.length + 2}) ${await Global.currentLocale.getEntry('client.editConfig_save')}');

        buffer.write('\n${await Global.currentLocale.getEntry('client.editConfig_request')} ');

        final answer = ui.getInt(1, formated.length + 2, textToShow: buffer.toString());

        if (!answer.$1) {
            return;
        }

        if (answer.$2 == formated.length + 1) {
            final defaultConfig = Config.fromJson({})..repairConfig();
            await defaultConfig.writeConfig();

            fields = defaultConfig.toJson().map((k, v) => MapEntry(k, v)).entries.toList();

            await Global.updateEnvironment();

            continue;
        } else if (answer.$2 == formated.length + 2) {
            final newConfig = Config.fromJson(Map.fromEntries(fields));
            await newConfig.writeConfig();

            await Global.updateEnvironment();

            continue;
        } else {
            final index = answer.$2 - 1;
            final field = fields[index];

            final key = ConfigProperty.fromString(field.key);

            bool exit = false;
            dynamic value;

            switch (key.getType()) {

                case ConfigFieldType.int:
                    final min = key.getMin()!.toInt();
                    final max = key.getMax()!.toInt();

                    final result = ui.getInt(
                        min == -1 ? null : min, 
                        max == -1 ? null : max,
                        textToShow: '${await Global.currentLocale.getEntry('client.configEdit_fieldName')} ${await key.toFormatedString()}\n'
                                    '${await Global.currentLocale.getEntry('client.configEdit_currentValue')} ${field.value}\n'
                                    '${await Global.currentLocale.getEntry('client.configEdit_numFieldMin')} $min\n'
                                    '${await Global.currentLocale.getEntry('client.configEdit_numFieldMax')} $max\n\n'
                                    '${await Global.currentLocale.getEntry('client.configEdit_fieldRequest')} ' 
                                    '(${Global.currentConfig.getValueOrDefault(ConfigProperty.exitPhrase)} ${await Global.currentLocale.getEntry('client.requestExit')}): '
                    );

                    exit = !result.$1;
                    value = result.$2;

                break;

                case ConfigFieldType.one:
                    final min = key.getMin();
                    final max = key.getMax();

                    final result = ui.getDouble(
                        min == -1 ? null : min, 
                        max == -1 ? null : max,
                        textToShow: '${await Global.currentLocale.getEntry('client.configEdit_fieldName')} ${await key.toFormatedString()}\n'
                                    '${await Global.currentLocale.getEntry('client.configEdit_currentValue')} ${field.value}\n'
                                    '${await Global.currentLocale.getEntry('client.configEdit_numFieldMin')} $min\n'
                                    '${await Global.currentLocale.getEntry('client.configEdit_numFieldMax')} $max\n\n'
                                    '${await Global.currentLocale.getEntry('client.configEdit_fieldRequest')} ' 
                                    '(${Global.currentConfig.getValueOrDefault(ConfigProperty.exitPhrase)} ${await Global.currentLocale.getEntry('client.requestExit')}): '
                    );

                    exit = !result.$1;
                    value = result.$2;

                break;

                case ConfigFieldType.double:
                    final min = key.getMin();
                    final max = key.getMax();

                    final result = ui.getDouble(
                        min == -1 ? null : min, 
                        max == -1 ? null : max,
                        textToShow: '${await Global.currentLocale.getEntry('client.configEdit_fieldName')} ${await key.toFormatedString()}\n'
                                    '${await Global.currentLocale.getEntry('client.configEdit_currentValue')} ${field.value}\n'
                                    '${await Global.currentLocale.getEntry('client.configEdit_numFieldMin')} $min\n'
                                    '${await Global.currentLocale.getEntry('client.configEdit_numFieldMax')} $max\n\n'
                                    '${await Global.currentLocale.getEntry('client.configEdit_fieldRequest')} ' 
                                    '(${Global.currentConfig.getValueOrDefault(ConfigProperty.exitPhrase)} ${await Global.currentLocale.getEntry('client.requestExit')}): '
                    );

                    exit = !result.$1;
                    value = result.$2;

                break;

                case ConfigFieldType.string:
                    final result = ui.getStringInternally(textToShow: 
                        '${await Global.currentLocale.getEntry('client.configEdit_fieldName')} ${await key.toFormatedString()}\n'
                        '${await Global.currentLocale.getEntry('client.configEdit_currentValue')} ${field.value}\n'
                        '${await Global.currentLocale.getEntry('client.configEdit_fieldRequest')} ' 
                        '(${Global.currentConfig.getValueOrDefault(ConfigProperty.exitPhrase)} ${await Global.currentLocale.getEntry('client.requestExit')}): '
                    );

                    exit = !result.$1;
                    value = result.$2;

                break;

                case ConfigFieldType.bool:
                    final result = ui.getBool(textToShow: 
                        '${await Global.currentLocale.getEntry('client.configEdit_fieldName')} ${await key.toFormatedString()}\n'
                        '${await Global.currentLocale.getEntry('client.configEdit_currentValue')} ${field.value}\n'
                        '${await Global.currentLocale.getEntry('client.configEdit_fieldRequest')} ' 
                        '(${Global.currentConfig.getValueOrDefault(ConfigProperty.exitPhrase)} ${await Global.currentLocale.getEntry('client.requestExit')}) [y/n]: '
                    );

                    exit = !result.$1;
                    value = result.$2;

                break;

                case ConfigFieldType.language:
                    final localeList = await Locale.getLocaleNamesList();

                    StringBuffer buffer = StringBuffer();

                    buffer.writeln('${await Global.currentLocale.getEntry('client.configEdit_fieldName')} ${await key.toFormatedString()}');
                    buffer.writeln('${await Global.currentLocale.getEntry('client.configEdit_currentValue')} ${field.value}\n');

                    for (int i = 0; i < localeList.length; i++) {
                        buffer.writeln('${i + 1}) ${localeList[i]}');
                    }

                    buffer.write('\n${await Global.currentLocale.getEntry('client.configEdit_languageRequest')} ' 
                        '(${Global.currentConfig.getValueOrDefault(ConfigProperty.exitPhrase)} ${await Global.currentLocale.getEntry('client.requestExit')}): ');

                    final result = ui.getInt(1, localeList.length, textToShow: buffer.toString());

                    exit = !result.$1;
                    value = exit ? '' : localeList[result.$2 - 1];

                break;
    
            }

            if (!exit) {
                fields[index] = MapEntry(key.toJsonKey(), value);
            }
        }
    }
}

Future<World?> chooseSave({bool remoteGeneration = true}) async {                                                               
    var savesText = '1) ${await Global.currentLocale.getEntry('client.createNewSave')}\n';

    final saveDir = Directory(Global.savesDirectoryPath);
    final saveFilePaths = await saveDir.list()
        .map((s) => s.path)
        .where((p) => p.endsWith('.json'))
        .toList();
    final saveNames = saveFilePaths.map((f) => path.basenameWithoutExtension(f)).toList();

    for (int i = 1; i <= saveNames.length; i++) {
        final saveName = saveNames[i - 1];
        final end = saveName.lastIndexOf('_');
        
        savesText += '${i + 1}) ${saveName.substring(0, end == -1 ? saveName.length : end)}\n';
    }

    savesText += '\n${await Global.currentLocale.getEntry('client.saveIndexRequest')} ';

    final saveIndex = ui.getInt(1, saveNames.length + 1, textToShow: savesText);

    if (!saveIndex.$1) {
        return null;
    }

    if (saveIndex.$2 == 1) {
        final summary = await ui.getStringExternaly(textToShow: '${await Global.currentLocale.getEntry('client.newWorldSummaryRequest')} ');

        if (!summary.$1) {
            return null;
        }

        if (remoteGeneration) {
            final newWorld = await Engine.worldGeneration(summary.$2);

            if (newWorld != null) {
                newWorld.savePath = path.join(Global.savesDirectoryPath, '${newWorld.id}_${DateFormat('yyyy-MM-dd:HH-mm-ss').format(DateTime.now())}.json');

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

        final load = World.fromJson(jsonDecode(content.$2));

        return load..savePath = saveFilePaths[saveIndex.$2 - 2];
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
        final userInput = (await ui.getStringExternaly(textToShow: '> ', clearScreen: false));

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