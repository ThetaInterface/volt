class Package {
    final String action;
    final String content;

    Package({required this.action, required this.content});

    factory Package.fromJson(Map<String, dynamic> json) {
        return Package(
            action: json['action'] as String? ?? '', 
            content: json['content'] as String? ?? ''
        );
    }

    Map<String, dynamic> toJson() {
        return {
            'action': action,
            'content': content
        };
    }
}