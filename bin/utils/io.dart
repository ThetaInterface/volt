import 'dart:io';

import 'utils.dart';

Future<(bool, String)> read(String path, {bool deleteAfter = false}) async {
    final file = File(path);

    if (!await file.exists()) {
        Logger.createLog('File \'$path\' doesn\'t exist', LogType.log);

        return (false, '');
    }

    try {
        final result = (true, await file.readAsString());

        if (deleteAfter) {
            await file.delete();
        }

        return result;
    } catch (e) {
        Logger.createLog('Unexpected error while reading of \'$path\' -> $e', LogType.fatal);

        rethrow;
    }
}
 
Future<void> write(String path, {String content = '', FileMode mode = FileMode.writeOnly, bool flush = true}) async {
    final file = File(path);

    try {
        await file.writeAsString(content, mode: mode, flush: flush);
    } catch (e) {
        Logger.createLog('Unexpected error error while writing to \'$path\' -> $e', LogType.fatal);

        rethrow;
    }
}