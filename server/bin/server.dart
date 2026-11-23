import 'dart:io';

import 'package:args/args.dart';
import 'package:bellote_server/server_app.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '8080')
    ..addOption('host', defaultsTo: '0.0.0.0');

  final args = parser.parse(arguments);
  // Render (et la plupart des PaaS) fournissent le port à écouter via $PORT.
  final port = args.wasParsed('port')
      ? int.tryParse(args['port'] as String) ?? 8080
      : int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final host = args['host'] as String;

  final gameServer = await BelloteServer.start(host: host, port: port);
  stdout.writeln(
    'Belote server écoute sur http://${gameServer.address.host}:${gameServer.port}',
  );
  stdout.writeln(
    'WebSocket: ws://${gameServer.address.host}:${gameServer.port}/ws',
  );

  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        stdout.writeln(
          'Réseau local (${interface.name}): ws://${address.address}:${gameServer.port}/ws',
        );
      }
    }
  } catch (_) {}

  Future<void> shutdown() async {
    stdout.writeln('Arrêt du serveur...');
    await gameServer.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) => shutdown());
  ProcessSignal.sigterm.watch().listen((_) => shutdown());
}
