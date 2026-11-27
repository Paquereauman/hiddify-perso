import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/core/logger/logger_setup.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hiddify/features/log/data/log_data_providers.dart';
import 'package:hiddify/utils/uri_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// perso : journal des erreurs, à copier ou envoyer en .txt en un geste.
///
/// Contient les avertissements et erreurs gardés en mémoire (appli et moteur VPN), du plus récent
/// au plus ancien, sous un en-tête qui situe le téléphone et la version.
class ErrorJournalPage extends StatefulWidget {
  const ErrorJournalPage({super.key});

  @override
  State<ErrorJournalPage> createState() => _ErrorJournalPageState();
}

class _ErrorJournalPageState extends State<ErrorJournalPage> {
  String _header = '';
  List<LogRecord> _records = const [];
  String _appFile = '';
  String _coreFile = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final info = await PackageInfo.fromPlatform();
    final now = DateTime.now();
    final header = StringBuffer()
      ..writeln('PandaVPN - journal d\'erreurs')
      ..writeln('Version : ${info.version} (${info.buildNumber})')
      ..writeln('Système : ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
      ..writeln('Date : ${now.toIso8601String().substring(0, 19).replaceFirst('T', ' ')}');
    final records = logRing.view(minLevel: Level.WARNING).reversed.toList();
    // fichiers gardés sur le téléphone d'une session à l'autre
    var appFile = '';
    var coreFile = '';
    if (mounted) {
      final paths = ProviderScope.containerOf(context).read(logPathResolverProvider);
      appFile = await _tail(paths.appFile(), 300);
      coreFile = await _tail(paths.coreFile(), 400, onlyProblems: true);
    }
    if (!mounted) return;
    setState(() {
      _header = header.toString();
      _records = records;
      _appFile = appFile;
      _coreFile = coreFile;
    });
  }

  /// Les [max] dernières lignes d'un fichier (seulement avertissements et erreurs si [onlyProblems]).
  static Future<String> _tail(File f, int max, {bool onlyProblems = false}) async {
    try {
      if (!await f.exists()) return '';
      var lines = await f.readAsLines();
      if (onlyProblems) {
        final re = RegExp(r'\b(WARN|WARNING|ERROR|FATAL|PANIC)\b', caseSensitive: false);
        lines = lines.where(re.hasMatch).toList();
      }
      if (lines.length > max) lines = lines.sublist(lines.length - max);
      return lines.join('\n');
    } catch (_) {
      return '';
    }
  }

  String get _text {
    final b = StringBuffer(_header)
      ..writeln()
      ..writeln('=== Cette session (avertissements et erreurs, du plus récent au plus ancien) ===');
    if (_records.isEmpty) b.writeln('Rien.');
    for (final r in _records) {
      b.writeln(formatRecord(r));
    }
    b
      ..writeln()
      ..writeln('=== Erreurs de l\'appli, toutes sessions (app.log) ===')
      ..writeln(_appFile.isEmpty ? 'Rien.' : _appFile)
      ..writeln()
      ..writeln('=== Moteur VPN : avertissements et erreurs (box.log) ===')
      ..writeln(_coreFile.isEmpty ? 'Rien.' : _coreFile);
    return b.toString();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

  Future<void> _copy() async {
    // le presse-papiers d'Android refuse les très longs textes : on garde la fin, la plus utile
    var text = _text;
    if (text.length > 60000) text = '${_header}[début coupé]\n${text.substring(text.length - 58000)}';
    try {
      await Clipboard.setData(ClipboardData(text: text));
      _toast('Journal copié : colle-le dans ton message');
    } catch (_) {
      _toast('Trop long pour le presse-papiers : utilise « Envoyer en .txt »');
    }
  }

  Future<void> _share() async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().substring(0, 16).replaceAll(':', '-');
    final file = File('${dir.path}/pandavpn-erreurs-$stamp.txt');
    await file.writeAsString(_text);
    final ok = await UriUtils.tryShareFile(
      Uri.file(file.path),
      mimeType: 'text/plain',
      subject: 'PandaVPN - journal d\'erreurs',
    );
    if (!ok && mounted) _toast('Partage annulé');
  }

  void _clear() {
    logRing.clear();
    try {
      final paths = ProviderScope.containerOf(context).read(logPathResolverProvider);
      paths.appFile().writeAsStringSync('');
    } catch (_) {}
    _reload();
    _toast('Journal effacé');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal d\'erreurs'),
        actions: [
          IconButton(tooltip: 'Actualiser', icon: const Icon(Icons.refresh_rounded), onPressed: _reload),
          IconButton(tooltip: 'Effacer', icon: const Icon(Icons.delete_outline_rounded), onPressed: _clear),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _copy,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copier'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _share,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Envoyer en .txt'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _records.isEmpty
                  ? 'Aucune erreur depuis le démarrage de l\'appli.'
                  : '${_records.length} avertissement(s) ou erreur(s), du plus récent au plus ancien.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _text,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.35),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
