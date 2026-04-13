import 'dart:convert';

/// Constant-time string comparison to prevent timing attacks on secrets such
/// as API keys.
///
/// Returns `true` if [a] and [b] contain the same bytes. The comparison runs
/// in time proportional to the length of the inputs and does not short-circuit
/// on the first differing byte, so an attacker cannot infer how many leading
/// characters they guessed correctly by measuring response time.
bool constantTimeEquals(String a, String b) {
  final aBytes = utf8.encode(a);
  final bBytes = utf8.encode(b);
  if (aBytes.length != bBytes.length) return false;
  var result = 0;
  for (var i = 0; i < aBytes.length; i++) {
    result |= aBytes[i] ^ bBytes[i];
  }
  return result == 0;
}
