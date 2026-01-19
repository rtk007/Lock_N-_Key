import 'package:encrypt/encrypt.dart';

void main() {
  final iv1 = IV.fromLength(16);
  final iv2 = IV.fromLength(16);
  
  print('IV1: ${iv1.base64}');
  print('IV2: ${iv2.base64}');
  
  if (iv1.base64 == iv2.base64) {
    print('IV is CONSTANT/DETERMINISTIC');
  } else {
    print('IV is RANDOM');
  }
}
