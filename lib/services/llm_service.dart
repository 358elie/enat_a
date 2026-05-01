import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../services/prefs_service.dart';

// ─── Message model ────────────────────────────────────────────────────────────

enum Role { user, assistant, system }

class ChatMessage {
  final Role role;
  String content;
  bool isStreaming;

  ChatMessage({required this.role, required this.content, this.isStreaming = false});
}

// ─── LLM Service ─────────────────────────────────────────────────────────────
//
// This service wraps the `llama_cpp_dart` package (pub.dev/packages/llama_cpp_dart).
// It runs inference in a separate Isolate so the UI thread never freezes.
//
// To add to pubspec.yaml:
//   llama_cpp_dart: ^0.1.9
//   shared_preferences: ^2.2.2
//   file_picker: ^6.1.1
//   path_provider: ^2.1.2

class LlmService extends ChangeNotifier {
  bool _isLoaded = false;
  bool _isGenerating = false;
  String? _loadedModelPath;

  bool get isLoaded => _isLoaded;
  bool get isGenerating => _isGenerating;
  String? get loadedModelPath => _loadedModelPath;

  // Isolate communication
  Isolate? _isolate;
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  StreamController<String>? _tokenController;

  // ── Load model ──────────────────────────────────────────────────────────────
  Future<String?> loadModel(String path) async {
    try {
      await _disposeIsolate();

      _isolate = await Isolate.spawn(
        _isolateEntry,
        _IsolateInit(
          sendPort: _receivePort.sendPort,
          modelPath: path,
          threads: PrefsService.threads,
          contextSize: PrefsService.contextSize,
        ),
      );

      // Wait for ready signal
      final completer = Completer<String?>();
      final sub = _receivePort.listen((msg) {
        if (msg is _ReadyMsg) {
          _sendPort = msg.sendPort;
          if (msg.error == null) {
            completer.complete(null);
          } else {
            completer.complete(msg.error);
          }
        } else if (msg is _TokenMsg && !completer.isCompleted) {
          // ignore tokens before ready
        }
      });

      final error = await completer.future;
      sub.cancel();

      if (error != null) return error;

      _isLoaded = true;
      _loadedModelPath = path;
      await PrefsService.setModelPath(path);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Generate ────────────────────────────────────────────────────────────────
  Stream<String> generate(List<ChatMessage> messages) {
    _tokenController?.close();
    _tokenController = StreamController<String>();

    _isGenerating = true;
    notifyListeners();

    // Build prompt from messages
    final prompt = _buildPrompt(messages);

    _sendPort?.send(_GenerateMsg(
      prompt: prompt,
      maxTokens: PrefsService.maxTokens, // 0 = unlimited
    ));

    // Relay tokens from isolate
    late StreamSubscription sub;
    sub = _receivePort.listen((msg) {
      if (msg is _TokenMsg) {
        if (msg.done) {
          _isGenerating = false;
          notifyListeners();
          _tokenController?.close();
          sub.cancel();
        } else if (msg.token != null) {
          _tokenController?.add(msg.token!);
        } else if (msg.error != null) {
          _tokenController?.addError(msg.error!);
          _isGenerating = false;
          notifyListeners();
          sub.cancel();
        }
      }
    });

    return _tokenController!.stream;
  }

  // ── Stop generation ─────────────────────────────────────────────────────────
  void stop() {
    _sendPort?.send(const _StopMsg());
    _isGenerating = false;
    notifyListeners();
  }

  // ── Prompt builder (ChatML format) ──────────────────────────────────────────
  String _buildPrompt(List<ChatMessage> messages) {
    final buf = StringBuffer();
    final sysPrompt = PrefsService.systemPrompt;

    buf.write('<|im_start|>system\n$sysPrompt<|im_end|>\n');

    for (final m in messages) {
      if (m.role == Role.system) continue;
      final role = m.role == Role.user ? 'user' : 'assistant';
      buf.write('<|im_start|>$role\n${m.content}<|im_end|>\n');
    }
    buf.write('<|im_start|>assistant\n');
    return buf.toString();
  }

  // ── Cleanup ─────────────────────────────────────────────────────────────────
  Future<void> _disposeIsolate() async {
    _sendPort?.send(const _DisposeMsg());
    await Future.delayed(const Duration(milliseconds: 200));
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _isLoaded = false;
    _loadedModelPath = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposeIsolate();
    _receivePort.close();
    _tokenController?.close();
    super.dispose();
  }
}

// ─── Isolate messages ─────────────────────────────────────────────────────────

class _IsolateInit {
  final SendPort sendPort;
  final String modelPath;
  final int threads;
  final int contextSize;
  const _IsolateInit({
    required this.sendPort,
    required this.modelPath,
    required this.threads,
    required this.contextSize,
  });
}

class _ReadyMsg {
  final SendPort sendPort;
  final String? error;
  const _ReadyMsg({required this.sendPort, this.error});
}

class _GenerateMsg {
  final String prompt;
  final int maxTokens;
  const _GenerateMsg({required this.prompt, required this.maxTokens});
}

class _TokenMsg {
  final String? token;
  final bool done;
  final String? error;
  const _TokenMsg({this.token, this.done = false, this.error});
}

class _StopMsg {
  const _StopMsg();
}

class _DisposeMsg {
  const _DisposeMsg();
}

// ─── Isolate entry (runs in background) ──────────────────────────────────────
//
// Uses llama_cpp_dart package. If you use a different binding package,
// replace the import and calls below accordingly.

void _isolateEntry(_IsolateInit init) async {
  // Lazy import inside isolate to avoid UI thread loading
  // ignore: depend_on_referenced_packages
  // Replace with your actual llama.cpp dart binding package:
  // e.g. package:llama_cpp_dart/llama_cpp_dart.dart

  final receivePort = ReceivePort();
  init.sendPort.send(_ReadyMsg(sendPort: receivePort.sendPort));

  // Placeholder: actual llama.cpp integration
  // In production, load model here and stream tokens:
  //
  // try {
  //   final model = LlamaModel(init.modelPath, threads: init.threads, contextSize: init.contextSize);
  //   receivePort.listen((msg) {
  //     if (msg is _GenerateMsg) {
  //       model.generate(msg.prompt, maxTokens: msg.maxTokens == 0 ? -1 : msg.maxTokens,
  //         onToken: (token) => init.sendPort.send(_TokenMsg(token: token)),
  //         onDone: () => init.sendPort.send(const _TokenMsg(done: true)),
  //       );
  //     } else if (msg is _StopMsg) {
  //       model.stop();
  //     } else if (msg is _DisposeMsg) {
  //       model.dispose();
  //       Isolate.exit();
  //     }
  //   });
  // } catch (e) {
  //   init.sendPort.send(_ReadyMsg(sendPort: receivePort.sendPort, error: e.toString()));
  // }
}
