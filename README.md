A sample command-line application with an entrypoint in `bin/`, library code
in `lib/`, and example unit test in `test/`.

static Future<String?> _sendRequestToCustomProvider(List<ChatEntry> messages) async {
        final url = Uri.parse(Global.currentConfig.getValueOrDefault(ConfigProperty.customOpenAICompatibleProviderUrl));

        final client = http.Client();

        try {
            final request = http.Request('POST', url)
                ..headers['Content-Type'] = 'application/json'
                ..headers['Authorization'] = 'Bearer ${Global.currentConfig.getValueOrDefault(ConfigProperty.customOpenAICompatibleApiKey)}'
                ..body = jsonEncode({
                    'model': Global.currentConfig.getValueOrDefault(ConfigProperty.customOpenAICompatibleModel),
                    'temperature': Global.currentConfig.getValueOrDefault(ConfigProperty.temperature),
                    'stream': true, // 🔥 КРИТИЧНО: включаем потоковую передачу данных=
                    'messages':  messages.map((m) => m.toCustomProviderChatEntry()).toList()
                });

            final response = await http.post(
                url,
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer ${Global.currentConfig.getValueOrDefault(ConfigProperty.customOpenAICompatibleApiKey)}', 
                },
                body: jsonEncode({
                    'stream': true,
                    'model': Global.currentConfig.getValueOrDefault(ConfigProperty.customOpenAICompatibleModel),
                    'temperature': Global.currentConfig.getValueOrDefault(ConfigProperty.temperature),
                    'messages': messages.map((m) => m.toCustomProviderChatEntry()).toList()
                }),
            );

            if (response.statusCode == 200) {
                final raw = jsonDecode(response.body);

                return raw['choices'][0]['message']?['content'].toString() ?? '';
            } else {
                Logger.createLog('Error while using custom provider. err code -> ${response.statusCode}', LogType.warning);

                return null;
            }
        } catch (e) {
            Logger.createLog('Network errror while using custom provider -> $e', LogType.fatal);

            return null;
        }
    }