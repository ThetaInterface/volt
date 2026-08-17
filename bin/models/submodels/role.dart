enum Role {
    system,
    user,
    assistant;

    static Role from(String string) {
        return switch (string) {
            'system' => Role.system,
            'user' => Role.user,
            'assistant' => Role.assistant,
            _ => throw UnsupportedError('Unexpected role entry \'$string\'')
        };
    }

    @override
    String toString() {
        return switch (this) {
          Role.system => 'system',
          Role.user => 'user',
          Role.assistant => 'assistant',
        };
    }
}