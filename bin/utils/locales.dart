import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

import 'utils.dart';

class Locale {
    final Map<String, String> _entries;

    Locale(this._entries);

    Future<String> getName() async {
        if (!_entries.containsKey('localeName')) {
            await Logger.createLog('Unkown language', LogType.warning);

            return '';
        }

        return _entries['localeName']!;
    }

    Future<String> getEntry(String entryName) async {
        if (!_entries.containsKey(entryName)) {
            await Logger.createLog('\'$entryName\' entry was not found in \'${await getName()}\' locale', LogType.warning);

            return 'ENTRY_WASNOT_FOUND';
        }

        return _entries[entryName]!;
    }

    static Future<List<String>> getLocaleNamesList() async {
        final localeDir = Directory(Global.localeDirectoryPath);

        if (!localeDir.existsSync()) {
            await Logger.createLog('Locales weren\'t found', LogType.fatal);

            throw FileSystemException('No locales found');
        }

        final locales = localeDir.listSync()
            .where((file) => file.path.endsWith('.json'))
            .map((file) => path.basenameWithoutExtension(file.path))
            .toList();    

        if (locales.isEmpty) {
            await Logger.createLog('Locales weren\'t found', LogType.fatal);

            throw FileSystemException('No locales found');
        }

        return locales;
    }

    static Future<Locale?> readLocale(String localeName) async {
        final data = await read(path.join(Global.localeDirectoryPath, '$localeName.json'));

        if (!data.$1) {
            await Logger.createLog('Locale \'$localeName\' wasn\'t found', LogType.warning);

            return null;
        }

        Map<String, dynamic> content = jsonDecode(data.$2);

        if (!content.containsKey('localeName')) {
            await Logger.createLog('Locale \'$localeName\' doesn\'t contain \'localeName\' property', LogType.warning);

            return null;
        }

        final newEntries = content.entries.map((entry) => MapEntry(entry.key, entry.value as String));
        return Locale(Map.fromEntries(newEntries));
    }
}