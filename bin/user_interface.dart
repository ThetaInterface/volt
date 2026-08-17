import 'dart:io';

import 'utils/utils.dart';

(bool, int) getNumber(final int min, final int max, {String textToShow = '', final bool nextLine = false, final bool disableExit = false}) {
    final exitPhrase = Global.currentConfig.getValueOrDefault(ConfigProperty.exitPhrase);

    while (true) {
        stdout.clearScreen();

        if (nextLine) {
            stdout.writeln(textToShow);
        } else {
            stdout.write(textToShow);
        }

        final userInput = stdin.readLineSync() ?? '';

        if (userInput.trim() == exitPhrase && !disableExit) {
            return (false, 0);
        }

        final number = int.tryParse(userInput.trim());

        if (number != null) {
            if (number >= min && number <= max) {
                return (true, number);
            }
        }
    }
}

(bool, bool) getBool({String textToShow = '', final bool nextLine = false, final bool disableExit = false}) {
    final exitPhrase = Global.currentConfig.getValueOrDefault(ConfigProperty.exitPhrase);

    while (true) {
        stdout.clearScreen();

        if (nextLine) {
            stdout.writeln(textToShow);
        } else {
            stdout.write(textToShow);
        }

        final userInput = stdin.readLineSync()?.trim() ?? '';

        if (userInput == exitPhrase && !disableExit) {
            return (false, false);
        }

        final result = switch (userInput.toLowerCase()) {
            'y' => (true, true),
            '1' => (true, true),

            'n' => (true, false),
            '0' => (true, false),
            
            _ => (false, false)
        };

        if (result.$1) {
            return result;
        }
    }
}

Future<(bool, String)> getString({String textToShow = '', final bool nextLine = false, final bool clearScreen = true, final bool disableExit = false}) async {
    final exitPhrase = Global.currentConfig.getValueOrDefault(ConfigProperty.exitPhrase) as String;

    while (true) {
        if (clearScreen) {
            stdout.clearScreen();
        }
        
        if (nextLine) {
            stdout.writeln(textToShow);
        } else {
            stdout.write(textToShow);
        }

        final userInput = await _getInput() ?? exitPhrase;

        if (userInput.trim() == exitPhrase && !disableExit) {
            return (false, '');
        }

        return (true, userInput.trim());
    }
}

Future<String?> _getInput({String? title}) async {
    String windowTitle;

    if (title != null) {
        windowTitle = title;
    } else {
        windowTitle = await Global.currentLocale.getEntry('client.getInputTitle');
    }

    try {
        final String dialogPath;

        if (Platform.isWindows) {
            dialogPath = Global.dialogExecutionFilePathWin;
        } else if (Platform.isMacOS || Platform.isLinux) {
            dialogPath = Global.dialogExecutionFilePathLinux;
        } else {
            dialogPath = "err";
        }

        final process = await Process.start(dialogPath, [
            '--title', windowTitle,  
            '--save-btn', await Global.currentLocale.getEntry('client.getInputDone'),
            '--cancel-btn', await Global.currentLocale.getEntry('client.getInputCancel'),
            '--placeholder', await Global.currentLocale.getEntry('client.getInputPlaceholder')
        ]);

        await process.exitCode;

        final result = await read(Global.dialogTempFilePath, deleteAfter: true);

        if (result.$1) {
            return result.$2;
        } else {
            return null;
        }
    } on ProcessException catch (e) {
        Logger.createLog('Dialog missing execution file -> $e', LogType.warning);

        return null;
    } catch (e) {
        Logger.createLog('Unexpected error while requesting user input -> $e', LogType.warning);

        return null;
    }
}