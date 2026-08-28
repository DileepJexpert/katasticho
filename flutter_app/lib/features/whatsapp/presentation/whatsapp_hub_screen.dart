import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../../../routing/app_router.dart';
import '../../contacts/presentation/contact_picker_sheet.dart';
import '../data/whatsapp_models.dart';
import '../data/whatsapp_repository.dart';

class WhatsAppHubScreen extends ConsumerStatefulWidget {
  const WhatsAppHubScreen({super.key});

  @override
  ConsumerState<WhatsAppHubScreen> createState() => _WhatsAppHubScreenState();
}

class _WhatsAppHubScreenState extends ConsumerState<WhatsAppHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Bot & Document Automation'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.smart_toy_outlined), text: 'Bot Simulator'),
            Tab(icon: Icon(Icons.chat_outlined), text: 'Message Logs'),
            Tab(icon: Icon(Icons.settings_outlined), text: 'Gateway Setup'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(whatsappMessagesProvider);
              ref.invalidate(whatsappSettingsProvider);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _BotSimulatorTab(),
          _MessageLogsTab(),
          _GatewaySettingsTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1: INTERACTIVE BOT SIMULATOR
// ─────────────────────────────────────────────────────────────────────────────

class _ChatMessage {
  final String text;
  final bool isUser;
  final String time;
  final String? intent;
  final String? docType;
  final String? relatedDocId;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
    this.intent,
    this.docType,
    this.relatedDocId,
  });
}

class _BotSimulatorTab extends ConsumerStatefulWidget {
  const _BotSimulatorTab();

  @override
  ConsumerState<_BotSimulatorTab> createState() => _BotSimulatorTabState();
}

