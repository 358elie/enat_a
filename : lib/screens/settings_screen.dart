import 'package:flutter/material.dart';
import '../services/prefs_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _promptCtrl;
  late int _threads;
  late int _contextSize;

  @override
  void initState() {
    super.initState();
    _promptCtrl = TextEditingController(text: PrefsService.systemPrompt);
    _threads = PrefsService.threads;
    _contextSize = PrefsService.contextSize;
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await PrefsService.setSystemPrompt(_promptCtrl.text.trim());
    await PrefsService.setThreads(_threads);
    await PrefsService.setContextSize(_contextSize);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Réglages sauvegardés')),
      );
    }
  }

  void _resetPrompt() {
    setState(() {
      _promptCtrl.text = 'You are a helpful AI assistant.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réglages'),
        actions: [
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Sauvegarder'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── System Prompt ──────────────────────────────────────────────────────
          _SectionHeader(title: 'Prompt Système', icon: Icons.smart_toy_outlined),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ce prompt est envoyé en premier à chaque conversation.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _promptCtrl,
                    maxLines: 8,
                    minLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Entrez votre prompt système ici...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _resetPrompt,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Réinitialiser'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Performance ────────────────────────────────────────────────────────
          _SectionHeader(title: 'Performance', icon: Icons.speed_outlined),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                // Threads
                ListTile(
                  title: const Text('Threads CPU'),
                  subtitle: Text(
                    '$_threads thread${_threads > 1 ? "s" : ""} — plus = plus rapide (max: 8)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: SizedBox(
                    width: 140,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _threads > 1 ? () => setState(() => _threads--) : null,
                        ),
                        Text('$_threads', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _threads < 8 ? () => setState(() => _threads++) : null,
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1, indent: 16, endIndent: 16),

                // Context size
                ListTile(
                  title: const Text('Taille du contexte'),
                  subtitle: Text(
                    '$_contextSize tokens — contexte de la conversation',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: SizedBox(
                    width: 160,
                    child: DropdownButton<int>(
                      value: _contextSize,
                      isExpanded: true,
                      onChanged: (v) => setState(() => _contextSize = v!),
                      items: const [
                        DropdownMenuItem(value: 2048, child: Text('2048')),
                        DropdownMenuItem(value: 4096, child: Text('4096')),
                        DropdownMenuItem(value: 8192, child: Text('8192')),
                        DropdownMenuItem(value: 16384, child: Text('16384')),
                        DropdownMenuItem(value: 32768, child: Text('32768')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Tokens ────────────────────────────────────────────────────────────
          _SectionHeader(title: 'Génération', icon: Icons.token_outlined),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Tokens illimités'),
                  subtitle: const Text(
                    'La génération continue jusqu\'à la fin naturelle de la réponse',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: PrefsService.maxTokens == 0,
                  onChanged: (v) async {
                    await PrefsService.setMaxTokens(v ? 0 : 512);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Model info ────────────────────────────────────────────────────────
          _SectionHeader(title: 'Modèle actuel', icon: Icons.memory_outlined),
          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(
                PrefsService.modelPath != null
                    ? PrefsService.modelPath!.split('/').last
                    : 'Aucun modèle chargé',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
              subtitle: PrefsService.modelPath != null
                  ? Text(
                      PrefsService.modelPath!,
                      style: const TextStyle(fontSize: 10),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 32),

          // ── Tips ──────────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tips_and_updates_outlined, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text('Conseils anti-crash', style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    )),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('• Utilisez 4 threads pour un bon équilibre', style: TextStyle(fontSize: 13)),
                const Text('• Contexte 4096 = stable sur la plupart des appareils', style: TextStyle(fontSize: 13)),
                const Text('• Modèles Q4_K_M recommandés (moins de RAM)', style: TextStyle(fontSize: 13)),
                const Text('• Fermez les autres apps avant de charger un modèle', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
