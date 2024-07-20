import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeiTalk',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ChatPage(),
    );
  }
}

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  WebSocketChannel? channel;
  bool isConnected = false;
  bool isMatched = false;
  bool _isAtBottom = true;
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange) {
      setState(() {
        _isAtBottom = true;
      });
    } else {
      setState(() {
        _isAtBottom = false;
      });
    }
  }

  void _connectWebSocket() {
    final wsUrl = kIsWeb
        ? 'wss://change11jwebsocket.zapto.org/chat'
        : 'wss://change11jwebsocket.zapto.org/chat';
    print("Connecting to WebSocket: $wsUrl");

    try {
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      print("WebSocket connection established");

      setState(() {
        isConnected = true;
      });

      channel!.stream.listen(
        (message) {
          print("Received message: $message");
          _handleIncomingMessage(message);
        },
        onError: (error) {
          print('WebSocket error: $error');
          _handleConnectionError();
        },
        onDone: () {
          print('WebSocket connection closed');
          _handleConnectionClosed();
        },
      );
    } catch (e) {
      print("Error connecting to WebSocket: $e");
      _handleConnectionError();
    }
  }

  void _handleIncomingMessage(dynamic message) {
    print("Handling message: $message");
    setState(() {
      if (message == "已連線") {
        isMatched = true;
        print("Match found!");
      } else if (message == "對方已離開") {
        isMatched = false;
        print("Partner disconnected");
      } else {
        _messages.add(Message(message.toString(), false));
        _scrollToBottomIfNeeded();
      }
    });
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty && isMatched) {
      print("Sending message: ${_controller.text}");
      channel!.sink.add(_controller.text);
      setState(() {
        _messages.add(Message(_controller.text, true));
      });
      _controller.clear();
      _scrollToBottomIfNeeded();
    }
    _focusNode.requestFocus(); // 保持焦點
  }

  void _scrollToBottomIfNeeded() {
    if (_isAtBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _disconnect() {
    print("Disconnecting WebSocket");
    channel?.sink.close();
    setState(() {
      isConnected = false;
      isMatched = false;
      _messages.clear();
    });
  }

  void _handleConnectionError() {
    print("Handling connection error");
    setState(() {
      isConnected = false;
      isMatched = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('連接錯誤，請稍後重試')),
    );
  }

  void _handleConnectionClosed() {
    print("Handling connection closed");
    setState(() {
      isConnected = false;
      isMatched = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('連接已關閉')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WeiTalk'),
        actions: [
          IconButton(
            icon: Icon(isConnected
                ? Icons.no_accounts_outlined
                : Icons.connect_without_contact),
            onPressed: isConnected ? _disconnect : _connectWebSocket,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Text("連接狀態: ${isConnected ? '已連接' : '未連接'}"),
          Text("匹配狀態: ${isMatched ? '已匹配' : '未匹配'}"),
          Expanded(
            child: isConnected
                ? isMatched
                    ? ListView.builder(
                        controller: _scrollController,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return MessageBubble(message: _messages[index]);
                        },
                      )
                    : Center(child: Text('等待配對中...'))
                : Center(child: Text('點擊右上角按鈕連線')),
          ),
          if (isConnected && isMatched)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: '輸入訊息',
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    channel?.sink.close();
    _controller.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

class Message {
  final String text;
  final bool isSentByMe;

  Message(this.text, this.isSentByMe);
}

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          message.isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        decoration: BoxDecoration(
          color: message.isSentByMe ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(message.text),
      ),
    );
  }
}
