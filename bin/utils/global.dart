import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;

import 'utils.dart';

class Global {
    static final programPath = Platform.script.toFilePath().endsWith('.dart') ? 
        '/home/alpha/projects/Dart/volt/.dart_tool/pub/bin/volt': 
        path.dirname(path.dirname(Platform.resolvedExecutable));

    static final logFilePath = path.join(programPath, 'log.txt');
    static final configFilePath = path.join(programPath, 'config.json');
    static final modelFilePath = path.join(programPath, 'bin', 'model.gguf');

    static final dialogExecutionFilePathWin = path.join(programPath, 'dialog.exe');
    static final dialogExecutionFilePathLinux = path.join(programPath, 'dialog');
    static final dialogTempFilePath = path.join(programPath, '_dialog_output.txt');

    static final localeDirectoryPath = path.join(programPath, 'locales');
    static final savesDirectoryPath = path.join(programPath, 'saves');

    static Config? _currentConfig;
    static Locale? _currentLocale;

    static Config get currentConfig => _currentConfig ?? Config({});
    static Locale get currentLocale => _currentLocale ?? Locale({});

    static Future<void> selfStartWithArgs(String arg) async {
        if (Platform.isLinux) {
            await Process.start('kitty', ['--', Platform.resolvedExecutable, arg]);
        } else if (Platform.isWindows) {
            await Process.start('cmd', 
                [   
                    '/c', 
                    'start', '', 
                    Platform.resolvedExecutable, arg
                ], 
                runInShell: true
            );
        }
    }

    static Future<void> updateEnvironment() async {
        _currentConfig = await Config.readConfig();
       
        if (_currentConfig != null) {
            _currentLocale = await Locale.readLocale(_currentConfig!.getValueOrDefault(ConfigProperty.language) as String);
        }

        final dir = Directory(savesDirectoryPath);

        if (!await dir.exists()) {
            await dir.create();
        }
    }

    static Future<void> onServerSetup() async {
        await Process.start('kitty', ['--', path.join(Global.programPath, 'bin', 'volt'), '--client']);
    }
}