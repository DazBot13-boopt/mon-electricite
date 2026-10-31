import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api.dart';
import 'design.dart';
import 'admin_screen.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark));
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const ElectricityApp());
}

class ElectricityApp extends StatefulWidget {
  final Api? api;
  const ElectricityApp({super.key, this.api});
  @override
  State<ElectricityApp> createState() => _ElectricityAppState();
}

class _ElectricityAppState extends State<ElectricityApp> {
  late final Api api;
  bool connected = false;
  @override
  void initState() {
    super.initState();
    api = widget.api ?? Api();
    connected = api.hasSession;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mon Électricité',
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: connected
            ? Dashboard(
                api: api,
                onLogout: () => setState(() {
                      connected = false;
                    }))
            : AuthScreen(
                api: api,
                onAuthenticated: () => setState(() => connected = true)),
      );
}

class AuthScreen extends StatefulWidget {
  final Api api;
  final VoidCallback onAuthenticated;
  const AuthScreen(
      {super.key, required this.api, required this.onAuthenticated});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  bool register = false, busy = false, obscure = true;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post(register ? '/auth/register' : '/auth/login', {
        'name': name.text.trim(),
        'email': email.text.trim().toLowerCase(),
        'password': password.text,
      });
      if (!mounted) return;
      widget.onAuthenticated();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Row(children: [
                        Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                                color: amber,
                                borderRadius: BorderRadius.circular(13)),
                            child: const Icon(Icons.bolt_rounded,
                                color: navy, size: 29)),
                        const SizedBox(width: 11),
                        const Text('Mon Électricité',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: ink,
                                fontSize: 18)),
                        const Spacer(),
                        const Text('CLIENT & ADMIN',
                            style: TextStyle(
                                fontSize: 10, color: muted, letterSpacing: 1))
                      ]),
                      const SizedBox(height: 30),
                      Container(
                          padding: const EdgeInsets.all(26),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: const LinearGradient(
                                  colors: [navy, Color(0xFF23558A)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb_outline_rounded,
                                    color: amber, size: 36),
                                const SizedBox(height: 20),
                                const Text(
                                    'Votre énergie.\nVotre tranquillité.',
                                    style: TextStyle(
                                        fontSize: 30,
                                        height: 1.12,
                                        letterSpacing: -1,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                                const SizedBox(height: 13),
                                const Text(
                                    'Vos factures et vos reçus,\ntoujours à portée de main.',
                                    style: TextStyle(
                                        color: Color(0xFFD1DEED), height: 1.5)),
                                const SizedBox(height: 22),
                                Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: .09),
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    child: const Row(children: [
                                      Icon(Icons.verified_user_outlined,
                                          color: amber, size: 20),
                                      SizedBox(width: 9),
                                      Expanded(
                                          child: Text(
                                              'Un espace personnel pour chaque client',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12)))
                                    ])),
                              ])),
                      const SizedBox(height: 28),
                      Text(
                          register
                              ? 'Créer mon compte'
                              : 'Heureux de vous revoir',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                          register
                              ? 'Créez votre compte avec votre adresse e-mail.'
                              : 'Connectez-vous par e-mail pour retrouver vos données.',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 24),
                      Form(
                          key: form,
                          child: Column(children: [
                            if (register) ...[
                              TextFormField(
                                  controller: name,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                      labelText: 'Nom complet',
                                      prefixIcon: Icon(Icons.person_outline)),
                                  validator: (v) => (v?.trim().length ?? 0) >= 2
                                      ? null
                                      : 'Indiquez votre nom.'),
                              const SizedBox(height: 15),
                            ],
                            TextFormField(
                                controller: email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                decoration: const InputDecoration(
                                    labelText: 'Adresse e-mail',
                                    hintText: 'nom@exemple.com',
                                    prefixIcon: Icon(Icons.email_outlined)),
                                validator: (v) {
                                  final value = v?.trim() ?? '';
                                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                          .hasMatch(value)
                                      ? null
                                      : 'Saisissez une adresse e-mail valide.';
                                }),
                            const SizedBox(height: 15),
                            TextFormField(
                                controller: password,
                                obscureText: obscure,
                                decoration: InputDecoration(
                                    labelText: 'Mot de passe',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                        tooltip: obscure
                                            ? 'Afficher le mot de passe'
                                            : 'Masquer le mot de passe',
                                        icon: Icon(obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined),
                                        onPressed: () => setState(
                                            () => obscure = !obscure))),
                                validator: (v) =>
                                    (v?.length ?? 0) >= (register ? 10 : 1)
                                        ? null
                                        : '10 caractères minimum.'),
                            if (error != null) ...[
                              const SizedBox(height: 16),
                              InfoBanner(error!, error: true)
                            ],
                            const SizedBox(height: 23),
                            AppButton(
                                register ? 'Créer mon compte' : 'Se connecter',
                                busy: busy,
                                onPressed: submit,
                                icon: Icons.arrow_forward_rounded),
                          ])),
                      TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                    register = !register;
                                    error = null;
                                  }),
                          child: Text(register
                              ? 'Déjà inscrit ? Se connecter'
                              : 'Pas encore de compte ? S’inscrire')),
                      const SizedBox(height: 18),
                    ],
                  )))));
}

