import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:dotenv/dotenv.dart';

import '../lib/src/config.dart';

String prompt = "查询AUT测试结果";

Config config = initConfig();

Dio dio = Dio(BaseOptions(baseUrl: "http://192.168.2.75:${config.server.port}${config.server.apiPathPrefix}", headers: {"Authorization": "Bearer 111"}));

Future<void> main() async {

  CapabilityDto capabilityDto = CapabilityDto(llmConfig: _buildLLMConfigDto(), systemPrompt: _buildSystemPrompt(), openSpecList: await _buildOpenSpecList(), timeoutSeconds: 20);

  print("[capabilityDto] " + capabilityDto.toJson().toString());

  SessionDto? sessionDto = await initChat(capabilityDto);

  if(sessionDto != null) {
    print("[sessionDto] " + sessionDto.toJson().toString());
    WebSocket webSocket = await connectChat(sessionDto.id, (agentMessageDto) => printAgentMessage(agentMessageDto));

    print("[webSocket] " + webSocket.toString());

    await sendUserMessage(webSocket, prompt);
    print("[prompt] " + prompt);

    await sleep(10);

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

Future<void> sleep(int seconds) async {
  for(int i = seconds; i>0; i--) {
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

Future<WebSocket> connectChat(String sessionId, onReceive(AgentMessageDto)) async {
  final String url = 'ws://192.168.2.75:${config.server.port}${config.server.apiPathPrefix}/chat?id=$sessionId';

  final WebSocket socket = await WebSocket.connect(url, headers: {"Authorization": "Bearer 111"});

  // 监听接收到的消息
  socket.listen(
    (message) {
      final payload = message as String;
      if(payload != "pong"){
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
  UserMessageDto userMessageDto = UserMessageDto(type: UserMessageType.text, message: prompt);
  socket.add(jsonEncode(userMessageDto.toJson()));
}

Future<void> sendPing(WebSocket socket) async {
  socket.add("ping");
}

Future<SessionDto?> stopChat(String sessionId) async {
  try {
    Response response = await dio.get('/stop', queryParameters: {"id": sessionId});
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
    Response response = await dio.get('/clear', queryParameters: {"id": sessionId});
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

void printAgentMessage(AgentMessageDto agentMessageDto) {
    String system = "🖥SYSTEM";
    String user = "👤USER";
    String agent = "🤖AGENT";
    String llm = "💡LLM";
    String tool = "🔧TOOL";
    String client = "🔗CLIENT";

    String message = "";
    if(agentMessageDto.type == AgentMessageType.text) message = agentMessageDto.message as String;
    if(agentMessageDto.type == AgentMessageType.imageUrl) message = agentMessageDto.message as String;
    if(agentMessageDto.type == AgentMessageType.functionCallList) {
      List<dynamic> originalFunctionCallList = agentMessageDto.message as List<dynamic>;
      List<FunctionCall> functionCallList = originalFunctionCallList.map((dynamic json){
        return FunctionCall.fromJson(json);
      }).toList();
      message = jsonEncode(functionCallList);
    }
    if(agentMessageDto.type == AgentMessageType.toolReturn)  {
      message = jsonEncode(ToolReturn.fromJson(agentMessageDto.message));
      // message = jsonEncode(agentMessageDto.message as ToolReturn);
    };

    String from = "";
    if(agentMessageDto.from == AgentRole.SYSTEM) {from = system ; message = "\n$message";}
    if(agentMessageDto.from == AgentRole.USER) from = user;
    if(agentMessageDto.from == AgentRole.AGENT) from = agent;
    if(agentMessageDto.from == AgentRole.LLM) from = llm;
    if(agentMessageDto.from == AgentRole.TOOL) from = tool;
    if(agentMessageDto.from == AgentRole.CLIENT) from = client;

    String to = "";
    if(agentMessageDto.to == AgentRole.SYSTEM) to = system;
    if(agentMessageDto.to == AgentRole.USER) to = user;
    if(agentMessageDto.to == AgentRole.AGENT) to = agent;
    if(agentMessageDto.to == AgentRole.LLM) to = llm;
    if(agentMessageDto.to == AgentRole.TOOL) to = tool;
    if(agentMessageDto.to == AgentRole.CLIENT) to = client;

    if(from.isNotEmpty && to.isNotEmpty) {
      print("#${agentMessageDto.sessionId}# $from -> $to: [${agentMessageDto.type.name}] $message");
    }
}

LLMConfigDto _buildLLMConfigDto() {
  DotEnv env = DotEnv();
  env.load(['example/.env']);
  return LLMConfigDto(
      baseUrl: env["baseUrl"]!,
      apiKey: env["apiKey"]!,
      model: "gpt-3.5-turbo"
  );
}

String _buildSystemPrompt() {
  return
    '# 角色和职能\n'
        '\n'
        '1. 你的角色是：PRM AI, 职能是：设备测试智能助手，公司介绍专员\n'
        '\n'
        '# 技能\n'
        '\n'
        '1. 可对AFT, ASS, AUT设备进行测试，可对LAS设备进行打印\n'
        '2. 可控制FCT两个抽屉分别关闭或打开，开始测试\n'
        '3. 可从MDC获取设备原始数据或傅里叶数据\n'
        '4. 可从KNLG搜索内容\n'
        '\n'
        '# 约束条件\n'
        '\n'
        '1. AFT仅当状态为"IDLE"时才能开始测试，之后可查询进度,结果或数据\n'
        '2. ASS或AUT仅当状态为"Idle"时才能开始测试，之后可查询进度,结果或数据\n'
        '3. FCT开始测试之后可获取状态和结果\n'
        '4. LAS设备状态为"Idle"可开始打印，之后可获取状态\n'
        '5. 其他信息必须使用KNLG_post工具，从结果提取message字段并显示';
}

Future<List<OpenSpecDto>> _buildOpenSpecList() async {
  String openAPIFolder = "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}json${Platform.pathSeparator}openapi";
  List<String> openAPIFileNameList = ["AFT-merge.json", "ASS-merge.json", "AUT-merge.json", "FCT-merge.json", "LAS-merge.json", "MDC-service.json"];

  List<OpenSpecDto> OpenSpecDtoList = [];
  for (String openAPIFileName in openAPIFileNameList) {
    String jsonPath = "$openAPIFolder/$openAPIFileName";
    File file = File(jsonPath);
    String jsonString = await file.readAsString();
    OpenSpecDto openSpecDto = OpenSpecDto(openSpec: jsonString, protocol: Protocol.openapi);
    OpenSpecDtoList.add(openSpecDto);
  }

  String openModbusFolder = "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}json${Platform.pathSeparator}openmodbus";
  List<String> openModbusFileNameList = ["ascii-safe-system-example.json", "rtu-lights-example.json", "tcp-air-condition-example.json"];

  for (String openModbusFileName in openModbusFileNameList) {
    String jsonPath = "$openModbusFolder/$openModbusFileName";
    File file = File(jsonPath);
    String jsonString = await file.readAsString();
    OpenSpecDto openSpecDto = OpenSpecDto(openSpec: jsonString, protocol: Protocol.openmodbus);
    OpenSpecDtoList.add(openSpecDto);
  }

  return OpenSpecDtoList;
}