class _BotSimulatorTabState extends ConsumerState<_BotSimulatorTab> {
  Map<String, dynamic>? _selectedContact;
  final _phoneCtl = TextEditingController(text: '919876543210');
  final _msgCtl = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text: '👋 Welcome to the Interactive WhatsApp Bot Tester!\n'
          'Pick a customer contact above or test with the sample number.\n'
          'Try typing "MENU", "1", "STATEMENT", "PAY", or "ORDER 10 Crocin 650".',
      isUser: false,
      time: 'Just now',
      intent: 'SYSTEM',
    ),
  ];

  @override
  void dispose() {
    _phoneCtl.dispose();
    _msgCtl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _msgCtl.text).trim();
    if (text.isEmpty) return;

    final now = TimeOfDay.now().format(context);
    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: true,
        time: now,
      ));
      _isSending = true;
      if (presetText == null) _msgCtl.clear();
    });

    _scrollToBottom();

    try {
      final req = BotSimulationRequestPayload(
        contactId: _selectedContact?['id']?.toString(),
        message: text,
        fromPhone: _phoneCtl.text.trim(),
      );

      final reply = await ref.read(whatsappRepositoryProvider).simulateBot(req);

      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          text: reply.replyText,
          isUser: false,
          time: TimeOfDay.now().format(context),
          intent: reply.intent,
          docType: reply.docType,
          relatedDocId: reply.relatedDocId,
        ));
      });
      ref.invalidate(whatsappMessagesProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          text: '⚠️ Error sending message: $e',
          isUser: false,
          time: TimeOfDay.now().format(context),
          intent: 'ERROR',
        ));
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Contact & Phone Selector Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.md, vertical: KSpacing.sm),
          color: KColors.bgApp,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () async {
                    final picked = await showContactPicker(context, contactType: 'CUSTOMER');
                    if (picked != null) {
                      setState(() {
                        _selectedContact = picked;
                        final phone = picked['phone'] ?? picked['mobile'];
                        if (phone != null) _phoneCtl.text = phone.toString();
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: KColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 18, color: KColors.primary),
                        KSpacing.hGapSm,
                        Expanded(
                          child: Text(
                            _selectedContact?['displayName']?.toString() ??
                                _selectedContact?['name']?.toString() ??
                                'Pick Customer Contact',
                            style: KTypography.bodySmall.copyWith(
                              fontWeight: _selectedContact != null ? FontWeight.w600 : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_selectedContact != null)
                          GestureDetector(
                            onTap: () => setState(() => _selectedContact = null),
                            child: const Icon(Icons.close, size: 16, color: KColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                flex: 2,
                child: KTextField(
                  label: 'Sender Phone',
                  controller: _phoneCtl,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Quick Preset Action Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.md, vertical: 6),
          child: Row(
            children: [
              _PresetChip(label: '👋 MENU', onTap: () => _sendMessage('MENU')),
              _PresetChip(label: '1️⃣ Balance & Dues', onTap: () => _sendMessage('1')),
              _PresetChip(label: '2️⃣ Statement', onTap: () => _sendMessage('2')),
              _PresetChip(label: '3️⃣ Pay (UPI / Link)', onTap: () => _sendMessage('3')),
              _PresetChip(label: '4️⃣ Order 10 Crocin 650', onTap: () => _sendMessage('ORDER 10 Crocin 650')),
            ],
          ),
        ),
        const Divider(height: 1),

        // Chat Message Stream
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(KSpacing.md),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return _ChatBubble(message: msg);
            },
          ),
        ),

        // Typing / Sending Indicator
        if (_isSending)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.md, vertical: 4),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                KSpacing.hGapSm,
                Text('WhatsApp Bot is typing...', style: KTypography.caption.copyWith(color: KColors.textSecondary)),
              ],
            ),
          ),

        // Input Field Bar
        Container(
          padding: const EdgeInsets.all(KSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: const Border(top: BorderSide(color: KColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtl,
                  decoration: const InputDecoration(
                    hintText: 'Type a message (e.g. MENU, BALANCE, ORDER 5 Dolo)...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              KSpacing.hGapSm,
              IconButton.filled(
                onPressed: _isSending ? null : () => _sendMessage(),
                icon: const Icon(Icons.send_rounded),
                tooltip: 'Send to WhatsApp Bot',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: KTypography.caption.copyWith(fontWeight: FontWeight.w600)),
        onPressed: onTap,
        backgroundColor: KColors.bgApp,
        side: const BorderSide(color: KColors.border),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isUser
              ? KColors.primary.withValues(alpha: 0.12)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isUser ? KColors.primary.withValues(alpha: 0.3) : KColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser && message.intent != null) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.smart_toy, size: 14, color: KColors.primary),
                  KSpacing.hGapXs,
                  Text(
                    'BOT • ${message.intent}',
                    style: KTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: KColors.primary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              KSpacing.vGapXs,
            ],
            SelectableText(
              message.text,
              style: KTypography.bodyMedium.copyWith(
                height: 1.35,
              ),
            ),
            if (message.docType == 'SALES_ORDER' && message.relatedDocId != null) ...[
              KSpacing.vGapSm,
              InkWell(
                onTap: () => context.go('${Routes.salesOrders}/${message.relatedDocId}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: KColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: KColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.open_in_new, size: 14, color: KColors.success),
                      KSpacing.hGapXs,
                      Text('View Drafted Sales Order', style: KTypography.caption.copyWith(color: KColors.success, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
            KSpacing.vGapXs,
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                message.time,
                style: KTypography.caption.copyWith(color: KColors.textHint, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2: MESSAGE LOGS & DELIVERY AUDIT
// ─────────────────────────────────────────────────────────────────────────────

class _MessageLogsTab extends ConsumerWidget {
  const _MessageLogsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(whatsappMessagesProvider);

    return messagesAsync.when(
      loading: () => const KLoading(),
      error: (err, _) => KErrorView(
        message: 'Failed to load WhatsApp message logs: $err',
        onRetry: () => ref.invalidate(whatsappMessagesProvider),
      ),
      data: (messages) {
        if (messages.isEmpty) {
          return const KEmptyState(
            icon: Icons.mark_chat_read_outlined,
            title: 'No WhatsApp Messages Recorded',
            subtitle: 'Outgoing document sends and inbound bot messages will audit here.',
          );
        }

        return ListView.separated(
          padding: KSpacing.pagePadding,
          itemCount: messages.length,
          separatorBuilder: (_, __) => KSpacing.vGapSm,
          itemBuilder: (context, i) {
            final m = messages[i];
            final isInbound = m.direction == 'INBOUND';
            final isSent = m.status == 'SENT' || m.status == 'RECEIVED';

            return KCard(
              padding: const EdgeInsets.all(KSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isInbound ? Icons.call_received : Icons.call_made,
                            size: 16,
                            color: isInbound ? KColors.primary : KColors.success,
                          ),
                          KSpacing.hGapXs,
                          Text(
                            m.recipient,
                            style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
                          ),
                          KSpacing.hGapSm,
                          KStatusChip(
                            status: isSent ? 'SENT' : m.status,
                            label: m.status,
                          ),
                        ],
                      ),
                      Text(
                        m.docType,
                        style: KTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: KColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (m.body != null && m.body!.isNotEmpty) ...[
                    KSpacing.vGapXs,
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: KColors.bgApp,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        m.body!,
                        style: KTypography.bodySmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  KSpacing.vGapXs,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (m.providerMessageId != null)
                        Text(
                          'ID: ${m.providerMessageId}',
                          style: KTypography.mono(fontSize: 11, color: KColors.textSecondary),
                        )
                      else if (m.errorMessage != null)
                        Text(
                          'Error: ${m.errorMessage}',
                          style: KTypography.caption.copyWith(color: KColors.error),
                        )
                      else
                        const SizedBox.shrink(),
                      if (m.sentAt != null)
                        Text(
                          m.sentAt!.split('T').first,
                          style: KTypography.caption.copyWith(color: KColors.textHint),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3: GATEWAY & WEBHOOK SETTINGS
// ─────────────────────────────────────────────────────────────────────────────

class _GatewaySettingsTab extends ConsumerStatefulWidget {
  const _GatewaySettingsTab();

  @override
  ConsumerState<_GatewaySettingsTab> createState() => _GatewaySettingsTabState();
}

class _GatewaySettingsTabState extends ConsumerState<_GatewaySettingsTab> {
  final _phoneIdCtl = TextEditingController();
  final _apiKeyCtl = TextEditingController();
  final _customUrlCtl = TextEditingController();
  bool _enabled = false;
  bool _autoSendReceipt = false;
  String _provider = 'META';
  bool _isSaving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _phoneIdCtl.dispose();
    _apiKeyCtl.dispose();
    _customUrlCtl.dispose();
    super.dispose();
  }

  void _populate(WhatsAppSettingsModel s) {
    if (_loaded) return;
    _loaded = true;
    _enabled = s.enabled;
    _autoSendReceipt = s.autoSendReceipt;
    _provider = s.provider;
    _phoneIdCtl.text = s.phoneNumberId ?? '';
    _customUrlCtl.text = s.customUrl ?? '';
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final body = {
        'whatsapp.enabled': _enabled.toString(),
        'whatsapp.provider': _provider,
        'whatsapp.phone_number_id': _phoneIdCtl.text.trim(),
        'whatsapp.auto_send_receipt': _autoSendReceipt.toString(),
        'whatsapp.custom_url': _customUrlCtl.text.trim(),
      };
      if (_apiKeyCtl.text.trim().isNotEmpty) {
        body['whatsapp.api_key'] = _apiKeyCtl.text.trim();
      }

      await ref.read(whatsappRepositoryProvider).updateSettings(body);
      ref.invalidate(whatsappSettingsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp Gateway configuration saved successfully!'),
          backgroundColor: KColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save settings: $e'),
          backgroundColor: KColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(whatsappSettingsProvider);

    return settingsAsync.when(
      loading: () => const KLoading(),
      error: (err, _) => KErrorView(
        message: 'Failed to load WhatsApp settings: $err',
        onRetry: () => ref.invalidate(whatsappSettingsProvider),
      ),
      data: (settings) {
        _populate(settings);

        return ListView(
          padding: KSpacing.pagePadding,
          children: [
            // Inbound Webhook Integration Card
            KCard(
              padding: const EdgeInsets.all(KSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Inbound WhatsApp Webhook URL', style: KTypography.labelLarge),
                  KSpacing.vGapXs,
                  Text(
                    'Paste this URL into your Meta WhatsApp Cloud API / Aggregator Webhooks configuration dashboard.',
                    style: KTypography.caption.copyWith(color: KColors.textSecondary),
                  ),
                  KSpacing.vGapSm,
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: KColors.bgApp,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: KColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            settings.webhookUrl ?? '/api/v1/whatsapp/webhook/...',
                            style: KTypography.mono(fontSize: 12),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          tooltip: 'Copy Webhook URL',
                          onPressed: () {
                            if (settings.webhookUrl != null) {
                              Clipboard.setData(ClipboardData(text: settings.webhookUrl!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Webhook URL copied to clipboard')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  KSpacing.vGapSm,
                  Row(
                    children: [
                      Text('Verify Token: ', style: KTypography.caption),
                      SelectableText(
                        settings.verifyToken ?? '-',
                        style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            KSpacing.vGapMd,

            // Cloud API Credentials Form
            KCard(
              padding: const EdgeInsets.all(KSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gateway & Credentials', style: KTypography.labelLarge),
                  KSpacing.vGapMd,

                  SwitchListTile(
                    title: const Text('Enable WhatsApp Gateway'),
                    subtitle: const Text('Activate real-time document sends & automated bot replies'),
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(),

                  SwitchListTile(
                    title: const Text('Auto-Send POS Cash Receipts'),
                    subtitle: const Text('Automatically dispatch WhatsApp receipt PDF upon counter checkout'),
                    value: _autoSendReceipt,
                    onChanged: (v) => setState(() => _autoSendReceipt = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  KSpacing.vGapSm,

                  DropdownButtonFormField<String>(
                    initialValue: _provider,
                    decoration: const InputDecoration(labelText: 'Provider Gateway'),
                    items: const [
                      DropdownMenuItem(value: 'META', child: Text('Meta WhatsApp Cloud API (Official)')),
                      DropdownMenuItem(value: 'CUSTOM', child: Text('Custom Webhook Aggregator / Gupshup')),
                    ],
                    onChanged: (v) => setState(() => _provider = v!),
                  ),
                  KSpacing.vGapSm,

                  if (_provider == 'META') ...[
                    KTextField(
                      label: 'Phone Number ID *',
                      hint: 'e.g. 109876543210987',
                      controller: _phoneIdCtl,
                    ),
                    KSpacing.vGapSm,
                    KTextField(
                      label: 'Meta Access Token (System User / Permanent)',
                      hint: settings.apiKeySet ? '•••••••••••••••• (Configured)' : 'Paste EAAG... access token',
                      controller: _apiKeyCtl,
                      obscureText: true,
                    ),
                  ] else ...[
                    KTextField(
                      label: 'Custom Webhook POST URL *',
                      hint: 'https://api.aggregator.com/whatsapp/send',
                      controller: _customUrlCtl,
                    ),
                    KSpacing.vGapSm,
                    KTextField(
                      label: 'Authorization API Key',
                      hint: settings.apiKeySet ? '••••••••••••••••' : 'Bearer token / API key',
                      controller: _apiKeyCtl,
                      obscureText: true,
                    ),
                  ],
                  KSpacing.vGapLg,

                  KButton(
                    label: _isSaving ? 'Saving Configuration...' : 'Save Settings',
                    icon: Icons.save,
                    isLoading: _isSaving,
                    onPressed: _save,
                    fullWidth: true,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