class Dashboard extends StatefulWidget {
  final Api api;
  final VoidCallback onLogout;
  const Dashboard({super.key, required this.api, required this.onLogout});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with WidgetsBindingObserver {
  Json? data;
  String? error, selectedSub;
  int tab = 0, filter = 0;
  bool fetching = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    if (fetching) return;
    fetching = true;
    try {
      final result = await widget.api.get('/me');
      if (mounted) {
        setState(() {
          data = result;
          error = null;
          final subs = (result['subscriptions'] as List);
          if (subs.isNotEmpty && !subs.any((s) => s['id'] == selectedSub)) {
            selectedSub = subs.first['id'] as String;
          }
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 401) {
        widget.onLogout();
        return;
      }
      setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      fetching = false;
    }
  }

  List<Json> get subscriptions => ((data?['subscriptions'] ?? []) as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  List<Json> get invoices => ((data?['invoices'] ?? []) as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .where((e) => selectedSub == null || e['sub_id'] == selectedSub)
      .toList();
  bool get isAdmin => data?['user']?['role'] == 'admin';
  bool isTestPaid(Json invoice) {
    final testPayment = invoice['test_payment'];
    return testPayment is Map && testPayment['status'] == 'paid_test';
  }

  bool isPaidForDisplay(Json invoice) =>
      invoice['status'] == 'paid' || isTestPaid(invoice);

  Future<void> openInvoice(Json invoice) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => InvoiceScreen(api: widget.api, invoice: invoice)));
    if (mounted) await refresh();
  }

  Future<void> addSubscription() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const LinkScreen()));
    if (mounted) await refresh();
  }

  Widget subPicker() => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<String>(
        initialValue: selectedSub,
        isExpanded: true,
        decoration: const InputDecoration(
            prefixIcon: Icon(Icons.home_outlined), labelText: 'Mon abonnement'),
        items: subscriptions
            .map((s) => DropdownMenuItem<String>(
                value: s['id'] as String,
                child: Text('${s['label']} · ${s['id']}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: (v) => setState(() => selectedSub = v),
      ));
  Widget billTile(Json invoice) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => openInvoice(invoice),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: line)),
                child: Row(children: [
                  Container(
                      width: 43,
                      height: 48,
                      decoration: BoxDecoration(
                          color: const Color(0xFFEDF3FC),
                          borderRadius: BorderRadius.circular(13)),
                      child:
                          const Icon(Icons.receipt_long_outlined, color: blue)),
                  const SizedBox(width: 13),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(invoice['period'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, color: ink)),
                        const SizedBox(height: 5),
                        Text('${money(invoice['amount'])} FCFA',
                            style: const TextStyle(color: muted, fontSize: 13))
                      ])),
                  const SizedBox(width: 8),
                  StatusPill(isTestPaid(invoice)
                      ? 'test_paid'
                      : invoice['status'] as String)
                ]),
              ))));
  List<Widget> home() {
    final bills = invoices;
    final due = bills
        .where((i) => i['status'] == 'due' && !isPaidForDisplay(i))
        .toList();
    final bill = due.isNotEmpty
        ? due.first
        : bills.isNotEmpty
            ? bills.first
            : null;
    final firstName = (data!['user']['name'] as String).split(' ').first;
    return [
      Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('VOTRE ESPACE CLIENT',
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: muted)),
          const SizedBox(height: 6),
          Text('Bonjour, $firstName',
              style: Theme.of(context).textTheme.headlineMedium)
        ])),
        IconButton.filledTonal(
            onPressed: () => setState(() => tab = 3),
            tooltip: 'Mon profil',
            icon: const Icon(Icons.person_outline_rounded))
      ]),
      const SizedBox(height: 23),
      if (subscriptions.isNotEmpty) subPicker(),
      if (bill != null)
        Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                    colors: [navy, Color(0xFF214F7C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                boxShadow: [
                  BoxShadow(
                      color: navy.withValues(alpha: .14),
                      blurRadius: 25,
                      offset: const Offset(0, 12))
                ]),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(bill['period'] as String,
                        style: const TextStyle(
                            color: Color(0xFFD4E1EF), fontSize: 13))),
                StatusPill(
                    isTestPaid(bill) ? 'test_paid' : bill['status'] as String)
              ]),
              const SizedBox(height: 25),
              Text(isTestPaid(bill) ? 'RÉGLÉE EN TEST' : 'MONTANT À RÉGLER',
                  style: const TextStyle(
                      color: Color(0xFFBACCDF),
                      letterSpacing: 1.2,
                      fontSize: 10)),
              const SizedBox(height: 7),
              Text('${money(isPaidForDisplay(bill) ? 0 : bill['amount'])} FCFA',
                  style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.4,
                      color: Colors.white)),
              const SizedBox(height: 9),
              Row(children: [
                const Icon(Icons.event_outlined,
                    size: 16, color: Color(0xFFBACCDF)),
                const SizedBox(width: 7),
                Expanded(
                    child: Text(
                        isTestPaid(bill)
                            ? 'Payée en test · aucun débit réel'
                            : bill['status'] == 'paid'
                                ? 'Vos factures sont à jour'
                                : 'Échéance le ${displayDate(bill['due'] as String)}',
                        style: const TextStyle(
                            color: Color(0xFFD4E1EF), fontSize: 13)))
              ]),
              const SizedBox(height: 23),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: amber, foregroundColor: navy),
                      onPressed: () => openInvoice(bill),
                      icon: Icon(isTestPaid(bill)
                          ? Icons.science_outlined
                          : bill['status'] == 'paid'
                              ? Icons.receipt_long_outlined
                              : Icons.arrow_forward_rounded),
                      label: Text(isTestPaid(bill)
                          ? 'Voir le paiement test'
                          : bill['status'] == 'paid'
                              ? 'Consulter ma facture'
                              : 'Consulter et payer'))),
            ]))
      else
        Surface(
            child: Column(children: [
          const Icon(Icons.add_home_outlined, size: 50, color: blue),
          const SizedBox(height: 15),
          Text('Bienvenue chez vous',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Associez votre abonnement pour retrouver vos factures.',
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          AppButton('Ajouter mon abonnement', onPressed: addSubscription)
        ])),
      if (bill != null) ...[
        const SizedBox(height: 20),
        Surface(
            child: Row(children: [
          Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D5),
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.bolt_rounded,
                  color: Color(0xFF967008), size: 28)),
          const SizedBox(width: 15),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Consommation de la période',
                    style: TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 4),
                Text('${bill['consumption']} kWh',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w700, color: ink))
              ]))
        ])),
        Row(children: [
          Expanded(child: sectionTitle('Mes dernières factures')),
          TextButton(
              onPressed: () => setState(() => tab = 1),
              child: const Text('Tout voir'))
        ]),
        ...bills.take(3).map(billTile),
      ],
    ];
  }

  List<Widget> billsPage() => [
        Text('Mes factures', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Un historique clair, mois après mois.'),
        const SizedBox(height: 22),
        if (subscriptions.isNotEmpty) subPicker(),
        Wrap(
            spacing: 8,
            children: ['Toutes', 'À payer', 'Payées']
                .asMap()
                .entries
                .map((e) => ChoiceChip(
                    label: Text(e.value),
                    selected: filter == e.key,
                    onSelected: (_) => setState(() => filter = e.key)))
                .toList()),
        const SizedBox(height: 20),
        ...invoices
            .where((i) =>
                filter == 0 ||
                (filter == 1
                    ? i['status'] == 'due' && !isTestPaid(i)
                    : isPaidForDisplay(i)))
            .map(billTile),
        if (!invoices.any((i) =>
            filter == 0 ||
            (filter == 1
                ? i['status'] == 'due' && !isTestPaid(i)
                : isPaidForDisplay(i))))
          const Surface(child: Text('Aucune facture dans cette catégorie.')),
      ];
  List<Widget> subscriptionsPage() => [
        Text('Mes abonnements',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Votre maison, votre boutique, au même endroit.'),
        const SizedBox(height: 23),
        ...subscriptions.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Surface(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Icon(Icons.home_work_outlined, color: blue, size: 30),
                  const SizedBox(height: 12),
                  Text((s['label'] ?? 'Abonnement').toString(),
                      style: Theme.of(context).textTheme.titleLarge),
                  Text((s['address'] ?? '').toString()),
                  detailRow('Référence',
                      (s['reference'] ?? s['id'] ?? '—').toString()),
                  detailRow('Compteur', (s['meter_number'] ?? '—').toString()),
                  AppButton('Voir les factures',
                      onPressed: () => setState(() {
                            selectedSub = (s['id'] ?? '').toString();
                            tab = 1;
                          }))
                ])))),
        OutlinedButton.icon(
            onPressed: addSubscription,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter un abonnement')),
      ];
  List<Widget> profilePage() => [
        Text('Mon profil', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 25),
        Surface(
            child: Column(children: [
          const CircleAvatar(
              radius: 34,
              backgroundColor: Color(0xFFE9F1FC),
              child: Icon(Icons.person_outline_rounded, size: 34, color: blue)),
          const SizedBox(height: 16),
          Text(data!['user']['name'] as String,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(data!['user']['email'] as String),
          const SizedBox(height: 20),
          detailRow('Abonnements associés', '${subscriptions.length}'),
        ])),
        const SizedBox(height: 20),
        const InfoBanner(
            'Vos données de compte sont protégées par des règles d’accès individualisées.'),
        if (isAdmin) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => AdminScreen(api: widget.api),
            )),
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: const Text('Ouvrir l’administration'),
          ),
        ],
        const SizedBox(height: 23),
        OutlinedButton.icon(
            onPressed: () async {
              try {
                await widget.api.post('/auth/logout', {});
                if (mounted) widget.onLogout();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Se déconnecter'))
      ];
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 650),
                    child: data == null && error == null
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                            onRefresh: refresh,
                            child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(22, 25, 22, 20),
                                children: [
                                  if (error != null) ...[
                                    InfoBanner(error!, error: true),
                                    TextButton(
                                        onPressed: refresh,
                                        child: const Text('Réessayer'))
                                  ],
                                  if (data != null) ...[
                                    if (tab == 0)
                                      ...home()
                                    else if (tab == 1)
                                      ...billsPage()
                                    else if (tab == 2)
                                      ...subscriptionsPage()
                                    else
                                      ...profilePage()
                                  ],
                                  const SizedBox(height: 18),
                                ]))))),
        bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (v) => setState(() => tab = v),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Accueil'),
              NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Factures'),
              NavigationDestination(
                  icon: Icon(Icons.electrical_services_outlined),
                  label: 'Abonnements'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profil'),
            ]),
      );
}

