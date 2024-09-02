import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dotenv/dotenv.dart';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:lite_agent_core_dart_server/src/config.dart';
import 'listener.dart';

Config config = initConfig();

Dio dio = Dio(BaseOptions(
  baseUrl:
  "http://127.0.0.1:${config.server.port}${config.server.apiPathPrefix}",
  // headers: {"Authorization": "Bearer <KEY>"}
));



Future<void> main() async {

  DotEnv env = DotEnv();env.load(['example/.env']);LLMConfigDto llmConfig = LLMConfigDto(baseUrl: env["baseUrl"]!, apiKey: env["apiKey"]!, model: "gpt-4o-mini");

  String systemPrompt = "You play the role of a tool caller. You can help me decide which tool to call to complete the task according to my requirements. You can only call one tool at a time. \n\nYou support the following tools:\n\n 1. Translation\n 2. Add, delete, modify and query tools";
  String prompt = "Find the text with ID 0 and translate it into Chinese.";

  SessionDto? sessionDto1 = await _buildTextAgent();
  SessionDto? sessionDto2 = await _buildToolAgent();

  if(sessionDto1 == null || sessionDto2 == null) {
    print("Init sub session failed.");
    return;
  }

    CapabilityDto capabilityDto = CapabilityDto(llmConfig: llmConfig, systemPrompt: systemPrompt,
        sessionList: [sessionDto1, sessionDto2]
    );

    SessionDto? sessionDto = await initChat(capabilityDto);

  if (sessionDto != null) {
    print("[sessionDto] " + sessionDto.toJson().toString());
    WebSocket webSocket = await connectChat(sessionDto.id, (agentMessageDto) => listen(agentMessageDto));

    print("[webSocket] " + webSocket.toString());

    await sendUserMessage(webSocket, prompt);
    print("[prompt] " + prompt);

    await sleep(30);

    await sendPing(webSocket);
    print("[ping]");

    await sleep(2);

    SessionDto? stopSessionDto = await stopChat(sessionDto.id);
    print("[stopSessionDto] " + stopSessionDto!.toJson().toString());

    await sleep(5);

    SessionDto? clearSessionDto = await clearChat(sessionDto.id, webSocket);
    print("[clearSessionDto] " + clearSessionDto!.toJson().toString());
  }
}

Future<SessionDto?> _buildTextAgent() async {
  DotEnv env = DotEnv();env.load(['example/.env']);LLMConfigDto llmConfig = LLMConfigDto(baseUrl: env["baseUrl"]!, apiKey: env["apiKey"]!, model: "gpt-4o-mini");

  String systemPrompt = "Playing as a translator, knowing how to translate between languages.";

  CapabilityDto capabilityDto = CapabilityDto(llmConfig: llmConfig, systemPrompt: systemPrompt);
  return await initChat(capabilityDto);
}

Future<SessionDto?> _buildToolAgent() async {
  DotEnv env = DotEnv();env.load(['example/.env']);LLMConfigDto llmConfig = LLMConfigDto(baseUrl: env["baseUrl"]!, apiKey: env["apiKey"]!, model: "gpt-4o-mini");

  String openAPIFolder = "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}mock${Platform.pathSeparator}server";
  List<String> openAPIFileNameList = [
    "mock_openapi.json"
  ];

  List<OpenSpecDto> openSpecDtoList = [];
  for (String openAPIFileName in openAPIFileNameList) {
    String jsonPath = "$openAPIFolder${Platform.pathSeparator}$openAPIFileName";
    File file = File(jsonPath);
    String jsonString = await file.readAsString();
    OpenSpecDto openSpecDto = OpenSpecDto(openSpec: jsonString, protocol: Protocol.OPENAPI);
    openSpecDtoList.add(openSpecDto);
  }

  String systemPrompt = "A storage management tool that knows how to add, delete, modify, and query my texts.";

  CapabilityDto capabilityDto = CapabilityDto(llmConfig: llmConfig, systemPrompt: systemPrompt, openSpecList: openSpecDtoList);

  return await initChat(capabilityDto);
}

Future<void> sleep(int seconds) async {
  for (int i = seconds; i > 0; i--) {
    print(i);
    await Future.delayed(Duration(seconds: 1));
  }
}

Future<SessionDto?> initChat(CapabilityDto capabilityDto) async {
  try {
    Response response = await dio.post('/init', data: capabilityDto.toJson());
    final payload = response.data as String;
    final data = jsonDecode(payload);
    SessionDto sessionDto = SessionDto.fromJson(data);
    print("[initChat->RES] " + sessionDto.toJson().toString());
    return sessionDto;
  } catch (e) {
    print(e);
  }
  return null;
}

Future<WebSocket> connectChat(
    String sessionId, onReceive(AgentMessageDto)) async {
  final String url = 'ws://127.0.0.1:${config.server.port}${config.server.apiPathPrefix}/chat?id=$sessionId';

  final WebSocket socket = await WebSocket.connect(
    url,
    // headers: {"Authorization": "Bearer <KEY>"}
  );

  socket.listen((message) {
      final payload = message as String;
      if (payload != "pong") {
        final data = jsonDecode(payload);
        AgentMessageDto agentMessageDto = AgentMessageDto.fromJson(data);
        onReceive(agentMessageDto);
      } else {
        print("[pong]");
      }
    },
    onDone: () {
      print('WebSocket connection closed');
    },
    onError: (error) {
      print('WebSocket error: $error');
    },
    cancelOnError: true,
  );

  return socket;
}

Future<void> sendUserMessage(WebSocket socket, String prompt) async {
  UserMessageDto userMessageDto = UserMessageDto(type: UserMessageDtoType.text, message: prompt);
  UserTaskDto userTaskDto = UserTaskDto(contentList: [userMessageDto]);
  socket.add(jsonEncode(userTaskDto.toJson()));
}

Future<void> sendPing(WebSocket socket) async {
  socket.add("ping");
}

Future<SessionDto?> stopChat(String sessionId) async {
  try {
    Response response =
    await dio.get('/stop', queryParameters: {"id": sessionId});
    final payload = response.data as String;
    final data = jsonDecode(payload);
    SessionDto sessionDto = SessionDto.fromJson(data);
    return sessionDto;
  } catch (e) {
    print(e);
  }
  return null;
}

Future<SessionDto?> clearChat(String sessionId, WebSocket socket) async {
  try {
    Response response =
    await dio.get('/clear', queryParameters: {"id": sessionId});
    final payload = response.data as String;
    final data = jsonDecode(payload);
    SessionDto sessionDto = SessionDto.fromJson(data);
    await socket.close();
    return sessionDto;
  } catch (e) {
    print(e);
  }
  return null;
}