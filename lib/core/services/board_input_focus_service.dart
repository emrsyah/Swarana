import 'package:flutter/foundation.dart';

class BoardInputFocusService {
  BoardInputFocusService._();

  static final ValueNotifier<int> requests = ValueNotifier(0);

  static void requestFocus() {
    requests.value++;
  }
}
