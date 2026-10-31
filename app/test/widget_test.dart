import 'package:flutter_test/flutter_test.dart';
import 'package:mon_electricite/api.dart';
import 'package:mon_electricite/main.dart';

class _FakeApi extends Api {
  @override
  bool get hasSession => false;
}

void main() {
  testWidgets('The initial application shows the customer login',
      (tester) async {
    await tester.pumpWidget(ElectricityApp(api: _FakeApi()));
    expect(find.text('Mon Électricité'), findsOneWidget);
    expect(find.text('Heureux de vous revoir'), findsOneWidget);
    expect(find.text('ESPACE CLIENT'), findsOneWidget);
  });
}
