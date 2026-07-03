import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/animations.dart';
import '../../common/app_feedback.dart';
import '../../common/loading_overlay.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../providers/payment_provider.dart';
import '../../services/nfc_hce_service.dart';

const _apduSelectAid = '00A4040008F0534553434F494E';
const _apduGetData = '00CA000000';

String _hexToUtf8(String hex) {
  final bytes = [
    for (var i = 0; i + 1 < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ];
  return String.fromCharCodes(bytes);
}

class PayScreen extends ConsumerStatefulWidget {
  const PayScreen({super.key});

  @override
  ConsumerState<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends ConsumerState<PayScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabCtrl;
  bool _nfcAvailable = false;
  bool _nfcDisabled = false;
  bool _nfcSupported = false;

  final bool _isIOS = NfcHceService.isIOS;
  final bool _isAndroid = NfcHceService.isAndroid;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: 1);
    WidgetsBinding.instance.addObserver(this);
    _checkNfc();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNfc();
    }
  }

  Future<void> _checkNfc() async {
    if (!_isAndroid) {
      return;
    }
    try {
      final state = await NfcHceService.getNfcState();
      if (!mounted) {
        return;
      }
      setState(() {
        _nfcAvailable = state == 'enabled';
        _nfcDisabled = state == 'disabled';
        _nfcSupported = state != 'not_supported';
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabCtrl.dispose();
    NfcHceService.stopEmitting();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payState = ref.watch(paymentProvider);

    return LoadingOverlay(
      isLoading: payState.isLoading,
      message: 'Traitement...',
      child: Scaffold(
        appBar: AppBar(
          leading: Navigator.of(context).canPop()
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.go(AppRoutes.home),
                ),
          title: const Text('Payer'),
          bottom: TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: 'Recevoir', icon: Icon(Icons.download_rounded)),
              Tab(text: 'Envoyer', icon: Icon(Icons.upload_rounded)),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_isAndroid && _nfcDisabled)
              MaterialBanner(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Icon(Icons.nfc_rounded, color: context.accent),
                content: const Text(
                  'Active le NFC pour les paiements de proximité',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                actions: [
                  TextButton(
                    onPressed: NfcHceService.openNfcSettings,
                    child: const Text(
                      'Activer',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _ReceiveTab(
                    isIOS: _isIOS,
                    nfcAvailable: _nfcAvailable,
                  ),
                  _SendTab(
                    isAndroid: _isAndroid,
                    isIOS: _isIOS,
                    nfcAvailable: _nfcAvailable,
                    nfcSupported: _nfcSupported,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiveTab extends ConsumerStatefulWidget {
  const _ReceiveTab({required this.isIOS, required this.nfcAvailable});

  final bool isIOS;
  final bool nfcAvailable;

  @override
  ConsumerState<_ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends ConsumerState<_ReceiveTab> {
  final String? _myId = Supabase.instance.client.auth.currentUser?.id;
  bool _hceActive = false;

  @override
  void initState() {
    super.initState();
    _syncHce();
  }

  @override
  void didUpdateWidget(_ReceiveTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.nfcAvailable != oldWidget.nfcAvailable) {
      _syncHce();
    }
  }

  Future<void> _syncHce() async {
    if (_myId == null) {
      return;
    }
    if (!widget.isIOS && widget.nfcAvailable) {
      await NfcHceService.startEmitting(_myId!);
      if (mounted) {
        setState(() => _hceActive = true);
      }
    } else {
      await NfcHceService.stopEmitting();
      if (mounted) {
        setState(() => _hceActive = false);
      }
    }
  }

  @override
  void dispose() {
    NfcHceService.stopEmitting();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_myId == null) {
      return const Center(child: Text('Non connecté'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (_hceActive) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: context.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: context.accent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.nfc_rounded, size: 18, color: context.accent),
                  const SizedBox(width: 6),
                  Text(
                    'NFC actif · approche l’envoyeur',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            _hceActive
                ? 'Ou montre ce QR à l’envoyeur'
                : 'Montre ce QR pour recevoir un paiement',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                  blurRadius: 16,
                ),
              ],
            ),
            child: QrImageView(
              data: _myId!,
              version: QrVersions.auto,
              size: 220,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'L’envoyeur choisit le montant de son côté',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _SendTab extends ConsumerStatefulWidget {
  const _SendTab({
    required this.isAndroid,
    required this.isIOS,
    required this.nfcAvailable,
    required this.nfcSupported,
  });

  final bool isAndroid;
  final bool isIOS;
  final bool nfcAvailable;
  final bool nfcSupported;

  @override
  ConsumerState<_SendTab> createState() => _SendTabState();
}

class _SendTabState extends ConsumerState<_SendTab> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _nfcScanning = false;
  bool _showQrScanner = false;
  bool _sending = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }
    return true;
  }

  Future<void> _onIdScanned(String raw) async {
    final uuidRe = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    if (!uuidRe.hasMatch(raw)) {
      if (mounted) {
        AppFeedback.warning(
          context,
          'Ce QR code n\'est pas un compte SES Coin.',
        );
      }
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;

    setState(() => _sending = true);
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('display_name, username')
          .eq('id', raw)
          .maybeSingle();

      if (!mounted) {
        return;
      }
      if (profile == null) {
        AppFeedback.error(context, 'Compte introuvable.');
        setState(() => _sending = false);
        return;
      }

      final tx = await ref.read(paymentProvider.notifier).sendTo(
            recipientId: raw,
            amount: amount,
            paymentMethod: 'qr',
            description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
          );

      if (mounted) {
        _showSuccess(
          tx.amount,
          profile['display_name'] as String? ?? profile['username'] as String?,
        );
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.error(context, e);
        setState(() => _sending = false);
      }
    }
  }

  void _showSuccess(double amount, String? name) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PaymentSuccessDialog(
        amount: amount,
        name: name,
        onDone: () {
          Navigator.pop(ctx);
          setState(() {
            _sending = false;
            _amountCtrl.clear();
            _descCtrl.clear();
          });
        },
      ),
    );
  }

  Future<void> _startNfcScan() async {
    if (!_validateForm()) {
      return;
    }
    setState(() => _nfcScanning = true);
    try {
      await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 30),
        iosAlertMessage: 'Approche le téléphone du destinataire',
      );

      final selResp = await FlutterNfcKit.transceive(_apduSelectAid);
      if (!selResp.toUpperCase().endsWith('9000')) {
        await FlutterNfcKit.finish(iosErrorMessage: 'Tag SES Coin non reconnu');
        if (mounted) {
          setState(() => _nfcScanning = false);
        }
        return;
      }

      final dataResp = await FlutterNfcKit.transceive(_apduGetData);
      if (!dataResp.toUpperCase().endsWith('9000')) {
        await FlutterNfcKit.finish(iosErrorMessage: 'Erreur de lecture');
        if (mounted) {
          setState(() => _nfcScanning = false);
        }
        return;
      }

      final id = _hexToUtf8(dataResp.substring(0, dataResp.length - 4));
      await FlutterNfcKit.finish(
        iosAlertMessage: 'Destinataire détecté !',
      );
      if (mounted) {
        setState(() => _nfcScanning = false);
        await _sendViaNfc(id);
      }
    } catch (e) {
      try {
        await FlutterNfcKit.finish();
      } catch (_) {}
      if (mounted) {
        setState(() => _nfcScanning = false);
        final msg = e.toString();
        if (!msg.contains('timeout') && !msg.contains('cancel')) {
          AppFeedback.error(context, 'NFC : $msg');
        }
      }
    }
  }

  Future<void> _stopNfcScan() async {
    try {
      await FlutterNfcKit.finish();
    } catch (_) {}
    if (mounted) {
      setState(() => _nfcScanning = false);
    }
  }

  Future<void> _sendViaNfc(String recipientId) async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;

    setState(() => _sending = true);
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('display_name, username')
          .eq('id', recipientId)
          .maybeSingle();

      if (!mounted) {
        return;
      }
      if (profile == null) {
        AppFeedback.error(context, 'Compte introuvable.');
        setState(() => _sending = false);
        return;
      }

      final tx = await ref.read(paymentProvider.notifier).sendTo(
            recipientId: recipientId,
            amount: amount,
            paymentMethod: 'nfc',
            description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
          );

      if (mounted) {
        _showSuccess(
          tx.amount,
          profile['display_name'] as String? ?? profile['username'] as String?,
        );
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.error(context, e);
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showQrScanner) {
      return _buildQrScanner();
    }

    final canNfc = widget.isAndroid && widget.nfcAvailable;
    final showUnsupportedMessage = widget.isAndroid && !widget.nfcSupported;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Montant à envoyer',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: '0.00',
                suffixText: 'SC',
              ),
              validator: (value) {
                final number =
                    double.tryParse(value?.replaceAll(',', '.') ?? '');
                if (number == null || number <= 0) {
                  return 'Montant invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                hintText: 'Description (optionnelle)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 32),
            if (canNfc) ...[
              if (_nfcScanning) ...[
                const Center(child: _NfcPulse()),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'En attente du destinataire…',
                    style: TextStyle(color: context.accent),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _stopNfcScan,
                    child: const Text('Annuler NFC'),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _startNfcScan,
                    icon: const Icon(Icons.nfc_rounded),
                    label: const Text('Payer via NFC'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('ou', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: (canNfc ? TextButton.icon : ElevatedButton.icon)(
                onPressed: _sending
                    ? null
                    : () {
                        if (_validateForm()) {
                          setState(() => _showQrScanner = true);
                        }
                      },
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Payer via QR Code'),
              ),
            ),
            if (showUnsupportedMessage) ...[
              const SizedBox(height: 12),
              const Text(
                'Cet appareil Android ne supporte pas le NFC. Le QR est utilisé.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            if (_sending) ...[
              const SizedBox(height: 32),
              Center(
                child: CircularProgressIndicator(color: context.accent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQrScanner() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            final raw = capture.barcodes.firstOrNull?.rawValue;
            if (raw != null && !_sending) {
              setState(() => _showQrScanner = false);
              _onIdScanned(raw);
            }
          },
        ),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: context.accent, width: 2.5),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: SafeArea(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              onPressed: () => setState(() => _showQrScanner = false),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Retour'),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Indicateur NFC pulsant ─────────────────────────────────────────────────────

class _NfcPulse extends StatefulWidget {
  const _NfcPulse();

  @override
  State<_NfcPulse> createState() => _NfcPulseState();
}

class _NfcPulseState extends State<_NfcPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (!AppMotion.reduce) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return SizedBox(
      width: 120,
      height: 120,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (final phase in [0.0, 0.5])
                _ring(((_controller.value + phase) % 1.0), accent),
              child!,
            ],
          );
        },
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.nfc_rounded, size: 34, color: accent),
        ),
      ),
    );
  }

  Widget _ring(double t, Color accent) {
    return Container(
      width: 64 + t * 56,
      height: 64 + t * 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: accent.withValues(alpha: (1 - t) * 0.45),
          width: 2,
        ),
      ),
    );
  }
}

// ── Dialogue de paiement réussi ────────────────────────────────────────────────

class _PaymentSuccessDialog extends StatelessWidget {
  const _PaymentSuccessDialog({
    required this.amount,
    required this.name,
    required this.onDone,
  });

  final double amount;
  final String? name;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AppMotion.duration(const Duration(milliseconds: 600)),
              curve: Curves.elasticOut,
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppTheme.positive.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.positive.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 42,
                  color: AppTheme.positive,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Paiement effectué !',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            CountUpAmount(
              value: amount,
              duration: const Duration(milliseconds: 550),
              builder: (context, animated) => Text(
                '${animated.toStringAsFixed(2)} SC',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: context.accent,
                ),
              ),
            ),
            if (name != null) ...[
              const SizedBox(height: 4),
              Text(
                'envoyés à $name',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDone,
                child: const Text('Parfait !'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
