
# Dart版本Lite Agent Core的HTTP Server封装

- [Lite Agent Core的Service](https://gitlab.litevar.com:90/litevar/jan/lite_agent_core_dart/-/blob/master/lib/src/service/service.dart)（包括DTO）基础上，增加Controller、Router等，封装成HTTP/WS API，以下为LiteAgentServer交互指令集

## 1. 使用前执行
1. 需要先把 [Lite Agent Core](https://gitlab.litevar.com:90/litevar/jan/lite_agent_core_dart) 的代码pull下来到本地，假设本地路径为：`/Users/jan/Project/lite_agent_core_dart`
2. 在pubspec.yaml的lite_agent_core_dart依赖的path中，更新路径为步骤1下载的本地路径
3. 在项目根目录运行 `dart pub get` 构建依赖
4. （可选）如果需要运行`example/client_example`，需要在`example`目录增加`.env`文件，并采用如下格式填写配置：
    ```properties
    baseUrl = https://xxx.xxx.com         # 大模型接口的BaseURL
    apiKey = sk-xxxxxxxxxxxxxxxxxxxx      # 大模型接口的ApiKey
    ```

## 2. 运行server
1. `debug`或者`run`模式运行`/bin/server.dart`文件的`main()`

## 3. HTTP/WS API目录
- [HTTP命令](#4-http命令)
- [WebSocket交互](#5-websocket交互)
- [典型的交互例子](#6-典型的交互例子)

## 4. HTTP命令
- 用于session会话的控制指令，包括：
    - `/version`：版本号，用于确认server在运行
    - `/init`：初始化一个会话，server会返回一个id
    - `/history`：返回当前会话的所有message历史
    - `/stop`：中止会话，传入一个id，正在进行的message处理完后停止，后续的message不执行
    - `/clear`：清空会话，传入一个id，会清空会话的上下文和关闭websocket连接

###  BaseURL
- `http://127.0.0.1:9527/api`

### [GET] /version
- 版本号，无需任何入参，一般用于确认server在运行
- 返回样例：

  ```json
  {
      "version": "0.0.1"
  }
  ```

### [POST] /init
- 请求样例：body结构
    - 大模型设置：大模型的链接、key、模型名称
    - 预置提示词：角色、能力、目标描述
    - 能力细节描述：openapi、openmodbus文档描述。其中apiKey根据实际需要可选填写

  ```json
  {
      "llmConfig": {
          "baseUrl": "<大模型厂商的api入口，例如：https://api.openai.com/v1>",
          "apiKey": "<大模型厂商的api的Key>",
          "model": "<厂商支持的大模型名称，例如：gpt-3.5-turbo，下方的temperature、maxTokens、topP可选传入，下方为默认值>",
          "temperature": 0,
          "maxTokens": 4096,
          "topP": 1
      },
      "systemPrompt": "<预置的系统提示词，例如扮演什么角色，具有什么能力，需要帮助用户解决哪一类的问题>",
      "openSpecList": [
          {
              "openSpec": "<spec的json描述文本，目前支持的类型是openapi、openmodbus、openrpc>",
              "apiKey": {
                  "type": "<basic或bearer二选一>",
                  "apiKey": "<第三方服务的apiKey>"
              },
              "protocol": "目前支持openapi、openmodbus、jsonrpcHttp"
          },
          {
              "openSpec": "<另一段spec的json描述，可以不同类型混用>",
              "protocol": "目前支持openapi、openmodbus、jsonrpcHttp"
          }
      ],
      "timeoutSeconds": 3600
  }
  ```

- 返回样例：
    - 返回sessionId，用以后续对于该session的消息订阅、stop、clear操作

  ```json
  {
      "id": "b2ac9280-70d6-4651-bd3a-45eb81cd8c30"
  }
  ```

### [GET] /history?id=\<sessionId\>

- 返回样例：
    - 返回agent message的list

  ```json
  [
      {
          "sessionId": "b2ac9280-70d6-4651-bd3a-45eb81cd8c30",
          "from": "system、user、agent、llm、tool，五选一",
          "to": "user、agent、llm、tool、client，五选一",
          "type": "text、imageUrl、functionCallList、toolReturn，四选一",
          "message": "<泛类型，需要根据type来解析>",
          "completions": {
              "tokenUsage": {
                "promptTokens": 100,
                "completionTokens": 522,
                "totalTokens": 622
              },
              "id": "chatcmpl-9bgYkOjpdtLV0o0JugSmnNzGrRFMG",
              "model": "gpt-3.5-turbo"
           },
          "createTime": "2023-06-18T15:45:30.000+0800"
      }
  ]
  ```


### [GET] /stop?id=\<sessionId\>

- 返回样例：
    - 返回sessionId，用以确认该操作对应的session

  ```json
  {
      "id": "b2ac9280-70d6-4651-bd3a-45eb81cd8c30"
  }
  ```

### [GET] /clear?id=\<sessionId\>

- 返回样例：
    - 返回sessionId，用以确认该操作对应的session

  ```json
  {
      "id": "b2ac9280-70d6-4651-bd3a-45eb81cd8c30"
  }
  ```

## 5. WebSocket交互
- 用于session会话的消息发送和订阅

### Endpoint
- `ws://127.0.0.1:9527/api/chat?id=<sessionId>`

### 消息类型和交互顺序

#### 1. 保持连接
- client(ping) -> server: 发送`"ping"`给server
- client <- server(pong): 响应`"pong"`给client

#### 2. client发送 用户消息 到server
- client(UserMessage) -> server ：包装用户的消息给server
- 样例：

  ```json
  {
      "type": "text",
      "message": "帮我启动某某设备"
  }
  ```

#### 3. server回复 Agent消息 给client
- client <- server(AgentMessage) ：Agent系统持续推送消息给client
- 样例：

    ```json
    {
        "sessionId": "b2ac9280-70d6-4651-bd3a-45eb81cd8c30",
        "from": "system、user、agent、llm、tool，五选一",
        "to": "user、agent、llm、tool、client，五选一",
        "type": "text、imageUrl、functionCallList、toolReturn, contentList，五选一",
        "message": "<泛类型，需要根据type来解析>",
        "completions": {
          "tokenUsage": {
        	"promptTokens": 100,
        	"completionTokens": 522,
        	"totalTokens": 622
          },
          "id": "chatcmpl-9bgYkOjpdtLV0o0JugSmnNzGrRFMG",
          "model": "gpt-3.5-turbo"
        },
        "createTime": "2023-06-18T15:45:30.000+0800"
    }
    ```
- type在不同类型下的message结构
    -  text、imageUrl：
        -  直接就是`""`的String
        -  样例：`"AUT测试结果为：PASS"`
    - functionCallList：
        - 结构：

          ```json
          [
              {
                  "id":"<大模型返回的funcion call的id>",
                  "name":"<function的名称>",
                  "parameters": "<大模型返回的参数map>"
              }
          ]
          ```
        - 样例：

          ```json
          [
              {
                  "id":"call_z5FK2dAfU8TXzn61IJXzRl5I",
                  "name":"POST-AUT",
                  "parameters": {
                      "operation":"result"
                  }
              }
          ]
          ```
    -  toolReturn：
        - 结构：

          ``` json
          {
              "id":"<llm给出的call的id>",
              "result": <一个map，根据不同工具的不同情况返回不一样>
          }
          ```
        - 样例：

          ``` json
          {
              "id":"call_z5FK2dAfU8TXzn61IJXzRl5I",
              "result": {
                  "statusCode":200,
                  "body":"{\"code\":200,\"message\":\"PASS\"}"
              }
          }
          ```
    - contentList:
        - 结构：

          ```json
          [
              {
                  "type":"text，imageUrl，二选一",
                  "message":"String"
              }
          ]
          ```
        - 样例：

          ```json
          [
              {
                  "type":"text",
                  "message":"What’s in this image?"
              },
            {
                  "type":"imageUrl",
                  "message":"https://www.xxx.com/xxx.jpg"
              }
          ]
          ```
- to=Client时，message只有如下几个状态：
    - `"[TASK_START]"`：agent接收到user message，准备处理
    - `"[TASK_STOP]"`：agent接收到stop或者clear指令，停止任务
    - `"[TASK_DONE]"`：agent处理完成
    - `"[TOOLS_START]"`: 准备提交Tools执行
    - `"[TOOLS_DONE]"`: Tools执行完毕

## 6. 典型的交互例子

```
[/init请求] {llmConfig: ..., systemPrompt:..., openSpecList: [...]}
[/init返回] {id: eccdacc8-a1a8-463f-b0af-7aebc278c842}
[/chat建立ws连接后，发送userMessage] {type: text, message: 查询AUT测试结果}
[ws推送] id: eccdacc8-a1a8-463f-b0af-7aebc278c842# 🤖AGENT -> 🔗CLIENT: [text] [TASK_START]
[ws推送] id: eccdacc8-a1a8-463f-b0af-7aebc278c842# 👤USER -> 🤖AGENT: [text] 查询AUT测试结果
[ws推送] id: eccdacc8-a1a8-463f-b0af-7aebc278c842# 🤖AGENT -> 💡LLM: [text] 查询AUT测试结果
[ws推送] id: eccdacc8-a1a8-463f-b0af-7aebc278c842# 💡LLM -> 🤖AGENT: [functionCallList] [{"id":"call_73xLVZDe70QgLHsURgY5BNT0","name":"POST-AUT","parameters":{"operation":"result"}}]
[ws推送] id: eccdacc8-a1a8-463f-b0af-7aebc278c842# 🤖AGENT -> 🔧TOOL: [functionCallList] [{"id":"call_73xLVZDe70QgLHsURgY5BNT0","name":"POST-AUT","parameters":{"operation":"result"}}]
[ws推送] id: eccdacc8-a1a8-463f-b0af-7aebc278c842# 🤖AGENT -> 🔗CLIENT: [text] [TOOLS_START]
[ws推送] id: eccdacc8-a1a8-463f-b0af-7aebc278c842# 🔧TOOL -> 🤖AGENT: [toolReturn] {"id":"call_73xLVZDe70QgLHsURgY5BNT0","result":{"statusCode":200,"body":"{\"code\":200,\"message\":\"FAIL\"}"}}
[ws推送] id: eccdacc8-a1a8-463f-b0af-7aebc278c842# 🤖AGENT -> 💡LLM: [toolReturn] {"id":"call_73xLVZDe70QgLHsURgY5BNT0","result":{"statusCode":200,"body":"{\"code\":200,\"message\":\"FAIL\"}"}}
[ws推送] id: eccdacc8-a1a8-463f-b0af-7aebc278c842# 🔧TOOL -> 🤖AGENT: [text] [TOOLS_DONE]
[ws推送] id: eccdacc8-a1a8-463f-b0af-7aebc278c842# 🤖AGENT -> 🔗CLIENT: [text] [TOOLS_DONE]
[ws推送] id: eccdacc8-a1a8-463f-b0af-7aebc278c842# 💡LLM -> 🤖AGENT: [text] AUT测试结果为FAIL。
[ws推送] id: eccdacc8-a1a8-463f-b0af-7aebc278c842# 🤖AGENT -> 👤USER: [text] AUT测试结果为FAIL。
[ws推送] id: eccdacc8-a1a8-463f-b0af-7aebc278c842# 🤖AGENT -> 🔗CLIENT: [text] [TASK_DONE]
[ws推送] id: eccdacc8-a1a8-463f-b0af-7aebc278c842# 🤖AGENT -> 🔗CLIENT: [text] [TASK_STOP]
[/stop请求] {id: eccdacc8-a1a8-463f-b0af-7aebc278c842}
[/clear请求] {id: eccdacc8-a1a8-463f-b0af-7aebc278c842}
[ws关闭] WebSocket connection closed
```

## 7. Build构建
1. 命令行在项目根目录运行如下命令：
    ```shell
    dart compile exe bin/server.dart -o build/lite_agent_core_dart_server
    ```
2. 在build文件夹下，有`lite_agent_core_dart_server`文件
3. 把项目根目录的`config.json`文件复制到`lite_agent_core_dart_server`文件同一目录
4. 命令行运行，例如：
    ```shell
    ./lite_agent_core_dart_server
    ```
5. 命令行会有如下提示，即启动成功：
    ```
    INFO: 2024-06-24 14:48:05.862057: PID 34567: [HTTP] Start Server - http://0.0.0.0:9527/api
    ```
6. 运行启动后，同级目录将会出现`log`文件夹，文件夹中有`agent.log`文件，用以记录运行过程的日志