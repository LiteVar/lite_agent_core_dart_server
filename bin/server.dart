import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import '../lib/src/config.dart';
import '../lib/src/router.dart';
import '../lib/src/middleware.dart';
import '../lib/src/util/logger.dart';


void main(List<String> args) async {
  await startServer();
}

Future<void> startServer() async {

  final Router router = Router();
  apiRoutes();
  router.mount(config.server.apiPathPrefix, apiRouter);
  Handler handler = const Pipeline()
      .addMiddleware(checkAuthorization("111"))
      .addMiddleware(logRequest())
      .addHandler(router);

  HttpServer server = await serve(handler, '192.168.2.75', config.server.port);
  logger.log(LogModule.http, "Start Server", detail: "http://${server.address.host}:${server.port}${config.server.apiPathPrefix}");
}