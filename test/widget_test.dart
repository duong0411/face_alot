import 'package:flutter_test/flutter_test.dart';
import 'package:face_alot/main.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const FaceAlotApp());
    expect(find.byType(FaceAlotApp), findsOneWidget);
  });
}
