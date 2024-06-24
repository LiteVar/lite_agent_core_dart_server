import 'dart:convert';
import 'dart:io';

import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';

part 'config.g.dart';

final Config config = initConfig();

Config initConfig() {
  String configFilePath = '${Directory.current.path}${Platform.pathSeparator}lib${Platform.pathSeparator}config${Platform.pathSeparator}config.json';
  String configJsonString = File(configFilePath).readAsStringSync();
  final Map<String, dynamic> configJson = jsonDecode(configJsonString);
  final Config config = Config.fromJson(configJson);
  return config;
}

@JsonSerializable(createToJson: false)
class Config {
  late String version;
  late Server server;
  late Log log;

  Config({required this.version, required this.server, required this.log});

  factory Config.fromJson(Map<String, dynamic> json) => _$ConfigFromJson(json);
}

@JsonSerializable(createToJson: false)
class Server {
  late String apiPathPrefix;
  late int port;

  Server({this.apiPathPrefix = "/api", this.port = 9527});

  factory Server.fromJson(Map<String, dynamic> json) => _$ServerFromJson(json);
}

class Log {
  late Level level;

  Log({this.level = Level.INFO});

  factory Log.fromJson(Map<String, dynamic> json) {
    String levelString = json['level'] as String;
    return Log(level: _convertToLevel(levelString));
  }

  static Level _convertToLevel(String level) {
    switch(level){
      case "ALL": return Level.ALL;
      case "FINEST": return Level.FINEST;
      case "FINER": return Level.FINER;
      case "FINE": return Level.FINE;
      case "CONFIG": return Level.CONFIG;
      case "INFO": return Level.INFO;
      case "WARNING": return Level.WARNING;
      case "SEVERE": return Level.SEVERE;
      case "SHOUT": return Level.SHOUT;
      case "OFF": return Level.OFF;
      default: return Level.INFO;
    }
  }

}

