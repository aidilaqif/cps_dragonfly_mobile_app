// import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postgres/postgres.dart';
import 'package:cps_dragonfly_4_mobile_app/main.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'widget_test.mocks.dart';

@GenerateMocks([PostgreSQLConnection])
void main() {
  late MockPostgreSQLConnection mockConnection;

  setUp(() {
    mockConnection = MockPostgreSQLConnection();
    when(mockConnection.open()).thenAnswer((_) async => {});
  });

  testWidgets('Basic app test', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(connection: mockConnection));
    expect(find.text('CPS Dragonfly 4.0'), findsOneWidget);
  });
}