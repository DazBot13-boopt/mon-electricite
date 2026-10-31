import 'package:flutter/material.dart';

import 'api.dart';
import 'design.dart';

/// Écran d'administration des clients, abonnements et factures.
///
/// Toutes les opérations restent soumises aux contrôles RLS de Supabase.
class AdminScreen extends StatefulWidget {
  final Api api;

  const AdminScreen({super.key, required this.api});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  Json? _overview;
  String? _error;
  int _section = 0;
  bool _loading = true;
  bool _refreshing = false;
  bool _saving = false;

  List<Json> get _profiles => _rows('profiles');
  List<Json> get _subscriptions => _rows('subscriptions');
  List<Json> get _invoices => _rows('invoices');
  List<Json> get _auditLogs => _rows('audit_logs');

  List<Json> _rows(String key) {
    final rows = _overview?[key];
    if (rows is! List) return <Json>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      if (_overview == null) _loading = true;
    });
    try {
      final result = await widget.api.getAdminOverview();
      if (!mounted) return;
      setState(() {
        _overview = Map<String, dynamic>.from(result as Map);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _errorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  String _errorMessage(Object error) {
    final message = error.toString().trim();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  String _value(dynamic value, {String fallback = '—'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Actif';
      case 'closed':
        return 'Fermé';
      case 'suspended':
        return 'Suspendu';
      case 'pending_verification':
        return 'En attente de validation';
      case 'paid':
        return 'Payée';
      case 'paid_test':
        return 'Payée · TEST';
      case 'due':
        return 'À payer';
      case 'overdue':
        return 'En retard';
      case 'cancelled':
        return 'Annulée';
      default:
        return status.isEmpty ? 'Non défini' : status;
    }
  }

  String _subscriptionName(String? id) {
    if (id == null) return 'Abonnement inconnu';
    for (final subscription in _subscriptions) {
      if (subscription['id']?.toString() == id) {
        return '${_value(subscription['label'])} · ${_value(subscription['reference'])}';
      }
    }
    return 'Abonnement · $id';
  }

  Future<void> _mutate(
      Future<void> Function() operation, String success) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await operation();
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _errorMessage(e));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_errorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editSubscription([Json? subscription]) async {
    final values = await showDialog<Json>(
      context: context,
      builder: (context) => _SubscriptionEditor(
        profiles: _profiles,
        subscription: subscription,
      ),
    );
    if (values == null || !mounted) return;
    await _mutate(() async {
      if (subscription == null) {
        await widget.api.createAdminSubscription(
          ownerId: values['ownerId'] as String,
          reference: values['reference'] as String,
          label: values['label'] as String,
          serviceAddress: values['serviceAddress'] as String,
          meterNumber: values['meterNumber'] as String?,
        );
      } else {
        await widget.api.updateAdminSubscription(
          id: subscription['id'].toString(),
          ownerId: values['ownerId'] as String,
          reference: values['reference'] as String,
          label: values['label'] as String,
          serviceAddress: values['serviceAddress'] as String,
          meterNumber: values['meterNumber'] as String?,
          status: values['status'] as String,
        );
      }
    }, subscription == null ? 'Abonnement créé.' : 'Abonnement modifié.');
  }

  Future<void> _editInvoice([Json? invoice]) async {
    // Une facture payée reste consultable, mais ne peut pas être modifiée.
    if (invoice?['status']?.toString().toLowerCase() == 'paid') return;
    final values = await showDialog<Json>(
      context: context,
      builder: (context) => _InvoiceEditor(
        subscriptions: _subscriptions,
        invoice: invoice,
      ),
    );
    if (values == null || !mounted) return;
    await _mutate(() async {
      if (invoice == null) {
        await widget.api.createAdminInvoice(
          subscriptionId: values['subscriptionId'] as String,
          periodLabel: values['periodLabel'] as String,
          amountXof: values['amountXof'] as int,
          dueDate: values['dueDate'] as String?,
          externalReference: values['externalReference'] as String?,
        );
      } else {
        final status = values['status'].toString();
        if (status.toLowerCase() == 'paid') {
          throw StateError('Une facture ne peut pas être marquée comme payée.');
        }
        await widget.api.updateAdminInvoice(
          id: invoice['id'].toString(),
          periodLabel: values['periodLabel'] as String,
          amountXof: values['amountXof'] as int,
          dueDate: values['dueDate'] as String?,
          externalReference: values['externalReference'] as String?,
          status: status,
        );
      }
    }, invoice == null ? 'Facture créée.' : 'Facture modifiée.');
  }

  void _selectSection(int index) => setState(() => _section = index);

  Widget _navigation({required bool extended}) {
    const destinations = <NavigationRailDestination>[
      NavigationRailDestination(
        icon: Icon(Icons.people_outline_rounded),
        selectedIcon: Icon(Icons.people_rounded),
        label: Text('Clients'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.electrical_services_outlined),
        selectedIcon: Icon(Icons.electrical_services_rounded),
        label: Text('Abonnements'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long_rounded),
        label: Text('Factures'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.history_rounded),
        label: Text('Journal'),
      ),
    ];
    return NavigationRail(
      selectedIndex: _section,
      onDestinationSelected: _selectSection,
      labelType: extended
          ? NavigationRailLabelType.all
          : NavigationRailLabelType.selected,
      extended: extended,
      destinations: destinations,
    );
  }

  Widget _mobileNavigation() => NavigationBar(
        selectedIndex: _section,
        onDestinationSelected: _selectSection,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Clients',
          ),
          NavigationDestination(
            icon: Icon(Icons.electrical_services_outlined),
            selectedIcon: Icon(Icons.electrical_services_rounded),
            label: 'Abonnements',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Factures',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'Journal',
          ),
        ],
      );

  Widget _summaryCards() {
    final cards = <Widget>[
      _SummaryCard(
        title: 'Clients',
        count: _profiles.length,
        icon: Icons.people_outline_rounded,
        tint: const Color(0xFFEAF1FA),
      ),
      _SummaryCard(
        title: 'Abonnements',
        count: _subscriptions.length,
        icon: Icons.electrical_services_outlined,
        tint: const Color(0xFFFFF3D5),
      ),
      _SummaryCard(
        title: 'Factures',
        count: _invoices.length,
        icon: Icons.receipt_long_outlined,
        tint: const Color(0xFFE6F4EC),
      ),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 760 ? 3 : 1;
      const spacing = 12.0;
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children:
            cards.map((card) => SizedBox(width: width, child: card)).toList(),
      );
    });
  }

  Widget _sectionHeading(String title, String subtitle, {Widget? action}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 12),
            action,
          ],
        ],
      );

  Widget _clientsSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading('Clients', 'Comptes présents dans l’espace client.'),
          const SizedBox(height: 20),
          if (_profiles.isEmpty)
            const _EmptyState(
              icon: Icons.people_outline_rounded,
              message: 'Aucun client à afficher.',
            )
          else
            ..._profiles.map((profile) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Surface(
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFE9F1FC),
                          child:
                              Icon(Icons.person_outline_rounded, color: blue),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _value(profile['display_name'],
                                    fallback: 'Client sans nom'),
                                style: const TextStyle(
                                  color: ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _value(profile['email'],
                                    fallback: 'E-mail non renseigné'),
                                style:
                                    const TextStyle(fontSize: 13, color: muted),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_value(profile['role'], fallback: '')
                                  .isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'Rôle : ${_value(profile['role'])}',
                                  style: const TextStyle(
                                      fontSize: 12, color: muted),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      );

  Widget _subscriptionsSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Abonnements',
            'Créer ou mettre à jour les informations des contrats.',
            action: IconButton.filledTonal(
              onPressed: _saving || _profiles.isEmpty
                  ? null
                  : () => _editSubscription(),
              tooltip: 'Créer un abonnement',
              icon: const Icon(Icons.add_rounded),
            ),
          ),
          const SizedBox(height: 20),
          if (_profiles.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: InfoBanner(
                'Pour créer un abonnement, il faut d’abord qu’au moins un client soit présent.',
              ),
            ),
          if (_subscriptions.isEmpty)
            const _EmptyState(
              icon: Icons.electrical_services_outlined,
              message: 'Aucun abonnement à afficher.',
            )
          else
            ..._subscriptions.map((subscription) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.electrical_services_rounded,
                                color: blue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _value(subscription['label'],
                                    fallback: 'Abonnement'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            _StatusTag(
                              label: _statusLabel(_value(subscription['status'],
                                  fallback: 'pending')),
                              status: _value(subscription['status'],
                                  fallback: 'pending'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        detailRow(
                            'Référence', _value(subscription['reference'])),
                        detailRow(
                            'Adresse', _value(subscription['service_address'])),
                        detailRow('N° compteur',
                            _value(subscription['meter_number'])),
                        detailRow('Client',
                            _ownerName(subscription['owner_id']?.toString())),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _editSubscription(subscription),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Modifier'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          if (_profiles.isNotEmpty) ...[
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _editSubscription(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Créer un abonnement'),
            ),
          ],
        ],
      );

  String _ownerName(String? ownerId) {
    if (ownerId == null) return 'Client inconnu';
    for (final profile in _profiles) {
      if (profile['id']?.toString() == ownerId) {
        final name = _value(profile['display_name'], fallback: 'Client');
        final email = _value(profile['email'], fallback: '');
        return email.isEmpty ? name : '$name · $email';
      }
    }
    return 'Client · $ownerId';
  }

  Widget _invoicesSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Factures',
            'Créer et corriger les factures sans action de paiement.',
            action: IconButton.filledTonal(
              onPressed: _saving || _subscriptions.isEmpty
                  ? null
                  : () => _editInvoice(),
              tooltip: 'Créer une facture',
              icon: const Icon(Icons.add_rounded),
            ),
          ),
          const SizedBox(height: 20),
          if (_subscriptions.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: InfoBanner(
                'Un abonnement doit être disponible pour créer une facture.',
              ),
            ),
          if (_invoices.isEmpty)
            const _EmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'Aucune facture à afficher.',
            )
          else
            ..._invoices.map((invoice) {
              final status = _value(invoice['status'], fallback: 'due');
              final testPayment = invoice['test_payment'];
              final testPaid =
                  testPayment is Map && testPayment['status'] == 'paid_test';
              final paid = status.toLowerCase() == 'paid' || testPaid;
              final displayStatus = testPaid ? 'paid_test' : status;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long_outlined, color: blue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _value(invoice['period_label'],
                                  fallback: 'Facture'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          _StatusTag(
                              label: _statusLabel(displayStatus),
                              status: displayStatus),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${money(invoice['amount_xof'])} FCFA',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      detailRow(
                          'Abonnement',
                          _subscriptionName(
                              invoice['subscription_id']?.toString())),
                      detailRow('Cliente',
                          '${_value(invoice['customer_name'], fallback: 'Client')} · ${_value(invoice['customer_email'], fallback: 'e-mail manquant')}'),
                      detailRow('Échéance', _dateLabel(invoice['due_date'])),
                      detailRow('Référence externe',
                          _value(invoice['external_reference'])),
                      const SizedBox(height: 8),
                      if (testPaid)
                        const InfoBanner(
                          'Paiement TEST visible dans Supabase. Le statut officiel de la facture reste dû; aucun débit ni reçu réel.',
                        )
                      else if (paid)
                        const InfoBanner(
                          'Facture payée : modification désactivée. Aucun reçu ni paiement n’est créé ici.',
                        )
                      else
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed:
                                _saving ? null : () => _editInvoice(invoice),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Modifier'),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Tooltip(
                          message:
                              'Configurer un fournisseur d’e-mail avant l’envoi.',
                          child: OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.email_outlined, size: 18),
                            label: const Text('Envoi e-mail non configuré'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          if (_subscriptions.isNotEmpty) ...[
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _editInvoice(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Créer une facture'),
            ),
          ],
        ],
      );

  String _dateLabel(dynamic value) {
    final date = _value(value, fallback: '');
    if (date.isEmpty) return 'Non définie';
    return date.length >= 10 ? displayDate(date.substring(0, 10)) : date;
  }

  Widget _activeSection() {
    switch (_section) {
      case 1:
        return _subscriptionsSection();
      case 2:
        return _invoicesSection();
      case 3:
        return _auditSection();
      default:
        return _clientsSection();
    }
  }

  Widget _auditSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Journal d’administration',
            'Historique des créations et modifications de contrats et factures.',
          ),
          const SizedBox(height: 20),
          if (_auditLogs.isEmpty)
            const _EmptyState(
              icon: Icons.history_rounded,
              message: 'Aucune modification enregistrée.',
            )
          else
            ..._auditLogs.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_value(entry['action'])} · ${_value(entry['entity_type'])}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        detailRow('Élément', _value(entry['entity_id'])),
                        detailRow('Administrateur', _value(entry['actor_id'])),
                        detailRow('Date', _value(entry['created_at'])),
                      ],
                    ),
                  ),
                )),
        ],
      );

  Widget _content() => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Résumé', style: Theme.of(context).textTheme.titleLarge),
                if (_refreshing)
                  const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 13),
            if (_overview != null) _summaryCards(),
            if (_error != null) ...[
              const SizedBox(height: 14),
              InfoBanner(_error!, error: true),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                ),
              ),
            ],
            const SizedBox(height: 18),
            const InfoBanner(
              'Envoi e-mail non configuré. Le paiement TEST côté client est uniquement local : aucun débit, aucune écriture dans Supabase et aucun reçu réel. L’admin ne peut pas marquer une facture comme payée.',
            ),
            const SizedBox(height: 25),
            _activeSection(),
            if (_saving) ...[
              const SizedBox(height: 18),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Administration'),
          actions: [
            IconButton(
              tooltip: 'Actualiser le résumé',
              onPressed: _refreshing ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Row(
                  children: [
                    if (wide) ...[
                      const SizedBox(width: 8),
                      _navigation(extended: constraints.maxWidth >= 1100),
                      const VerticalDivider(
                          width: 1, thickness: 1, color: line),
                    ],
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _content(),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        bottomNavigationBar:
            MediaQuery.sizeOf(context).width < 900 ? _mobileNavigation() : null,
      );
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color tint;

  const _SummaryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) => Surface(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: blue),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 13, color: muted)),
                  const SizedBox(height: 2),
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Surface(
        child: Row(
          children: [
            Icon(icon, color: muted, size: 26),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      );
}

class _StatusTag extends StatelessWidget {
  final String label;
  final String status;

  const _StatusTag({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final Color background;
    final Color foreground;
    if (normalized == 'paid' ||
        normalized == 'active' ||
        normalized == 'success') {
      background = const Color(0xFFE5F4EB);
      foreground = const Color(0xFF216B48);
    } else if (normalized == 'failed' ||
        normalized == 'inactive' ||
        normalized == 'suspended') {
      background = const Color(0xFFFDEAEA);
      foreground = const Color(0xFFA63D3D);
    } else {
      background = const Color(0xFFFFF1D7);
      foreground = const Color(0xFF81500C);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(9)),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: foreground),
      ),
    );
  }
}

