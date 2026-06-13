// lib/screens/whatsapp_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/whatsapp_log.dart';
import '../providers/app_providers.dart';
import '../services/whatsapp_service.dart';

class WhatsAppScreen extends ConsumerStatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  ConsumerState<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends ConsumerState<WhatsAppScreen> {
  bool _botOnline = false;
  bool _checkingBot = false;
  final _messageCtrl = TextEditingController();
  final _urlCtrl = TextEditingController(text: 'http://localhost:3000');
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _checkBot();
  }

  Future<void> _checkBot() async {
    setState(() => _checkingBot = true);
    final service = WhatsAppService(baseUrl: _urlCtrl.text.trim());
    final online = await service.healthCheck();
    if (mounted) {
      setState(() { _botOnline = online; _checkingBot = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(whatsAppLogsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Engine'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section 1: Bot Status ──
            _buildSectionTitle('Bot Status'),
            _buildBotStatusCard(),
            const SizedBox(height: 24),

            // ── Section 2: Debt Pinger ──
            _buildSectionTitle('Debt Pinger'),
            _buildDebtPingerCard(),
            const SizedBox(height: 24),

            // ── Section 3: Broadcast Composer ──
            _buildSectionTitle('Broadcast Composer'),
            _buildBroadcastCard(),
            const SizedBox(height: 24),

            // ── Section 4: Message Logs ──
            _buildSectionTitle('Recent Messages'),
            _buildLogsList(logsAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildBotStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_botOnline ? Icons.check_circle : Icons.error, color: _botOnline ? Colors.green : Colors.red, size: 20),
                const SizedBox(width: 8),
                Text(_botOnline ? 'Bot Online' : 'Bot Offline',
                    style: TextStyle(fontWeight: FontWeight.bold, color: _botOnline ? Colors.green : Colors.red)),
                if (_checkingBot) ...[const SizedBox(width: 8), const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))],
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Webhook URL',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _checkingBot ? null : _checkBot,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Check Connection'),
                ),
              ],
            ),
            if (!_botOnline)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                    'Local WhatsApp bot offline. Please check the engine state in your WSL terminal environment.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtPingerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send debt reminders to all unpaid tenants.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: const Text(
                'Template: "Dear {name} (Room {room_number}), this is a friendly reminder that your rent payment is overdue. Please settle your balance as soon as possible."',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _botOnline && !_sending ? _pingUnpaidTenants : null,
                icon: _sending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.campaign),
                label: Text(_sending ? 'Sending...' : 'Ping All Unpaid Tenants'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBroadcastCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Use {name} and {room_number} as placeholders.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _messageCtrl,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
                hintText: 'Hi {name}, please note that quiet hours start at 10 PM...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _botOnline && !_sending && _messageCtrl.text.trim().isNotEmpty ? _sendBroadcast : null,
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Send to All Tenants'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsList(AsyncValue<List<WhatsAppLog>> logsAsync) {
    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (logs) {
        if (logs.isEmpty) return const Center(child: Text('No messages sent yet', style: TextStyle(color: Colors.grey)));
        return Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.length > 20 ? 20 : logs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final log = logs[i];
              return ListTile(
                dense: true,
                leading: Icon(
                  log.isDebtReminder ? Icons.payment : Icons.campaign,
                  color: log.isSent ? Colors.green : Colors.red,
                  size: 20,
                ),
                title: Text(log.messageBody, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  '${log.messageType} • ${log.sentAt.day}/${log.sentAt.month} ${log.sentAt.hour}:${log.sentAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: log.isSent
                    ? const Icon(Icons.check_circle, color: Colors.green, size: 16)
                    : const Icon(Icons.error, color: Colors.red, size: 16),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _pingUnpaidTenants() async {
    setState(() => _sending = true);
    try {
      final repo = ref.read(supabaseRepositoryProvider);
      final unpaidTenants = await repo.getUnpaidTenants();
      final rooms = await repo.getRooms();
      final roomMap = {for (var r in rooms) r.id: r.roomNumber};

      final service = WhatsAppService(baseUrl: _urlCtrl.text.trim());
      int sent = 0, failed = 0;

      for (final t in unpaidTenants) {
        if (t.phone.isEmpty) { failed++; continue; }
        final roomNum = t.roomId != null ? roomMap[t.roomId] ?? '?' : '?';
        final msg = 'Dear ${t.name} (Room $roomNum), this is a friendly reminder that your rent payment is overdue. Please settle your balance as soon as possible.';
        final success = await sendMessage(phoneNumber: t.phone, message: msg, service: service);
        await repo.logWhatsAppMessage(
          tenantId: t.id,
          messageType: 'debt_reminder',
          messageBody: msg,
          status: success ? 'sent' : 'failed',
        );
        if (success) {
          sent++;
        } else {
          failed++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Debt reminders: $sent sent, $failed failed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendBroadcast() async {
    setState(() => _sending = true);
    try {
      final repo = ref.read(supabaseRepositoryProvider);
      final tenants = await repo.getActiveTenants();
      final rooms = await repo.getRooms();
      final roomMap = {for (var r in rooms) r.id: r.roomNumber};

      final service = WhatsAppService(baseUrl: _urlCtrl.text.trim());
      final template = _messageCtrl.text.trim();
      int sent = 0, failed = 0;

      for (final t in tenants) {
        if (t.phone.isEmpty) { failed++; continue; }
        final roomNum = t.roomId != null ? roomMap[t.roomId] ?? '?' : '?';
        final msg = template.replaceAll('{name}', t.name).replaceAll('{room_number}', roomNum);
        final success = await sendMessage(phoneNumber: t.phone, message: msg, service: service);
        await repo.logWhatsAppMessage(
          tenantId: t.id,
          messageType: 'broadcast',
          messageBody: msg,
          status: success ? 'sent' : 'failed',
        );
        if (success) {
          sent++;
        } else {
          failed++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Broadcast: $sent sent, $failed failed.')),
        );
        _messageCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<bool> sendMessage({required String phoneNumber, required String message, required WhatsAppService service}) async {
    return service.sendMessage(phoneNumber: phoneNumber, message: message);
  }
}
