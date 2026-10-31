import 'package:flutter/material.dart';

const navy = Color(0xFF142C46);
const blue = Color(0xFF1456A0);
const amber = Color(0xFFFFD15C);
const paper = Color(0xFFF4F7FB);
const ink = Color(0xFF142C46);
const muted = Color(0xFF64758A);
const line = Color(0xFFE4EAF1);

String money(dynamic value) => '${value ?? 0}'
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
String displayDate(String date) {
  final parts = date.split('-');
  return parts.length == 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : date;
}

ThemeData appTheme() => ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(seedColor: blue, brightness: Brightness.light),
      scaffoldBackgroundColor: paper,
      appBarTheme: const AppBarTheme(
          backgroundColor: paper,
          foregroundColor: ink,
          surfaceTintColor: Colors.transparent,
          centerTitle: false),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.3,
            color: ink),
        headlineMedium: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w700,
            letterSpacing: -.8,
            color: ink),
        titleLarge:
            TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: ink),
        titleMedium:
            TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: muted),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: const BorderSide(color: line),
        foregroundColor: ink,
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: blue, width: 2)),
      ),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE9F1FD),
          labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
    );

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Surface(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20)});
  @override
  Widget build(BuildContext context) => Container(
      padding: padding,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: line)),
      child: child);
}

class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final testPaid = status == 'test_paid';
    final good = status == 'paid' || status == 'success';
    final failed = status == 'failed';
    final label = testPaid
        ? 'Payée · TEST'
        : good
            ? 'Payée'
            : failed
                ? 'Échec confirmé'
                : status == 'pending'
                    ? 'En attente'
                    : 'À payer';
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: testPaid
                ? const Color(0xFFFFF1D7)
                : good
                    ? const Color(0xFFE5F4EB)
                    : failed
                        ? const Color(0xFFFDEAEA)
                        : const Color(0xFFFFF1D7),
            borderRadius: BorderRadius.circular(9)),
        child: Text(label,
            style: TextStyle(
                color: testPaid
                    ? const Color(0xFF81500C)
                    : good
                        ? const Color(0xFF216B48)
                        : failed
                            ? const Color(0xFFA63D3D)
                            : const Color(0xFF81500C),
                fontSize: 12,
                fontWeight: FontWeight.w700)));
  }
}

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  const AppButton(this.text,
      {super.key, this.onPressed, this.busy = false, this.icon});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: Text(text, textAlign: TextAlign.center)),
                if (icon != null) ...[
                  const SizedBox(width: 9),
                  Icon(icon, size: 20)
                ],
              ]),
      ));
}

class InfoBanner extends StatelessWidget {
  final String text;
  final bool error;
  const InfoBanner(this.text, {super.key, this.error = false});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: error ? const Color(0xFFFFECEB) : const Color(0xFFEAF1FA),
          borderRadius: BorderRadius.circular(15)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 20, color: error ? Colors.red.shade800 : blue),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    color: error ? Colors.red.shade900 : navy,
                    fontSize: 13,
                    height: 1.5))),
      ]));
}

Widget detailRow(String label, String value, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Text(label, style: const TextStyle(color: muted))),
      const SizedBox(width: 16),
      Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: ink,
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w500))),
    ]));

Widget sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 25, bottom: 13),
    child: Text(title,
        style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w700, color: ink)));