class _SubscriptionEditor extends StatefulWidget {
  final List<Json> profiles;
  final Json? subscription;

  const _SubscriptionEditor({required this.profiles, this.subscription});

  @override
  State<_SubscriptionEditor> createState() => _SubscriptionEditorState();
}

class _SubscriptionEditorState extends State<_SubscriptionEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reference;
  late final TextEditingController _label;
  late final TextEditingController _address;
  late final TextEditingController _meter;
  late String? _ownerId;
  late String _status;

  bool get _editing => widget.subscription != null;

  @override
  void initState() {
    super.initState();
    final subscription = widget.subscription;
    _reference = TextEditingController(
        text: subscription?['reference']?.toString() ?? '');
    _label =
        TextEditingController(text: subscription?['label']?.toString() ?? '');
    _address = TextEditingController(
        text: subscription?['service_address']?.toString() ?? '');
    _meter = TextEditingController(
        text: subscription?['meter_number']?.toString() ?? '');
    final initialOwner = subscription?['owner_id']?.toString();
    _ownerId = widget.profiles
            .any((profile) => profile['id']?.toString() == initialOwner)
        ? initialOwner
        : (widget.profiles.isEmpty
            ? null
            : widget.profiles.first['id']?.toString());
    _status = subscription?['status']?.toString() ?? 'active';
  }

  @override
  void dispose() {
    _reference.dispose();
    _label.dispose();
    _address.dispose();
    _meter.dispose();
    super.dispose();
  }

  String? _required(String? value, String field) =>
      value?.trim().isNotEmpty == true ? null : 'Saisissez $field.';

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_ownerId == null || _ownerId!.isEmpty) return;
    Navigator.of(context).pop(<String, dynamic>{
      'ownerId': _ownerId,
      'reference': _reference.text.trim(),
      'label': _label.text.trim(),
      'serviceAddress': _address.text.trim(),
      'meterNumber': _meter.text.trim().isEmpty ? null : _meter.text.trim(),
      'status': _status,
    });
  }

  @override
  Widget build(BuildContext context) {
    final statuses = <String>{
      'active',
      'pending_verification',
      'suspended',
      'closed',
      _status
    }.toList();
    return AlertDialog(
      title: Text(_editing ? 'Modifier l’abonnement' : 'Créer un abonnement'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _ownerId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Client',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  items: widget.profiles
                      .map((profile) {
                        final id = profile['id']?.toString();
                        if (id == null || id.isEmpty) return null;
                        final name = profile['display_name']?.toString().trim();
                        final email = profile['email']?.toString().trim();
                        final title = [
                          if (name != null && name.isNotEmpty) name,
                          if (email != null && email.isNotEmpty) email,
                        ].join(' · ');
                        return DropdownMenuItem(
                            value: id,
                            child: Text(title.isEmpty ? id : title,
                                overflow: TextOverflow.ellipsis));
                      })
                      .whereType<DropdownMenuItem<String>>()
                      .toList(),
                  validator: (value) =>
                      value == null ? 'Sélectionnez un client.' : null,
                  onChanged: (value) => setState(() => _ownerId = value),
                ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: _reference,
                  textInputAction: TextInputAction.next,
                  decoration:
                      const InputDecoration(labelText: 'Référence du contrat'),
                  validator: (value) => _required(value, 'la référence'),
                ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: _label,
                  textInputAction: TextInputAction.next,
                  decoration:
                      const InputDecoration(labelText: 'Nom de l’abonnement'),
                  validator: (value) => _required(value, 'un nom'),
                ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: _address,
                  textInputAction: TextInputAction.next,
                  minLines: 1,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Adresse de service'),
                  validator: (value) => _required(value, 'une adresse'),
                ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: _meter,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                      labelText: 'Numéro de compteur (facultatif)'),
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_editing) ...[
                  const SizedBox(height: 13),
                  DropdownButtonFormField<String>(
                    initialValue:
                        statuses.contains(_status) ? _status : statuses.first,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: statuses
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(_subscriptionStatusLabel(status)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _status = value);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler')),
        FilledButton(
            onPressed: widget.profiles.isEmpty ? null : _submit,
            child: const Text('Enregistrer')),
      ],
    );
  }
}

