import 'dart:io';
import 'package:logging/logging.dart';
import '../config.dart';

enum LogModule {
  http,
  ws,
  agent
}

AgentLogger logger = AgentLogger(config.log.level);

class AgentLogger {
  static final AgentLogger _singleton = AgentLogger._internal();
  static Level _level = Level.INFO;

  factory AgentLogger(Level level) {
    _level = level;
    return _singleton;
  }

  Logger? _logger;
  late File _logFile;

  AgentLogger._internal() {
    // 初始化 Logger
    _logger = Logger('AgentLogger');
    Logger.root.level = _level;

    // 指定日志文件的路径
    _logFile = File('${Directory.current.path}${Platform.pathSeparator}log${Platform.pathSeparator}agent.log');
    _logFile.createSync(recursive: true); // 如果路径不存在，则创建文件

    Logger.root.onRecord.listen((record) {
      final message = '${record.level.name}: ${record.time}: PID $pid: ${record.message}';
      print(message); // 输出到控制台
      _logFile.writeAsStringSync('$message\n', mode: FileMode.append); // 追加到文件
    });
  }

  void log(LogModule module, String message, {String detail = "", Level level = Level.INFO}) {
    _logger?.log(level, "[${module.name.toUpperCase()}] $message - $detail");
  }
}