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
    } else {
        for (String arg in arguments) {
            final lower = arg.toLowerCase();

            if (lower == '--server') {
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
}

Future<void> report() async {
    final w = World.fromJson({ 
            'currentTime': Time.fromJson({}).toJson(),
            'actors': [ Actor.fromJson({ 'id': 'testActor' }).toJson() ],
            'locations': [ Location.fromJson({ 'id': 'testLocation' }).toJson() ] 
        });

    w.applyStates([
        {
            'type': 'addHistory',
            'id' : 'test',
            'content': 'test'
        },
        {
            'type': 'addHistory',
            'id' : 'test1',
            'content': 'test1'
        },
        {
            'type': 'removeHistory',
            'id': 'test1'
        },
        {
            'type': 'addMemory',
            'actorId': 'testActor',
            'id': 'testMemory',
            'content': 'testMemory'
        },
        {
            'type': 'addMemory',
            'actorId': 'testActor',
            'id': 'testMemory1',
            'content': 'testMemory1'
        },
        {
            'type': 'removeMemory',
            'actorId': 'testActor',
            'id': 'testMemory'
        }
    ]);

    await write(path.join(Global.savesDirectoryPath, 'structure.json'), content: encodeWithIndent(w.toJson()));
}