String _subscriptionStatusLabel(String status) {
  switch (status) {
    case 'active':
      return 'Actif';
    case 'pending_verification':
      return 'En attente de validation';
    case 'suspended':
      return 'Suspendu';
    case 'closed':
      return 'Fermé';
    default:
      return status;
  }
}

class _InvoiceEditor extends StatefulWidget {
  final List<Json> subscriptions;
  final Json? invoice;

  const _InvoiceEditor({required this.subscriptions, this.invoice});

  @override
  State<_InvoiceEditor> createState() => _InvoiceEditorState();
}

class _InvoiceEditorState extends State<_InvoiceEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _period;
  late final TextEditingController _amount;
  late final TextEditingController _dueDate;
  late final TextEditingController _externalReference;
  late String? _subscriptionId;
  late String _status;

  bool get _editing => widget.invoice != null;

  String get _selectedSubscriptionLabel {
    for (final row in widget.subscriptions) {
      if (row['id']?.toString() == _subscriptionId) {
        return '${row['label']} · ${row['reference']}';
      }
    }
    return 'Abonnement sélectionné';
  }

  @override
  void initState() {
    super.initState();
    final invoice = widget.invoice;
    _period =
        TextEditingController(text: invoice?['period_label']?.toString() ?? '');
    _amount =
        TextEditingController(text: invoice?['amount_xof']?.toString() ?? '');
    _dueDate =
        TextEditingController(text: invoice?['due_date']?.toString() ?? '');
    _externalReference = TextEditingController(
        text: invoice?['external_reference']?.toString() ?? '');
    final initialSub = invoice?['subscription_id']?.toString();
    _subscriptionId =
        widget.subscriptions.any((row) => row['id']?.toString() == initialSub)
            ? initialSub
            : (widget.subscriptions.isEmpty
                ? null
                : widget.subscriptions.first['id']?.toString());
    _status = invoice?['status']?.toString() ?? 'due';
  }

  @override
  void dispose() {
    _period.dispose();
    _amount.dispose();
    _dueDate.dispose();
    _externalReference.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final current = DateTime.tryParse(_dueDate.text.trim());
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Choisir une échéance',
    );
    if (selected != null) {
      setState(() => _dueDate.text =
          '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}');
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_subscriptionId == null || _subscriptionId!.isEmpty) return;
    // Défense en profondeur : le statut paid n'est jamais accepté à l'édition.
    if (_editing && _status.toLowerCase() == 'paid') return;
    Navigator.of(context).pop(<String, dynamic>{
      'subscriptionId': _subscriptionId,
      'periodLabel': _period.text.trim(),
      'amountXof': int.parse(_amount.text.trim()),
      'dueDate': _dueDate.text.trim().isEmpty ? null : _dueDate.text.trim(),
      'externalReference': _externalReference.text.trim().isEmpty
          ? null
          : _externalReference.text.trim(),
      'status': _status,
    });
  }

  @override
  Widget build(BuildContext context) {
    final statuses = <String>{'due', 'overdue', 'cancelled', _status}
        .where((status) => status.toLowerCase() != 'paid')
        .toList();
    return AlertDialog(
      title: Text(_editing ? 'Modifier la facture' : 'Créer une facture'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_editing)
                  DropdownButtonFormField<String>(
                    initialValue: _subscriptionId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Abonnement'),
                    items: widget.subscriptions
                        .map((subscription) {
                          final id = subscription['id']?.toString();
                          if (id == null || id.isEmpty) return null;
                          final label =
                              subscription['label']?.toString() ?? 'Abonnement';
                          final reference =
                              subscription['reference']?.toString() ?? '';
                          return DropdownMenuItem(
                            value: id,
                            child: Text('$label · $reference',
                                overflow: TextOverflow.ellipsis),
                          );
                        })
                        .whereType<DropdownMenuItem<String>>()
                        .toList(),
                    validator: (value) =>
                        value == null ? 'Sélectionnez un abonnement.' : null,
                    onChanged: (value) =>
                        setState(() => _subscriptionId = value),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _selectedSubscriptionLabel,
                      style: const TextStyle(color: muted),
                    ),
                  ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: _period,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                      labelText: 'Période de facturation'),
                  validator: (value) => value?.trim().isNotEmpty == true
                      ? null
                      : 'Saisissez une période (ex. octobre 2026).',
                ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Montant (FCFA)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    final amount = int.tryParse(value?.trim() ?? '');
                    return amount != null && amount > 0
                        ? null
                        : 'Saisissez un montant entier supérieur à zéro.';
                  },
                ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: _dueDate,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: InputDecoration(
                    labelText: 'Date d’échéance (facultative)',
                    hintText: 'AAAA-MM-JJ',
                    suffixIcon: IconButton(
                      tooltip: 'Choisir une date',
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    final parsed = DateTime.tryParse(text);
                    return parsed != null &&
                            RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)
                        ? null
                        : 'Utilisez le format AAAA-MM-JJ.';
                  },
                ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: _externalReference,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                      labelText: 'Référence externe (facultative)'),
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_editing) ...[
                  const SizedBox(height: 13),
                  DropdownButtonFormField<String>(
                    initialValue:
                        statuses.contains(_status) ? _status : statuses.first,
                    decoration: const InputDecoration(
                        labelText: 'Statut (jamais « payée »)'),
                    items: statuses
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(_invoiceStatusLabel(status)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null && value.toLowerCase() != 'paid') {
                        setState(() => _status = value);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: widget.subscriptions.isEmpty ? null : _submit,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

String _invoiceStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'due':
      return 'À payer';
    case 'overdue':
      return 'En retard';
    case 'cancelled':
      return 'Annulée';
    default:
      return status;
  }
}
