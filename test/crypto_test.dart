import 'package:flutter_test/flutter_test.dart';

import '../tool/crypto_self_check.dart' as checks;

void main() {
  test('native libsodium vault and recovery checks', checks.main);
}
