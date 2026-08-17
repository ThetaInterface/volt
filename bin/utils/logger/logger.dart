import 'dart:io';

import '../utils.dart';

class Logger {
    static Future<void> createLog(String message, LogType level) async {
        final logFilePath = Global.logFilePath;
        await rotate(logFilePath);

        await write(logFilePath, content: '[${DateTime.now()}] ($level) ${message.trim()}\n', 
            mode: FileMode.append, flush: true);
    }

    static Future<void> rotate(String logFilePath) async {
        if (Global.currentConfig.getValueOrDefault(ConfigProperty.logRotation)) {
            final data = await read(logFilePath);

            if (data.$1) {
                final lines = data.$2.split('\n');

                if (lines.length > Global.currentConfig.getValueOrDefault(ConfigProperty.logRotationLimit)) {
                    await write(logFilePath);
                }
            }
        }
    }
}