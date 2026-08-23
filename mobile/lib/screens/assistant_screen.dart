import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:samapoche/models/models.dart';
import 'package:samapoche/state/app_state.dart';
import 'package:samapoche/theme.dart';
import 'package:samapoche/utils/format.dart';
import 'package:samapoche/widgets/widgets.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _typing = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _send([String? text]) async {
    final msg = (text ?? _input.text).trim();
    if (msg.isEmpty || _typing) return;
    _input.clear();
    AppState.I.chat.add(ChatMessage(text: msg, fromUser: true, time: DateTime.now()));
    setState(() => _typing = true);
    _scrollDown();
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    AppState.I.chat.add(ChatMessage(text: AppState.I.aiReply(msg), fromUser: false, time: DateTime.now()));
    setState(() => _typing = false);
    _scrollDown();
  }

  void _clearChat() {
    AppState.I.clearChat();
    _scrollDown();
  }

  void _exportChat() {
    final sb = StringBuffer('SamaPoche — Export de la conversation\n');
    sb.write('Exporté le ${formatDateDetail(DateTime.now())}\n\n');
    for (final m in AppState.I.chat) {
      final who = m.fromUser ? 'Vous' : 'SamaPoche AI';
      sb.write('[$who · ${hhmm(m.time)}]\n${m.text}\n\n');
    }
    Clipboard.setData(ClipboardData(text: sb.toString())).then((_) {
      if (!mounted) return;
      showToast(context, 'Conversation exportée dans le presse-papier', ToastType.success);
    });
  }

  void _copyMsg(String text) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      if (!mounted) return;
      showToast(context, 'Message copié', ToastType.success);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = isDark ? AppDark.accent : AppColors.accent;
    final fg2 = isDark ? AppDark.fg2 : AppColors.fg2;
    final borderSoft = isDark ? AppDark.borderSoft : AppColors.borderSoft;
    final surface = isDark ? AppDark.surface : AppColors.surface;
    final meta = isDark ? AppDark.meta : AppColors.meta;
    final muted = isDark ? AppDark.muted : AppColors.muted;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.smart_toy_rounded, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('SamaPoche AI',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                          ),
                        ],
                      ),
                      Text('En ligne — Réponses instantanées', style: TextStyle(fontSize: 12, color: muted)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _clearChat,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18)),
                    child: Icon(Icons.delete_outline_rounded, size: 18, color: fg2),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _exportChat,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18)),
                    child: Icon(Icons.download_rounded, size: 18, color: fg2),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: AppState.I,
              builder: (context, _) {
                final chat = AppState.I.chat;
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  itemCount: chat.length + (_typing ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= chat.length) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: _TypingBubble(),
                        ),
                      );
                    }
                    final m = chat[i];
                    return _MessageBubble(message: m, onCopy: () => _copyMsg(m.text));
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SuggestionChip(label: 'Mon budget ce mois', onTap: () => _send('Mon budget ce mois')),
                _SuggestionChip(label: 'Mes dépenses', onTap: () => _send('Mes dépenses par catégorie')),
                _SuggestionChip(label: 'Objectif épargne', onTap: () => _send("Objectif d'épargne")),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: borderSoft))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Posez une question…',
                      hintStyle: TextStyle(fontSize: 16, color: meta),
                      filled: true,
                      fillColor: surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _send(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 8)],
                    ),
                    child: const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onCopy;
  const _MessageBubble({required this.message, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final surface = isDark ? AppDark.surface : AppColors.surface;
    final fg = isDark ? AppDark.fg : AppColors.fg;
    final accent = isDark ? AppDark.accent : AppColors.accent;
    final meta = isDark ? AppDark.meta : AppColors.meta;
    final user = message.fromUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!user) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.smart_toy_rounded, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: user ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: user ? accent : surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(user ? 20 : 4),
                      bottomRight: Radius.circular(user ? 4 : 20),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: user ? Colors.white : fg,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(hhmm(message.time), style: TextStyle(fontSize: 10, color: meta)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onCopy,
                      child: Icon(Icons.copy_rounded, size: 12, color: meta),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final surface = context.isDark ? AppDark.surface : AppColors.surface;
    final meta = context.isDark ? AppDark.meta : AppColors.meta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.3, end: 1),
                duration: Duration(milliseconds: 400 + i * 200),
                curve: Curves.easeInOut,
                builder: (_, v, child) => Opacity(
                  opacity: v,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: meta, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final surface = context.isDark ? AppDark.surface : AppColors.surface;
    final borderSoft = context.isDark ? AppDark.borderSoft : AppColors.borderSoft;
    final fg2 = context.isDark ? AppDark.fg2 : AppColors.fg2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderSoft),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: fg2)),
      ),
    );
  }
}
