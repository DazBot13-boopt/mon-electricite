import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

typedef Json = Map<String, dynamic>;

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

/// Thin application adapter over Supabase Auth and Postgres.
/// Client-side access is constrained by the database RLS policies.
class Api {
  Api({SupabaseClient? client}) : _clientOverride = client;

  final SupabaseClient? _clientOverride;
  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;
  bool get hasSession => _client.auth.currentSession != null;

  Future<Json> createTestPayment(String invoiceId) async {
    if (!SupabaseConfig.paymentTestMode) {
      throw ApiException(403, 'Le mode paiement TEST est désactivé.');
    }
    final user = _client.auth.currentUser;
    if (user == null) {
      throw ApiException(401, 'Connectez-vous pour continuer.');
    }

    final invoiceResult = await _client
        .from('invoices')
        .select('id, subscription_id, amount_xof, status')
        .eq('id', invoiceId)
        .maybeSingle();
    if (invoiceResult == null) throw ApiException(404, 'Facture introuvable.');
    final invoice = Map<String, dynamic>.from(invoiceResult);
    if (invoice['status'] == 'paid') {
      throw ApiException(409, 'Cette facture est déjà réglée réellement.');
    }

    final subscriptionResult = await _client
        .from('subscriptions')
        .select('owner_id')
        .eq('id', invoice['subscription_id'])
        .maybeSingle();
    if (subscriptionResult == null ||
        subscriptionResult['owner_id'] != user.id) {
      throw ApiException(403, 'Cette facture ne vous appartient pas.');
    }

    final existing = await _client
        .from('test_payments')
        .select('id')
        .eq('invoice_id', invoiceId)
        .eq('user_id', user.id)
        .maybeSingle();
    if (existing == null) {
      await _client.from('test_payments').insert(<String, dynamic>{
        'invoice_id': invoiceId,
        'user_id': user.id,
        'amount_xof': invoice['amount_xof'],
      });
    }
    return _loadInvoice(invoiceId);
  }

  Future<Json> get(String path) async {
    try {
      if (path == '/me') return await _loadDashboard();

      final invoiceId = _resourceId(path, '/invoices/');
      if (invoiceId != null) return await _loadInvoice(invoiceId);

      final receiptId = _resourceId(path, '/receipts/');
      if (receiptId != null) return await _loadReceipt(receiptId);

      throw ApiException(404, 'Cette ressource est indisponible.');
    } on AuthException catch (e) {
      throw ApiException(401, e.message);
    } on PostgrestException catch (e) {
      throw ApiException(0, e.message);
    }
  }

  Future<Json> post(String path, Json body) async {
    try {
      if (path == '/auth/register') return await _register(body);
      if (path == '/auth/login') return await _login(body);
      if (path == '/auth/logout') {
        await _client.auth.signOut();
        return <String, dynamic>{};
      }
      if (path == '/links/request' || path == '/links/verify') {
        throw ApiException(
          503,
          'L’association d’un abonnement doit être validée par un opérateur avant d’afficher ses données.',
        );
      }
      if (path.contains('/payments')) {
        throw ApiException(
          503,
          'Aucun prestataire de paiement réel n’est connecté. Aucun débit n’a été effectué.',
        );
      }
      throw ApiException(404, 'Cette opération est indisponible.');
    } on AuthException catch (e) {
      throw ApiException(401, e.message);
    } on PostgrestException catch (e) {
      throw ApiException(0, e.message);
    }
  }

  Future<Json> _register(Json body) async {
    final email = _normalizeEmail(body['email']?.toString() ?? '');
    final password = body['password']?.toString() ?? '';
    final displayName = body['name']?.toString().trim() ?? '';
    if (!_isValidEmail(email) || password.isEmpty || displayName.length < 2) {
      throw ApiException(
          400, 'Vérifiez le nom, l’adresse e-mail et le mot de passe.');
    }

    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: <String, dynamic>{'display_name': displayName},
    );

