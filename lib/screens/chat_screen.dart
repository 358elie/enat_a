import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/llm_service.dart';
import '../services/prefs_service.dart';

class ChatScreen extends StatefulWidget {
  final LlmService llmService;
  const ChatScreen({super.key, required this.llmService});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isLoadingModel = false;
  StreamSubscription<String>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Load GGUF from device ───────────────────────────────────────────────────
  Future<void> _pickModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    if (!path.endsWith('.gguf')) {
      _showSnack('Veuillez sélectionner un fichier .gguf');
      return;
    }

    setState(() => _isLoadingModel = true);
    _showSnack('Chargement du modèle...');

    final error = await widget.llmService.loadModel(path);

    setState(() => _isLoadingModel = false);

    if (error != null) {
      _showSnack('Erreur: $error', isError: true);
    } else {
      _showSnack('✓ Modèle chargé avec succès');
    }
  }

  // ── Send message ────────────────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    if (!widget.llmService.isLoaded) {
      _showSnack('Chargez d\'abord un modèle .gguf');
      return;
    }
    if (widget.llmService.isGenerating) return;

    _inputCtrl.clear();

    setState(() {
      _messages.add(ChatMessage(role: Role.user, content: text));
      _messages.add(ChatMessage(role: Role.assistant, content: '', isStreaming: true));
    });

    _scrollToBottom();

    final assistantMsg = _messages.last;

    _sub = widget.llmService.generate(_messages).listen(
      (token) {
        setState(() => assistantMsg.content += token);
        _scrollToBottom();
      },
      onDone: () {
        setState(() => assistantMsg.isStreaming = false);
      },
      onError: (e) {
        setState(() {
          assistantMsg.content += '\n\n[Erreur: $e]';
          assistantMsg.isStreaming = false;
        });
      },
    );
  }

  void _stop() {
    widget.llmService.stop();
    _sub?.cancel();
    setState(() {
      if (_messages.isNotEmpty && _messages.last.isStreaming) {
        _messages.last.isStreaming = false;
      }
    });
  }

  void _clearChat() {
    setState(() => _messages.clear());
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red[700] : null,
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoaded = widget.llmService.isLoaded;
    final isGenerating = widget.llmService.isGenerating;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Local LLM', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              isLoaded
                  ? '● ${widget.llmService.loadedModelPath!.split('/').last}'
                  : '○ Aucun modèle chargé',
              style: TextStyle(
                fontSize: 11,
                color: isLoaded ? Colors.greenAccent : Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Effacer le chat',
              onPressed: _clearChat,
            ),
          IconButton(
            icon: _isLoadingModel
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.folder_open_outlined),
            tooltip: 'Charger un modèle .gguf',
            onPressed: _isLoadingModel ? null : _pickModel,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Messages ─────────────────────────────────────────────────────────
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(isLoaded)
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) => _MessageBubble(message: _messages[i]),
                  ),
          ),

          // ── Input bar ─────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      maxLines: null,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: isLoaded ? 'Votre message...' : 'Chargez un modèle .gguf d\'abord',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                      enabled: isLoaded && !isGenerating,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: isGenerating ? _stop : (isLoaded ? _send : null),
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                      backgroundColor: isGenerating ? Colors.red[700] : null,
                    ),
                    child: Icon(isGenerating ? Icons.stop : Icons.send, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isLoaded) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.memory, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              isLoaded ? 'Prêt à discuter !' : 'Aucun modèle chargé',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isLoaded
                  ? 'Tapez votre message ci-dessous.'
                  : 'Appuyez sur l\'icône dossier pour charger un fichier .gguf depuis votre téléphone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == Role.user;
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.content.isEmpty && message.isStreaming ? '...' : message.content,
              style: TextStyle(
                color: isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            if (message.isStreaming) ...[
              const SizedBox(height: 6),
              _TypingIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
