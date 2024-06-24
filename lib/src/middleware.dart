import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'util/logger.dart';

// 检查 'Authorization' 头部的中间件
Middleware checkAuthorization(String validToken) {
  return (Handler innerHandler) {
    return (Request request) async {
      // 获取请求头部中的 'Authorization' 值
      final authorizationHeader = request.headers['Authorization'];
      final tokenPrefix = "Bearer ";
      // 验证 token 是否匹配
      if (authorizationHeader == null || authorizationHeader != tokenPrefix + validToken) {
        // 如果 token 不匹配，返回 '401 Unauthorized' 错误
        return Response.unauthorized('Invalid or missing authorization token');
      }

      // 如果 token 匹配，继续执行后续的处理器
      return innerHandler(request);
    };
  };
}

Middleware logRequest() {
  return (Handler innerHandler) {
    return (Request request) async {
      String method = request.method;
      String uri = request.requestedUri.toString();
      String body = await request.readAsString();
      logger.log(LogModule.http, "logRequest", detail: "[$method] $uri $body", level: Level.FINE);
      Request newRequest = request.change(body: Stream.value(utf8.encode(body)));
      return innerHandler(newRequest);
    };
  };
}