    if (response.session == null) {
      throw ApiException(
        409,
        'La confirmation e-mail est encore activée dans Supabase. Dans Auth > Providers > Email, désactive « Confirm email » pour autoriser une connexion immédiate sans vérification. L’inscription a pu créer un compte en attente.',
      );
    }
    return <String, dynamic>{'token': response.session!.accessToken};
  }

  Future<Json> _login(Json body) async {
    final email = _normalizeEmail(body['email']?.toString() ?? '');
    final password = body['password']?.toString() ?? '';
    if (!_isValidEmail(email) || password.isEmpty) {
      throw ApiException(
          400, 'Saisissez une adresse e-mail valide et votre mot de passe.');
    }

    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return <String, dynamic>{'token': response.session?.accessToken ?? ''};
  }

  Future<Json> getAdminOverview() async {
    try {
      await _requireAdmin();
      final profileRows = _rows(await _client
          .from('profiles')
          .select('id, display_name, email, role, created_at')
          .order('created_at', ascending: false)
          .limit(500));
      final profilesById = <String, Json>{
        for (final profile in profileRows) profile['id'].toString(): profile,
      };
      final subscriptions = _rows(await _client
          .from('subscriptions')
          .select(
              'id, owner_id, reference, label, service_address, meter_number, status, created_at')
          .order('created_at', ascending: false)
          .limit(500));
      final subscriptionsById = <String, Json>{
        for (final row in subscriptions) row['id'].toString(): row,
      };
      final testPaymentRows = _rows(await _client
          .from('test_payments')
          .select('id, invoice_id, user_id, status, amount_xof, created_at')
          .order('created_at', ascending: false)
          .limit(2000));
      final testPaymentsByInvoice = <String, Json>{
        for (final row in testPaymentRows) row['invoice_id'].toString(): row,
      };
      final invoices = _rows(await _client
              .from('invoices')
              .select(
                  'id, subscription_id, period_label, amount_xof, due_date, status, external_reference, created_at')
              .order('created_at', ascending: false)
              .limit(1000))
          .map((invoice) {
        final subscription =
            subscriptionsById[invoice['subscription_id'].toString()];
        final profile = profilesById[subscription?['owner_id'].toString()];
        return <String, dynamic>{
          ...invoice,
          'subscription_reference': subscription?['reference'] ?? '',
          'subscription_label': subscription?['label'] ?? '',
          'customer_name': profile?['display_name'] ?? 'Cliente',
          'customer_email': profile?['email'] ?? '',
          'test_payment': testPaymentsByInvoice[invoice['id'].toString()],
        };
      }).toList();
      final auditLogs = _rows(await _client
          .from('admin_audit_log')
          .select('id, actor_id, action, entity_type, entity_id, created_at')
          .order('created_at', ascending: false)
          .limit(100));
      return <String, dynamic>{
        'profiles': profileRows,
        'subscriptions': subscriptions,
        'invoices': invoices,
        'audit_logs': auditLogs,
      };
    } on AuthException catch (e) {
      throw ApiException(401, e.message);
    } on PostgrestException catch (e) {
      throw ApiException(0, e.message);
    }
  }

  Future<void> createAdminSubscription({
    required String ownerId,
    required String reference,
    required String label,
    required String serviceAddress,
    String? meterNumber,
  }) async {
    await _requireAdmin();
    final cleanReference = reference.trim();
    final cleanLabel = label.trim();
    if (ownerId.isEmpty || cleanReference.isEmpty || cleanLabel.isEmpty) {
      throw ApiException(400, 'Cliente, référence et nom du contrat requis.');
    }
    await _client.from('subscriptions').insert(<String, dynamic>{
      'owner_id': ownerId,
      'reference': cleanReference,
      'label': cleanLabel,
      'service_address': serviceAddress.trim(),
      'meter_number': _nullable(meterNumber),
    });
  }

  Future<void> updateAdminSubscription({
    required String id,
    required String ownerId,
    required String reference,
    required String label,
    required String serviceAddress,
    String? meterNumber,
    required String status,
  }) async {
    await _requireAdmin();
    const allowedStatuses = {
      'pending_verification',
      'active',
      'suspended',
      'closed'
    };
    if (!allowedStatuses.contains(status)) {
      throw ApiException(400, 'État de contrat invalide.');
    }
    await _client.from('subscriptions').update(<String, dynamic>{
      'owner_id': ownerId,
      'reference': reference.trim(),
      'label': label.trim(),
      'service_address': serviceAddress.trim(),
      'meter_number': _nullable(meterNumber),
      'status': status,
    }).eq('id', id);
  }

  Future<void> createAdminInvoice({
    required String subscriptionId,
    required String periodLabel,
    required int amountXof,
    String? dueDate,
    String? externalReference,
  }) async {
    await _requireAdmin();
    if (subscriptionId.isEmpty || periodLabel.trim().isEmpty || amountXof < 0) {
      throw ApiException(400, 'Abonnement, période et montant sont requis.');
    }
    final cleanDueDate = _nullable(dueDate);
    if (cleanDueDate != null && DateTime.tryParse(cleanDueDate) == null) {
      throw ApiException(400, 'La date limite doit être au format AAAA-MM-JJ.');
    }
    await _client.from('invoices').insert(<String, dynamic>{
      'subscription_id': subscriptionId,
      'period_label': periodLabel.trim(),
      'amount_xof': amountXof,
      'due_date': cleanDueDate,
      'external_reference': _nullable(externalReference),
      'status': 'due',
    });
  }

  Future<void> updateAdminInvoice({
    required String id,
    required String periodLabel,
    required int amountXof,
    String? dueDate,
    String? externalReference,
    required String status,
  }) async {
    await _requireAdmin();
    const allowedStatuses = {'due', 'overdue', 'cancelled'};
    if (status == 'paid') {
      throw ApiException(403,
          'Seul un prestataire de paiement vérifié peut confirmer le règlement.');
    }
    if (!allowedStatuses.contains(status) ||
        periodLabel.trim().isEmpty ||
        amountXof < 0) {
      throw ApiException(400, 'Vérifiez les champs de la facture.');
    }
    final cleanDueDate = _nullable(dueDate);
    if (cleanDueDate != null && DateTime.tryParse(cleanDueDate) == null) {
      throw ApiException(400, 'La date limite doit être au format AAAA-MM-JJ.');
    }
    await _client.from('invoices').update(<String, dynamic>{
      'period_label': periodLabel.trim(),
      'amount_xof': amountXof,
      'due_date': cleanDueDate,
      'external_reference': _nullable(externalReference),
      'status': status,
    }).eq('id', id);
  }

  Future<void> _requireAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) throw ApiException(401, 'Connectez-vous pour continuer.');
    final row = await _client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null || row['role'] != 'admin') {
      throw ApiException(403, 'Accès réservé à un compte administrateur.');
    }
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<Json> _loadDashboard() async {
    final user = _client.auth.currentUser;
    if (user == null) throw ApiException(401, 'Connectez-vous pour continuer.');

    final profileResult = await _client
        .from('profiles')
        .select('display_name, role')
        .eq('id', user.id)
        .maybeSingle();
    final profile = profileResult == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(profileResult);

    final subscriptionResult = await _client
        .from('subscriptions')
        .select(
            'id, owner_id, reference, label, service_address, meter_number, status')
        .eq('owner_id', user.id)
        .order('created_at', ascending: false)
        .limit(100);
    final subscriptions = _rows(subscriptionResult);
    final subscriptionsById = <String, Json>{
      for (final row in subscriptions) row['id'].toString(): row,
    };
    final subscriptionIds = subscriptions.map((row) => row['id']).toList();

    final invoiceRows = subscriptionIds.isEmpty
        ? <Json>[]
        : _rows(await _client
            .from('invoices')
            .select(
                'id, subscription_id, period_label, amount_xof, due_date, status, consumption_kwh, previous_index, current_index, energy_xof, fees_xof, created_at')
            .inFilter('subscription_id', subscriptionIds)
            .order('created_at', ascending: false)
            .limit(200));

    final paymentRows = _rows(await _client
        .from('payments')
        .select('id, invoice_id, status, amount_xof, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(200));
    final latestPaymentByInvoice = <String, Json>{};
    for (final row in paymentRows) {
      latestPaymentByInvoice.putIfAbsent(
          row['invoice_id'].toString(), () => row);
    }

    final testPaymentRows = _rows(await _client
        .from('test_payments')
        .select('id, invoice_id, status, amount_xof, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(200));
    final testPaymentsByInvoice = <String, Json>{
      for (final row in testPaymentRows) row['invoice_id'].toString(): row,
    };

    final receiptRows = _rows(await _client
        .from('receipts')
        .select('id, payment_id')
        .eq('user_id', user.id)
        .limit(200));
    final receiptByPayment = <String, String>{
      for (final row in receiptRows)
        row['payment_id'].toString(): row['id'].toString(),
    };

    return <String, dynamic>{
      'user': <String, dynamic>{
        'name': (profile['display_name'] as String?)?.trim().isNotEmpty == true
            ? profile['display_name']
            : 'Utilisateur',
        'email': user.email ?? '',
        'role': profile['role'] ?? 'customer',
      },
      'subscriptions': subscriptions
          .map((row) => <String, dynamic>{
                'id': row['id'],
                'reference': row['reference'],
                'label': row['label'],
                'address': row['service_address'],
                'meter_number': row['meter_number'],
                'status': row['status'],
              })
          .toList(),
      'invoices': invoiceRows
          .map((row) => _invoiceView(
                row,
                subscriptionsById,
                latestPaymentByInvoice,
                testPaymentsByInvoice,
                receiptByPayment,
              ))
          .toList(),
    };
  }

  Future<Json> _loadInvoice(String invoiceId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw ApiException(401, 'Connectez-vous pour continuer.');

    final invoiceResult = await _client
        .from('invoices')
        .select(
            'id, subscription_id, period_label, amount_xof, due_date, status, consumption_kwh, previous_index, current_index, energy_xof, fees_xof, created_at')
        .eq('id', invoiceId)
        .maybeSingle();
    if (invoiceResult == null) throw ApiException(404, 'Facture introuvable.');
    final invoice = Map<String, dynamic>.from(invoiceResult);

    final subscriptionResult = await _client
        .from('subscriptions')
        .select('id, reference, label')
        .eq('id', invoice['subscription_id'])
        .maybeSingle();
    final subscriptionsById = <String, Json>{
      if (subscriptionResult != null)
        invoice['subscription_id'].toString():
            Map<String, dynamic>.from(subscriptionResult),
    };

    final paymentRows = _rows(await _client
        .from('payments')
        .select('id, invoice_id, status, amount_xof, created_at')
        .eq('user_id', user.id)
        .eq('invoice_id', invoiceId)
        .order('created_at', ascending: false)
        .limit(1));
    final latestPaymentByInvoice = <String, Json>{
      if (paymentRows.isNotEmpty) invoiceId: paymentRows.first,
    };
    final receiptByPayment = <String, String>{};
    if (paymentRows.isNotEmpty) {
      final receiptResult = await _client
          .from('receipts')
          .select('id, payment_id')
          .eq('payment_id', paymentRows.first['id'])
          .maybeSingle();
      if (receiptResult != null) {
        receiptByPayment[receiptResult['payment_id'].toString()] =
            receiptResult['id'].toString();
      }
    }

    final testPaymentResult = await _client
        .from('test_payments')
        .select('id, invoice_id, user_id, status, amount_xof, created_at')
        .eq('invoice_id', invoiceId)
        .maybeSingle();
    final testPaymentsByInvoice = <String, Json>{
      if (testPaymentResult != null)
        invoiceId: Map<String, dynamic>.from(testPaymentResult),
    };

    return _invoiceView(
      invoice,
      subscriptionsById,
      latestPaymentByInvoice,
      testPaymentsByInvoice,
      receiptByPayment,
    );
  }

  Future<Json> _loadReceipt(String receiptId) async {
    final receiptResult = await _client
        .from('receipts')
        .select('id, payment_id, user_id, receipt_number, issued_at')
        .eq('id', receiptId)
        .maybeSingle();
    if (receiptResult == null) throw ApiException(404, 'Reçu introuvable.');
    final receipt = Map<String, dynamic>.from(receiptResult);

    final paymentResult = await _client
        .from('payments')
        .select('id, invoice_id, amount_xof, provider_reference')
        .eq('id', receipt['payment_id'])
        .maybeSingle();
    if (paymentResult == null) throw ApiException(404, 'Paiement introuvable.');
    final payment = Map<String, dynamic>.from(paymentResult);

    final invoiceResult = await _client
        .from('invoices')
        .select('id, subscription_id, period_label')
        .eq('id', payment['invoice_id'])
        .maybeSingle();
    if (invoiceResult == null) throw ApiException(404, 'Facture introuvable.');
    final invoice = Map<String, dynamic>.from(invoiceResult);

    final subscriptionResult = await _client
        .from('subscriptions')
        .select('id, reference')
        .eq('id', invoice['subscription_id'])
        .maybeSingle();
    final subscription = subscriptionResult == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(subscriptionResult);
    final issuedAt = DateTime.parse(receipt['issued_at'].toString());

    return <String, dynamic>{
      'id': receipt['receipt_number'],
      'amount': payment['amount_xof'],
      'subscription_id': subscription['reference'] ?? '—',
      'invoice_id': invoice['id'],
      'period': invoice['period_label'],
      'transaction_id': payment['provider_reference'] ?? '—',
      'created': issuedAt.millisecondsSinceEpoch / 1000,
    };
  }

  static Json _invoiceView(
    Json row,
    Map<String, Json> subscriptionsById,
    Map<String, Json> latestPaymentByInvoice,
    Map<String, Json> testPaymentsByInvoice,
    Map<String, String> receiptByPayment,
  ) {
    final subscriptionId = row['subscription_id'].toString();
    final payment = latestPaymentByInvoice[row['id'].toString()];
    final testPayment = testPaymentsByInvoice[row['id'].toString()];
    return <String, dynamic>{
      'id': row['id'],
      'sub_id': subscriptionId,
      'label': subscriptionsById[subscriptionId]?['label'] ?? 'Abonnement',
      'period': row['period_label'] ?? 'Facture',
      'amount': row['amount_xof'] ?? 0,
      'status': row['status'] ?? 'due',
      'due': row['due_date']?.toString() ?? '',
      'consumption': row['consumption_kwh'] ?? '—',
      'previous_index': row['previous_index'] ?? '—',
      'current_index': row['current_index'] ?? '—',
      'energy': row['energy_xof'] ?? 0,
      'fees': row['fees_xof'] ?? 0,
      'payment': payment == null
          ? null
          : <String, dynamic>{
              'id': payment['id'],
              'status': payment['status'],
              'receipt_id': receiptByPayment[payment['id'].toString()],
            },
      'test_payment': testPayment,
    };
  }

  static List<Json> _rows(dynamic result) => (result as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();

  static String? _resourceId(String path, String prefix) {
    if (!path.startsWith(prefix)) return null;
    final id = path.substring(prefix.length);
    return id.isEmpty || id.contains('/') ? null : id;
  }

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
}
