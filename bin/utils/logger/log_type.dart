enum LogType {
    log,
    warning,
    fatal;

    @override
    String toString() {
        return switch (this) {
            LogType.log => 'LOG',
            LogType.warning => 'WARNING',
            LogType.fatal => 'FATAL',
        };
    }
}