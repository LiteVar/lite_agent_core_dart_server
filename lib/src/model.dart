import 'package:lite_agent_core_dart/lite_agent_core.dart';

class CapabilityModel {
  late LLMConfig llmConfig;
  late String systemPrompt;
  late List<ToolRunner> toolRunnerList;

  CapabilityModel({required this.llmConfig, required this.systemPrompt, required this.toolRunnerList});
}