class LinkScreen extends StatelessWidget {
  const LinkScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ajouter un abonnement')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 15),
          const Align(
            alignment: Alignment.centerLeft,
            child: CircleAvatar(
              radius: 33,
              backgroundColor: Color(0xFFE7F0FC),
              child: Icon(Icons.add_home_outlined, color: blue, size: 32),
            ),
          ),
          const SizedBox(height: 26),
          Text('Association à valider',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 13),
          const Text(
              'L’accès aux factures nécessite de vérifier que le contrat vous appartient. Une référence de compteur seule ne suffit pas.'),
          const SizedBox(height: 20),
          const InfoBanner(
              'Le rattachement automatique SBEE n’est pas encore connecté. Aucun abonnement fictif ne sera ajouté à votre compte.'),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Retour'),
          ),
        ]),
      );
}

class InvoiceScreen extends StatefulWidget {
  final Api api;
  final Json invoice;
  const InvoiceScreen({super.key, required this.api, required this.invoice});
  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  late Json invoice;
  String? error;
  bool checking = false;
  @override
  void initState() {
    super.initState();
    invoice = widget.invoice;
    reload();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Json? get payment => invoice['payment'] == null
      ? null
      : Map<String, dynamic>.from(invoice['payment'] as Map);
  Future<void> reload() async {
    if (checking) return;
    checking = true;
    try {
      final result = await widget.api.get('/invoices/${invoice['id']}');
      if (mounted) {
        setState(() {
          invoice = result;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      checking = false;
    }
  }

  Future<void> pay() async {
    if (!SupabaseConfig.paymentTestMode) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Paiement indisponible'),
          content: const Text(
              'Aucun prestataire de paiement n’est connecté. Aucun débit ne sera effectué.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paiement de test'),
        content: const Text(
          'Simulation pour l’exposé, sans argent. Une ligne « paid_test » sera enregistrée dans la table test_payments de Supabase et visible par le client et l’admin. '
          'La facture réelle reste due : aucune ligne de paiement réel ou de reçu n’est créée et aucun débit n’a lieu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Simuler le paiement'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final updated =
          await widget.api.createTestPayment(invoice['id'].toString());
      if (!mounted) return;
      setState(() {
        invoice = updated;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paiement TEST réussi'),
        content: const Text(
          'Le paiement TEST est enregistré dans Supabase et apparaît « Payée · TEST » au client et à l’admin. Le statut officiel de la facture reste dû; aucun argent ni reçu réel.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  Future<void> receipt() async {
    final id = payment?['receipt_id'];
    if (id == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            ReceiptScreen(api: widget.api, receiptId: id as String)));
  }

  @override
  Widget build(BuildContext context) {
    final persistedPaid = invoice['status'] == 'paid';
    final testPayment = invoice['test_payment'] as Json?;
    final simulatedPaid =
        testPayment?['status'] == 'paid_test' && !persistedPaid;
    final pending = payment?['status'] == 'pending';
    return Scaffold(
        appBar: AppBar(title: const Text('Ma facture'), actions: [
          IconButton(
              onPressed: reload,
              tooltip: 'Actualiser le statut',
              icon: const Icon(Icons.refresh_rounded))
        ]),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          Row(children: [
            Expanded(
                child: Text(invoice['id'] as String,
                    style: const TextStyle(
                        color: muted, fontSize: 11, letterSpacing: .4))),
            StatusPill(simulatedPaid
                ? 'test_paid'
                : pending
                    ? 'pending'
                    : invoice['status'] as String)
          ]),
          const SizedBox(height: 14),
          Text(invoice['period'] as String,
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 5),
          Text('${invoice['label']} · ${invoice['sub_id']}'),
          const SizedBox(height: 25),
          if (simulatedPaid) ...[
            const InfoBanner(
                'PAIEMENT TEST enregistré dans Supabase : « Payée · TEST ». Le statut officiel de la facture reste dû; aucun débit ni reçu réel.'),
            const SizedBox(height: 18)
          ] else if (persistedPaid) ...[
            const InfoBanner(
                'Le paiement est confirmé. Votre reçu est disponible.'),
            const SizedBox(height: 18)
          ] else if (pending) ...[
            const InfoBanner(
                'Confirmation en cours. Actualisez le statut avant toute autre action.'),
            const SizedBox(height: 18)
          ] else if (payment?['status'] == 'failed') ...[
            const InfoBanner(
                'Le prestataire a refusé cette transaction. Aucun paiement confirmé.',
                error: true),
            const SizedBox(height: 18)
          ] else if (SupabaseConfig.paymentTestMode) ...[
            const InfoBanner(
                'MODE TEST activé : tu peux simuler le paiement sans argent. Une ligne « paid_test » sera enregistrée dans Supabase; le statut officiel de la facture restera dû.'),
            const SizedBox(height: 18)
          ] else ...[
            const InfoBanner(
                'Le paiement en ligne n’est pas encore configuré. Aucun débit ne peut être réalisé.'),
            const SizedBox(height: 18)
          ],
          Surface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('MONTANT DE LA FACTURE',
                    style: TextStyle(
                        fontSize: 10, color: muted, letterSpacing: 1.2)),
                const SizedBox(height: 11),
                Text('${money(invoice['amount'])} FCFA',
                    style: const TextStyle(
                        fontSize: 34,
                        letterSpacing: -1,
                        fontWeight: FontWeight.w700,
                        color: ink)),
                const SizedBox(height: 9),
                detailRow('Échéance', displayDate(invoice['due'] as String))
              ])),
          sectionTitle('Votre consommation'),
          Surface(
              child: Column(children: [
            detailRow('Index précédent', '${invoice['previous_index']} kWh'),
            detailRow('Index actuel', '${invoice['current_index']} kWh'),
            const Divider(color: line),
            detailRow('Consommation', '${invoice['consumption']} kWh',
                strong: true)
          ])),
          sectionTitle('Comprendre le montant'),
          Surface(
              child: Column(children: [
            detailRow('Énergie', '${money(invoice['energy'])} F'),
            detailRow('Frais et abonnement', '${money(invoice['fees'])} F'),
            const Divider(color: line),
            detailRow('Total', '${money(invoice['amount'])} FCFA', strong: true)
          ])),
          const SizedBox(height: 22),
          if (error != null) ...[
            InfoBanner(error!, error: true),
            const SizedBox(height: 15),
            TextButton(
                onPressed: reload, child: const Text('Vérifier le statut'))
          ],
          AppButton(
            persistedPaid
                ? 'Consulter mon reçu'
                : simulatedPaid
                    ? 'Paiement de test effectué'
                    : pending
                        ? 'Vérifier la confirmation'
                        : SupabaseConfig.paymentTestMode
                            ? 'Simuler le paiement (test)'
                            : 'Paiement en ligne indisponible',
            busy: checking,
            onPressed: persistedPaid
                ? receipt
                : simulatedPaid
                    ? null
                    : pending
                        ? reload
                        : pay,
            icon: persistedPaid
                ? Icons.receipt_long_outlined
                : simulatedPaid
                    ? Icons.check_circle_outline_rounded
                    : SupabaseConfig.paymentTestMode
                        ? Icons.science_outlined
                        : Icons.arrow_forward_rounded,
          ),
          const SizedBox(height: 18),
        ]));
  }
}

class ReceiptScreen extends StatefulWidget {
  final Api api;
  final String receiptId;
  const ReceiptScreen({super.key, required this.api, required this.receiptId});
  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  Json? data;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.api.get('/receipts/${widget.receiptId}');
      if (mounted) {
        setState(() {
          data = result;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Mon reçu')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        if (data == null && error == null)
          const Center(child: CircularProgressIndicator()),
        if (error != null) ...[
          InfoBanner(error!, error: true),
          TextButton(onPressed: load, child: const Text('Réessayer'))
        ],
        if (data != null) ...[
          const SizedBox(height: 20),
          const Center(
              child: CircleAvatar(
                  radius: 38,
                  backgroundColor: Color(0xFFE4F4EA),
                  child: Icon(Icons.check_rounded,
                      color: Color(0xFF216B48), size: 44))),
          const SizedBox(height: 20),
          Text('Paiement confirmé',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text('Le reçu de votre opération', textAlign: TextAlign.center),
          const SizedBox(height: 25),
          Surface(
              child: Column(children: [
            Text('${money(data!['amount'])} FCFA',
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    letterSpacing: -1)),
            const SizedBox(height: 20),
            const Divider(color: line),
            detailRow('Référence', data!['id'] as String),
            detailRow('Abonnement', data!['subscription_id'] as String),
            detailRow('Facture', data!['invoice_id'] as String),
            detailRow('Période', data!['period'] as String),
            detailRow('Transaction', data!['transaction_id'] as String),
            detailRow(
                'Date',
                DateTime.fromMillisecondsSinceEpoch(
                        ((data!['created'] as num) * 1000).round())
                    .toLocal()
                    .toString()
                    .substring(0, 19))
          ])),
          const SizedBox(height: 20),
          const InfoBanner(
              'Ce reçu correspond à un paiement enregistré et confirmé par le serveur.'),
          const SizedBox(height: 24),
          OutlinedButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(
                    text: '${data!['id']} · ${money(data!['amount'])} FCFA'));
                if (!mounted) return;
                messenger.showSnackBar(
                    const SnackBar(content: Text('Référence copiée.')));
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copier la référence')),
          const SizedBox(height: 18),
        ],
      ]));
}
