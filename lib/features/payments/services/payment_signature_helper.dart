import 'dart:convert';
import 'dart:typed_data';

/// Pure-Dart HMAC-SHA256 generator with zero external pub dependencies.
/// Guarantees exact byte-for-byte signature match with Python hmac.new.
class PaymentSignatureHelper {
  static const String defaultTestSecret = 'rzp_test_secret_998877665544';

  /// Computes Razorpay checkout HMAC-SHA256 signature for
  /// "${orderId}|${paymentId}".
  static String computeRazorpaySignature({
    required String orderId,
    required String paymentId,
    String secret = defaultTestSecret,
  }) {
    final message = '$orderId|$paymentId';
    return hmacSha256(secret, message);
  }

  /// Calculates HMAC-SHA256 hex digest using RFC 2104 algorithm.
  static String hmacSha256(String key, String message) {
    final keyBytes = utf8.encode(key);
    final messageBytes = utf8.encode(message);

    const blockSize = 64;
    final k = Uint8List(blockSize);

    if (keyBytes.length > blockSize) {
      final keyHash = _sha256(Uint8List.fromList(keyBytes));
      k.setRange(0, keyHash.length, keyHash);
    } else {
      k.setRange(0, keyBytes.length, keyBytes);
    }

    final oPad = Uint8List(blockSize);
    final iPad = Uint8List(blockSize);
    for (var i = 0; i < blockSize; i++) {
      oPad[i] = k[i] ^ 0x5c;
      iPad[i] = k[i] ^ 0x36;
    }

    final inner = Uint8List(iPad.length + messageBytes.length)
      ..setRange(0, iPad.length, iPad)
      ..setRange(iPad.length, iPad.length + messageBytes.length, messageBytes);
    final innerHash = _sha256(inner);

    final outer = Uint8List(oPad.length + innerHash.length)
      ..setRange(0, oPad.length, oPad)
      ..setRange(oPad.length, oPad.length + innerHash.length, innerHash);
    final outerHash = _sha256(outer);

    final buffer = StringBuffer();
    for (final b in outerHash) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static Uint8List _sha256(Uint8List data) {
    // SHA-256 standard round constants
    const k = <int>[
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
      0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
      0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
      0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
      0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
      0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
      0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
      0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
      0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
      0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
      0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
      0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
      0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];

    var h0 = 0x6a09e667;
    var h1 = 0xbb67ae85;
    var h2 = 0x3c6ef372;
    var h3 = 0xa54ff53a;
    var h4 = 0x510e527f;
    var h5 = 0x9b05688c;
    var h6 = 0x1f83d9ab;
    var h7 = 0x5be0cd19;

    final length = data.length;
    final bitLength = length * 8;
    final padLength = ((length + 8) ~/ 64 + 1) * 64;
    final padded = Uint8List(padLength)..setRange(0, length, data);
    padded[length] = 0x80;

    final view = ByteData.view(padded.buffer)
      ..setUint32(padLength - 4, bitLength & 0xFFFFFFFF)
      ..setUint32(padLength - 8, (bitLength >> 32) & 0xFFFFFFFF);

    final w = List<int>.filled(64, 0);

    for (var chunk = 0; chunk < padLength; chunk += 64) {
      for (var i = 0; i < 16; i++) {
        w[i] = view.getUint32(chunk + i * 4);
      }
      for (var i = 16; i < 64; i++) {
        final s0 =
            _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
        final s1 =
            _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
      }

      var a = h0;
      var b = h1;
      var c = h2;
      var d = h3;
      var e = h4;
      var f = h5;
      var g = h6;
      var h = h7;

      for (var i = 0; i < 64; i++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ (~e & g);
        final temp1 = (h + s1 + ch + k[i] + w[i]) & 0xFFFFFFFF;
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xFFFFFFFF;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + h) & 0xFFFFFFFF;
    }

    final out = Uint8List(32);
    ByteData.view(out.buffer)
      ..setUint32(0, h0)
      ..setUint32(4, h1)
      ..setUint32(8, h2)
      ..setUint32(12, h3)
      ..setUint32(16, h4)
      ..setUint32(20, h5)
      ..setUint32(24, h6)
      ..setUint32(28, h7);
    return out;
  }

  static int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;
}
