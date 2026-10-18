import 'dart:io';

import 'package:paluma_cli/paluma_cli.dart';

Future<void> main(List<String> args) async {
  exitCode = await PalumaCli().run(args);
}
