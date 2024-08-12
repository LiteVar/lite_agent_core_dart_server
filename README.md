
# LiteAgent core Dart Server

English · [中文](README-zh_CN.md)

LLM `AI Agent` multi session HTTP/WebSocket service

## Feature

- Support  [OpenAPI](https://github.com/djbird2046/openapi_dart)/[OpenRPC](https://github.com/djbird2046/openrpc_dart)/[OpenModbus](https://github.com/djbird2046/openmodbus_dart)/[OpenTool](https://github.com/djbird2046/opentool_dart) JSON Spec.
- Support LLM Function calling to `HTTP API`/`json-rpc 2.0 over HTTP`/`Modbus` and more custom tools.
- HTTP Server wrapper [Lite Agent core Dart](https://github.com/LiteVar/lite_agent_core_dart) 
- Base on [Lite Agent Core AgentService](https://github.com/LiteVar/lite_agent_core_dart/blob/master/lib/src/service/service.dart)(DTO included), add Controller、Router, wrapper to HTTP/WS API.

## Usage

### 1. Prepare

1. Some OpenSpec json file, according to `/example/json/open*/*.json`, which is callable.
2. Run your tool server, which is described in json file.
3. Add `.env` file in the `example` folder, and add below content in the `.env` file：
     ```properties
     baseUrl = https://xxx.xxx.com         # LLM API BaseURL
     apiKey = sk-xxxxxxxxxxxxxxxxxxxx      # LLM API ApiKey
     ```

### 2. Develop run server
1. `debug` or `run` mode run `/bin/server.dart` file `main()`

### 3. HTTP/WS API
- [HTTP API](#31-http-API)
- [WebSocket API](#32-websocket-API)
- [Typical Interaction](#33-Typical-Interaction)

#### 3.1 HTTP API
- session control command, include：
  - [/version](#get-version)：get version number, to confirm server running
  - [/init](#post-init): initial new session, server return session id
  - [/history](#get-historyidsessionid): get session messages not be cleared
  - [/stop](#get-stopidsessionid): stop session, when current message done, will not run next message
  - [/clear](#get-clearidsessionid): clear session context messages, and close websocket connection

##### BaseURL
- `http://127.0.0.1:9527/api`

##### [GET] /version
- Feature：get version number, to confirm server running
- Request params: empty
- Response body sample：
  ```json
  {
      "version": "0.1.0"
  }
  ```

##### [POST] /init
- Feature: initial new session agent
- Request body：
    - LLM config: baseUrl, apiKey, model
    - System Prompt: Agent character, ToDo/NotToDo description
    - Tools Description: openapi、openmodbus Spec. According to third APIs in Spec to set `apiKey` or net
    - Timeout：3600 seconds in default. When agent stopped, massages context will be clear
    - Sample: 
      ```json
      {
          "llmConfig": {
              "baseUrl": "<LLM API baseUrl, e.g. https://api.openai.com/v1>",
              "apiKey": "<LLM API apiKey, e.g. sk-xxxxxxxxxx>",
              "model": "<LLM API model name, e.g. gpt-3.5-turbo. And temperature、maxTokens、topP can be changed below >",
              "temperature": 0,
              "maxTokens": 4096,
              "topP": 1
          },
          "systemPrompt": "<System Prompt. LLM character, capabilities, need to help user fixed what problems>",
          "openSpecList": [
              {
                  "openSpec": "<tool spec json string, support openapi、openmodbus、openrpc>",
                  "apiKey": {
                      "type": "<basic or bearer>",
                      "apiKey": "<Third APIs apiKey>"
                  },
                  "protocol": "Support openapi, openmodbus, jsonrpcHttp"
              },
              {
                  "openSpec": "<Another spec json string, can be another protocol>",
                  "protocol": "Support openapi, openmodbus, jsonrpcHttp"
              }
          ],
          "timeoutSeconds": 3600
      }
      ```

- Response body：
    - sessionId, will be used as session websocket subscribe, stop and clear operations.
    - Sample: 
      ```json
      {
          "id": "b2ac9280-70d6-4651-bd3a-45eb81cd8c30"
      }
      ```

##### [GET] /history?id=\<sessionId\>

- Response body:
  - agent messages context as list
  - Sample:
  ```json
  [
  {
    "sessionId": "b2ac9280-70d6-4651-bd3a-45eb81cd8c30",
    "from": "system | user | agent | llm | tool",
    "to": "user | agent | llm | tool | client",
    "type": "text | imageUrl | functionCallList | toolReturn | contentList",
    "message": "<need to parse according type>",
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

##### [GET] /stop?id=\<sessionId\>

- Response body:
  - sessionId, to confirm the operation of the session
  - Sample: 
  ```json
  {
      "id": "b2ac9280-70d6-4651-bd3a-45eb81cd8c30"
  }
  ```

##### [GET] /clear?id=\<sessionId\>

- Response body:
  - sessionId, to confirm the operation of the session
  - Sample: 
  ```json
  {
      "id": "b2ac9280-70d6-4651-bd3a-45eb81cd8c30"
  }
  ```

#### 3.2 WebSocket API
- Send and subscribe session AgentMessage

##### Endpoint
- `ws://127.0.0.1:9527/api/chat?id=<sessionId>`

##### 3.2.1 alive
- client(ping) -> server: send `"ping"` to server
- client <- server(pong): respond `"pong"` to client

##### 3.2.2 client send UserMessageDto List to server
- client(\[UserMessageDto\]) -> server ：Wrap and send server
- Sample: 
```json
[
  {
    "type": "text",
    "message": "Get some tool status"
  }
]
```
```json
{
  "taskId": "Optional. For identify which task AgentMessage from. If NULL, server will create one.",
  "contentList": [
    {
      "type": "text",
      "message": "Get some tool status"
    }
  ]
}
```

##### 3.2.3 server feedback AgentMessage to client
- client <- server(AgentMessage) ：server will keep sending AgentMessage to client
- Sample:
```json
{
  "sessionId": "b2ac9280-70d6-4651-bd3a-45eb81cd8c30",
  "taskId": "0b127f1d-4667-4a52-bbcb-0b636f9a471a",
  "from": "system | user | agent | llm | tool",
  "to": "user | agent | llm | tool | client",
  "type": "text | imageUrl | functionCallList | toolReturn | contentList",
  "message": "<need to parse according type>",
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
- According `type` to parse `message`
    - text、imageUrl：
      - String
      - Sample: `"Tool result: PASS"`
    - functionCallList：
      - Struct:
      ```json
      [
          {
              "id":"<LLM respond id in function call>",
              "name":"<function name>",
              "parameters": "<LLM respond parameters in map>"
          }
      ]
      ```
      - Sample:
      ```json
      [
        {
          "id":"call_z5FK2dAfU8TXzn61IJXzRl5I",
          "name":"SomeFunction",
          "parameters": {
            "operation":"result"
          }
        }
      ]
      ```
    - toolReturn：
      - Struct: 
      ``` json
      {
        "id":"<LLM respond id in function call>",
        "result": "<JSON Map, different tools in defferent result>"
      }
      ```
      - Sample:
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
      - Struct:
      ```json
      [
        {
          "type":"text | imageUrl",
          "message":"String"
        }
      ]
      ```
      - Sample:
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
- When to=Client, message in below status:
    - `"[TASK_START]"`：agent receive user messages, and ready to run task
    - `"[TOOLS_START]"`: ready to call Tools
    - `"[TOOLS_DONE]"`: Tools return finished
    - `"[TASK_STOP]"`：agent receive stop or clear command, stop task
    - `"[TASK_DONE]"`：agent run task finished

#### 3.3 Typical Interaction

```
[/init request] {llmConfig: ..., systemPrompt:..., openSpecList: [...]}
[/init response SessionId] {id: eccdacc8-a1a8-463f-b0af-7aebc278c842, taskId: 0b127f1d-4667-4a52-bbcb-0b636f9a471a}
[After /chat connect ws, send userTaskDto] {taskId: 0b127f1d-4667-4a52-bbcb-0b636f9a471a, contentList: [{type: text, message: Get some tool status}]}
[ws push] id: eccdacc8-a1a8-463f-b0af-7aebc278c842, taskId: 0b127f1d-4667-4a52-bbcb-0b636f9a471a# 🤖AGENT -> 🔗CLIENT: [text] [TASK_START]
[ws push] id: eccdacc8-a1a8-463f-b0af-7aebc278c842, taskId: 0b127f1d-4667-4a52-bbcb-0b636f9a471a# 👤USER -> 🤖AGENT: [text] Get some tool status
[ws push] id: eccdacc8-a1a8-463f-b0af-7aebc278c842, taskId: 0b127f1d-4667-4a52-bbcb-0b636f9a471a# 🤖AGENT -> 💡LLM: [text] Get some tool status
[ws push] id: eccdacc8-a1a8-463f-b0af-7aebc278c842, taskId: 0b127f1d-4667-4a52-bbcb-0b636f9a471a# 💡LLM -> 🤖AGENT: [functionCallList] [{"id":"call_73xLVZDe70QgLHsURgY5BNT0","name":"SomeFunction","parameters":{"operation":"result"}}]
[ws push] id: eccdacc8-a1a8-463f-b0af-7aebc278c842, taskId: 0b127f1d-4667-4a52-bbcb-0b636f9a471a# 🤖AGENT -> 🔧TOOL: [functionCallList] [{"id":"call_73xLVZDe70QgLHsURgY5BNT0","name":"SomeFunction","parameters":{"operation":"result"}}]
[ws push] id: eccdacc8-a1a8-463f-b0af-7aebc278c842, taskId: 0b127f1d-4667-4a52-bbcb-0b636f9a471a# 🤖AGENT -> 🔗CLIENT: [text] [TOOLS_START]
[ws push] id: eccdacc8-a1a8-463f-b0af-7aebc278c842, taskId: 0b127f1d-4667-4a52-bbcb-0b636f9a471a# 🔧TOOL -> 🤖AGENT: [toolReturn] {"id":"call_73xLVZDe70QgLHsURgY5BNT0","result":{"statusCode":200,"body":"{\"code\":200,\"message\":\"FAIL\"}"}}
[ws push] id: eccdacc8-a1a8-463f-b0af-7aebc278c842, taskId: 0b127f1d-4667-4a52-bbcb-0b636f9a471a# 🤖AGENT -> 💡LLM: [toolReturn] {"id":"call_73xLVZDe70QgLHsURgY5BNT0","result":{"statusCode":200,"body":"{\"code\":200,\"message\":\"FAIL\"}"}}
[ws push] id: eccdacc8-a1a8-463f-b0af-7aebc278c842, taskId: 0b127f1d-4667-4a52-bbcb-0b636f9a471a# 🔧TOOL -> 🤖AGENT: [text] [TOOLS_DONE]
[ws push] id: eccdacc8-a1a8-463f-b0af-7aebc278c842, taskId: 0b127f1d-4667-4a52-bbcb-0b636f9a471a# 🤖AGENT -> 🔗CLIENT: [text] [TOOLS_DONE]
[ws push] id: eccdacc8-a1a8-463f-b0af-7aebc278c842, taskId: 0b127f1d-4667-4a52-bbcb-0b636f9a471a# 💡LLM -> 🤖AGENT: [text] Tool status: FAIL.
[ws push] id: eccdacc8-a1a8-463f-b0af-7aebc278c842, taskId: 0b127f1d-4667-4a52-bbcb-0b636f9a471a# 🤖AGENT -> 👤USER: [text] Tool status: FAIL.
[ws push] id: eccdacc8-a1a8-463f-b0af-7aebc278c842, taskId: 0b127f1d-4667-4a52-bbcb-0b636f9a471a# 🤖AGENT -> 🔗CLIENT: [text] [TASK_DONE]
[ws push] id: eccdacc8-a1a8-463f-b0af-7aebc278c842, taskId: 0b127f1d-4667-4a52-bbcb-0b636f9a471a# 🤖AGENT -> 🔗CLIENT: [text] [TASK_STOP]
[/stop request] {id: eccdacc8-a1a8-463f-b0af-7aebc278c842}
[/clear request] {id: eccdacc8-a1a8-463f-b0af-7aebc278c842}
[ws close] WebSocket connection closed
```

## Build and Run
1. Build in shell script:
    ```shell
    dart compile exe bin/server.dart -o build/lite_agent_core_dart_server
    ```
2. Then the `lite_agent_core_dart_server` file will be in `build` folder
3. Copy `config.json` file to `lite_agent_core_dart_server` same folder
4. Run in shell script:
    ```shell
    ./lite_agent_core_dart_server
    ```
5. Terminal will show:
    ```
    INFO: 2024-06-24 14:48:05.862057: PID 34567: [HTTP] Start Server - http://0.0.0.0:9527/api
    ```
6. After server running, will create `log` folder and `agent.log` file in the folder, to record server running logs.