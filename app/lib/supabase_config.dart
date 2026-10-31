/// Public client configuration for the SBEE Supabase project.
/// The publishable key is intended for client apps; database access is
/// restricted by PostgreSQL grants and RLS policies. Never put a service_role
/// key in this file or in the Flutter app.
class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ncgtfhsfnwhokewfcslh.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_EyZewAQp45zJbv63DbVHMg_q0McGRri',
  );

  /// Local-only payment simulation. Disable for production with
  /// --dart-define=PAYMENT_TEST_MODE=false. This never writes payment data.
  static const paymentTestMode = bool.fromEnvironment(
    'PAYMENT_TEST_MODE',
    defaultValue: true,
  );
}
