import 'dart:io';

extension ConsoleExtension on Stdout {
    void clearScreen() {
        write('\x1B[2J\x1B[0;0H');
    }
}