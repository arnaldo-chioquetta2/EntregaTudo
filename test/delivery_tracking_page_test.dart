import 'package:flutter_test/flutter_test.dart';

import 'package:entregatudo/marketplace/screens/delivery_tracking_page.dart';

void main() {
  test('identifica estados finais do tracking', () {
    expect(isTerminalDeliveryStatus('delivered'), isTrue);
    expect(isTerminalDeliveryStatus('cancelled'), isTrue);
    expect(isTerminalDeliveryStatus('driver_assigned'), isFalse);
    expect(isTerminalDeliveryStatus('collected'), isFalse);
    expect(isTerminalDeliveryStatus(null), isFalse);
  });
}
