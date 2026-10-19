import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('App renders PowerBid home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AuctionGameApp());

    // Verify that the PowerBid branding subtitle exists.
    expect(find.text('REAL-TIME MULTIPLAYER AUCTION'), findsOneWidget);

    // Verify that the 'Play Online' button exists.
    expect(find.text('PLAY ONLINE'), findsOneWidget);
  });
}
