import 'dart:convert';

export 'global.dart';
export 'locales.dart';
export 'console.dart';
export 'io.dart';

export 'config/config.dart';
export 'config/config_property.dart';

export 'logger/logger.dart';
export 'logger/log_type.dart';

extension ListExtension<T> on List<T> {
    bool containsOneOf(List<T> otherList) {
        return otherList.any((e) => contains(e));
    }

    List<T> getLastEntriesOfList(int count) {
        List<T> newList = [];

        for (int i = length - 1, b = 0; i >= 0; i--) {
            if (b == count) {
                break;
            }

            newList.add(this[i]);

            b++;
        }

        return newList;
    }
}

String encodeWithIndent(Map<String, dynamic> json) => JsonEncoder.withIndent('    ').convert(json);