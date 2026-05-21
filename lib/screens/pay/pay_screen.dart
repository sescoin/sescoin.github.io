import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    if (state == AppLifecycleState.resumed) _checkNfc();
  }

  Future<void> _checkNfc() async {
    if (!_isAndroid) return;
    try {
      final state = await NfcHceService.getNfcState();
      if (!mounted) return;
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
            indicatorColor: AppTheme.gold,
            labelColor: AppTheme.gold,
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
                leading: const Icon(Icons.nfc_rounded, color: AppTheme.gold),
                content: const Text(
                  'Active le NFC pour les paiements de proximit\u00E9',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                actions: [
                  TextButton(
                    onPressed: NfcHceService.openNfcSettings,
                    child: const Text(
                      'Activer',
                      style: TextStyle(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.w700,
                      ),
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
    if (widget.nfcAvailable != oldWidget.nfcAvailable) _syncHce();
  }

  Future<void> _syncHce() async {
    if (_myId == null) return;
    if (!widget.isIOS && widget.nfcAvailable) {
      await NfcHceService.startEmitting(_myId!);
      if (mounted) setState(() => _hceActive = true);
    } else {
      await NfcHceService.stopEmitting();
      if (mounted) setState(() => _hceActive = false);
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
      return const Center(child: Text('Non connect\u00E9'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (_hceActive) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.gold.withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.nfc_rounded, size: 18, color: AppTheme.gold),
                  SizedBox(width: 6),
                  Text(
                    'NFC actif \u00B7 approche l\u2019envoyeur',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.gold,
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
                ? 'Ou montre ce QR \u00E0 l\u2019envoyeur'
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
            'L\u2019envoyeur choisit le montant de son c\u00F4t\u00E9',
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
    if (!_formKey.currentState!.validate()) return false;
    return true;
  }

  Future<void> _onIdScanned(String raw) async {
    final uuidRe = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    if (!uuidRe.hasMatch(raw)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR invalide : ce n\u2019est pas un compte SES Coin'),
          ),
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

      if (!mounted) return;
      if (profile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte introuvable')),
        );
        setState(() => _sending = false);
        return;
      }

      final tx = await ref.read(paymentProvider.notifier).sendTo(
            recipientId: raw,
            amount: amount,
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _sending = false);
      }
    }
  }

  void _showSuccess(double amount, String? name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Paiement effectu\u00E9 !'),
        content: Text(
          '${amount.toStringAsFixed(2)} SC envoy\u00E9s${name != null ? ' \u00E0 $name' : ''}',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _sending = false;
                _amountCtrl.clear();
                _descCtrl.clear();
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _startNfcScan() async {
    if (!_validateForm()) return;
    setState(() => _nfcScanning = true);
    try {
      await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 30),
        iosAlertMessage: 'Approche le t\u00E9l\u00E9phone du destinataire',
      );

      final selResp = await FlutterNfcKit.transceive(_apduSelectAid);
      if (!selResp.toUpperCase().endsWith('9000')) {
        await FlutterNfcKit.finish(iosErrorMessage: 'Tag SES Coin non reconnu');
        if (mounted) setState(() => _nfcScanning = false);
        return;
      }

      final dataResp = await FlutterNfcKit.transceive(_apduGetData);
      if (!dataResp.toUpperCase().endsWith('9000')) {
        await FlutterNfcKit.finish(iosErrorMessage: 'Erreur de lecture');
        if (mounted) setState(() => _nfcScanning = false);
        return;
      }

      final id = _hexToUtf8(dataResp.substring(0, dataResp.length - 4));
      await FlutterNfcKit.finish(
        iosAlertMessage: 'Destinataire d\u00E9tect\u00E9 !',
      );
      if (mounted) {
        setState(() => _nfcScanning = false);
        await _onIdScanned(id);
      }
    } catch (e) {
      try {
        await FlutterNfcKit.finish();
      } catch (_) {}
      if (mounted) {
        setState(() => _nfcScanning = false);
        final msg = e.toString();
        if (!msg.contains('timeout') && !msg.contains('cancel')) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('NFC : $msg')));
        }
      }
    }
  }

  Future<void> _stopNfcScan() async {
    try {
      await FlutterNfcKit.finish();
    } catch (_) {}
    if (mounted) setState(() => _nfcScanning = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showQrScanner) return _buildQrScanner();

    final canNfc = widget.isAndroid && widget.nfcAvailable;
    final showUnavailableMessage = !widget.isAndroid;
    final showUnsupportedMessage = widget.isAndroid && !widget.nfcSupported;
    final unavailableMessage = kIsWeb
        ? 'Sur la web app, le paiement se fait via QR Code.'
        : widget.isIOS
            ? 'Sur iPhone, le paiement se fait via QR Code.'
            : 'Le paiement NFC est disponible uniquement sur Android.';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Montant \u00E0 envoyer',
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
              validator: (v) {
                final n = double.tryParse(v?.replaceAll(',', '.') ?? '');
                if (n == null || n <= 0) return 'Montant invalide';
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
                const Center(
                  child: Icon(
                    Icons.nfc_rounded,
                    size: 56,
                    color: AppTheme.gold,
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'En attente du destinataire...',
                    style: TextStyle(color: AppTheme.gold),
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
            if (showUnavailableMessage || showUnsupportedMessage) ...[
              const SizedBox(height: 12),
              Text(
                showUnsupportedMessage
                    ? 'Cet appareil Android ne supporte pas le NFC. Le QR est utilis\u00E9.'
                    : unavailableMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            if (_sending) ...[
              const SizedBox(height: 32),
              const Center(
                child: CircularProgressIndicator(color: AppTheme.gold),
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
              border: Border.all(color: AppTheme.gold, width: 2.5),
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
