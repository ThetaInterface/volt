import 'dart:convert';

import 'utils/utils.dart';
import 'server.dart';
import 'client.dart' as client;


import 'package:path/path.dart' as path;
import 'models/models.dart';
  
void main(List<String> arguments) async {
    final config = (await Config.readConfig())..repairConfig();
    await config.writeConfig();

    await Global.updateEnvironment();

    if (arguments.isEmpty) {
        while (true) {
            await client.menu();
        }

        //server.setupLocaly(initializeClient: true);
        //server.createChatSession('Testing ai model on rx6600');
    } else {
        for (String arg in arguments) {
            final lower = arg.toLowerCase();

            if (lower == '--remote-server') {
                await Server.setup();  
            } else if (lower == '--test') {
                await test();
            } else if (lower == '--report') {
                await report();
            }
        }
    }
}

Future<void> test() async {
    final world = World.fromJson(jsonDecode((await read(path.join(Global.savesDirectoryPath, "world_void.json"))).$2));
    final playerAction = Map<String, dynamic>.from(jsonDecode((await read(path.join(Global.programPath, 'player_action.json'))).$2));
    final localEvent = Map<String, dynamic>.from(jsonDecode((await read(path.join(Global.programPath, 'final_event.json'))).$2));

    world.applyChanges(playerAction);
    world.applyChanges(localEvent);
}

Future<void> report() async {
    await write(path.join(Global.savesDirectoryPath, 'structure.json'), content: encodeWithIndent(
        World.fromJson({ 
            'actors': [ Actor.fromJson({}).toJson() ],
            'locations': [ Location.fromJson({}).toJson() ] 
        }).toJson()
    ));
}
