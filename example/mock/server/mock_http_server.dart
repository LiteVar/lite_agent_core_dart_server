import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'mock_util.dart';

/// -------- Config --------
Map<String, dynamic> config = {
  "server": {
    "ip": "0.0.0.0",
    "port": 8080,
    "apiPrefix": "/api"
  }
};

/// -------- Server --------

void main(List<String> args) async {
  await startServer();
}

Future<void> startServer() async {
  final Router router = Router();
  apiRoutes();
  router.mount((config["server"]["apiPrefix"] as String), apiRouter);
  Handler handler = const Pipeline()
      .addHandler(router);

  HttpServer server = await serve(handler, config["server"]["ip"] as String, config["server"]["port"] as int);
  print("Start Mock HTTP Server - " + "http://${server.address.host}:${server.port}${config["server"]["apiPrefix"] as String}");
}

/// -------- Router -------- ///

final Router apiRouter = Router();

void apiRoutes() {
  apiRouter.get('/count', mockController.count);
  apiRouter.post('/create', mockController.create);
  apiRouter.post('/read', mockController.read);
  apiRouter.post('/update', mockController.update);
  apiRouter.post('/delete', mockController.delete);
}

/// -------- Controller -------- ///

final MockController mockController = MockController();

class MockController {
  MockUtil mockUtil = MockUtil();

  Future<Response> count(Request request) async {
    int count = mockUtil.count();
    CountDto countDto = CountDto(count: count);
    return Response.ok(jsonEncode(countDto.toJson()));
  }

  Future<Response> create(Request request) async {
    final payload = await request.readAsString();
    final data = jsonDecode(payload);

    try {
      final TextDto textDto = TextDto.fromJson(data);

      int id = mockUtil.create(textDto.text);

      return Response.ok(jsonEncode(IdDto(id: id)));
    } on FormatException catch (e) {
      print("Response create Exception: ${e}");
      return Response.badRequest(body: e);
    } catch (e) {
      print("Response create Exception: ${e}");
      return Response.internalServerError(body: e);
    }
  }

  Future<Response> read(Request request) async {
    final payload = await request.readAsString();
    final data = jsonDecode(payload);

    try {
      final IdDto idDto = IdDto.fromJson(data);

      String text = mockUtil.read(idDto.id);

      return Response.ok(jsonEncode(TextDto(text: text)));
    } on FormatException catch (e) {
      print("Response create Exception: ${e}");
      return Response.badRequest(body: e);
    } catch (e) {
      print("Response create Exception: ${e}");
      return Response.internalServerError(body: e);
    }
  }

  Future<Response> update(Request request) async {
    final payload = await request.readAsString();
    final data = jsonDecode(payload);

    try {
      final UpdateDto updateDto = UpdateDto.fromJson(data);

      mockUtil.update(updateDto.id, updateDto.text);

      return Response.ok(jsonEncode(IdDto(id: updateDto.id)));
    } on FormatException catch (e) {
      print("Response create Exception: ${e}");
      return Response.badRequest(body: e);
    } catch (e) {
      print("Response create Exception: ${e}");
      return Response.internalServerError(body: e);
    }
  }

  Future<Response> delete(Request request) async {
    final payload = await request.readAsString();
    final data = jsonDecode(payload);

    try {
      final IdDto idDto = IdDto.fromJson(data);

      mockUtil.delete(idDto.id);

      return Response.ok(jsonEncode(IdDto(id: idDto.id)));
    } on FormatException catch (e) {
      print("Response create Exception: ${e}");
      return Response.badRequest(body: e);
    } catch (e) {
      print("Response create Exception: ${e}");
      return Response.internalServerError(body: e);
    }
  }
}

/// -------- DTO -------- ///

class CountDto {
  int count;
  CountDto({required this.count});
  factory CountDto.fromJson(Map<String, dynamic> json) => CountDto(count: json["count"]);
  Map<String, dynamic> toJson() => {"count": count};
}

class IdDto {
  int id;
  IdDto({required this.id});
  factory IdDto.fromJson(Map<String, dynamic> json) => IdDto(id: json["id"]);
  Map<String, dynamic> toJson() => {"id": id};
}

class TextDto {
  String text;
  TextDto({required this.text});
  factory TextDto.fromJson(Map<String, dynamic> json) => TextDto(text: json["text"]);
  Map<String, dynamic> toJson() => {"text": text};
}

class UpdateDto {
  int id;
  String text;
  UpdateDto({required this.id, required this.text});
  factory UpdateDto.fromJson(Map<String, dynamic> json) => UpdateDto(id: json["id"], text: json["text"]);
  Map<String, dynamic> toJson() => {"id": id, "text": text};
}