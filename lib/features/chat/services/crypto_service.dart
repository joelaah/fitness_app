import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:fitness_app/core/config/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Container for encrypted message payload matching
/// PROJECT.md § Cryptographic Protocol Contract.
class EncryptedPayload {
  const EncryptedPayload({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
  });

  /// Base64 string of raw AES ciphertext + 16-byte GCM tag.
  final String ciphertext;

  /// Base64 string of 12-byte CSPRNG IV.
  final String nonce;

  /// Base64 string of 16-byte authentication tag.
  final String mac;

  Map<String, String> toJson() => <String, String>{
    'ciphertext': ciphertext,
    'nonce': nonce,
    'mac': mac,
  };
}

/// Service implementing Signal-Protocol-style client-side end-to-end
/// encryption.
///
/// Features:
/// - X25519 ECDH key agreement.
/// - HKDF-SHA256 key derivation with Salt `b"PulseFit-E2EE-v1-Salt"`,
///   Info `b"PulseFit-AES-256-GCM-Key"`, 32-byte output.
/// - AES-256-GCM authenticated encryption/decryption with 96-bit
///   (12-byte) random nonces.
/// - Zero plaintext in ciphertext or database wire payload.
/// - Local key persistence and Supabase public key publishing.
class CryptoService {
  CryptoService({
    String storagePrefix = 'default',
    SupabaseClient? supabaseClient,
    SharedPreferences? sharedPreferences,
    X25519? x25519,
    Hkdf? hkdf,
    AesGcm? aesGcm,
  }) : _storagePrefix = storagePrefix,
       _supabaseClient = supabaseClient,
       _sharedPreferences = sharedPreferences,
       _x25519 = x25519 ?? X25519(),
       _hkdf =
           hkdf ??
           Hkdf(
             hmac: Hmac.sha256(),
             outputLength: 32,
           ),
       _aesGcm = aesGcm ?? AesGcm.with256bits();

  static const String hkdfSaltString = 'PulseFit-E2EE-v1-Salt';
  static const String hkdfInfoString = 'PulseFit-AES-256-GCM-Key';

  final String _storagePrefix;
  String get _prefPrivateKey => 'e2ee_x25519_private_key_$_storagePrefix';
  String get _prefPublicKey => 'e2ee_x25519_public_key_$_storagePrefix';

  final SupabaseClient? _supabaseClient;
  final SharedPreferences? _sharedPreferences;
  final X25519 _x25519;
  final Hkdf _hkdf;
  final AesGcm _aesGcm;

  SimpleKeyPair? _myKeyPair;
  final Map<String, SecretKey> _sessionKeys = <String, SecretKey>{};
  final Map<String, String> _peerPublicKeys = <String, String>{};

  SupabaseClient? get _supabase {
    if (_supabaseClient != null) return _supabaseClient;
    if (SupabaseConfig.isInitialized) {
      return Supabase.instance.client;
    }
    return null;
  }

  /// Sets or overrides current user's key pair directly (useful for tests).
  void setKeyPair(SimpleKeyPair keyPair) {
    _myKeyPair = keyPair;
    _sessionKeys.clear();
  }

  /// Manually registers a peer's public key (e.g. for offline demonstration).
  void registerPeerPublicKey(String userId, String base64PublicKey) {
    _peerPublicKeys[userId] = base64PublicKey;
    _sessionKeys.remove(userId);
  }

  /// Clears in-memory session key cache.
  void clearSessionKeys() {
    _sessionKeys.clear();
  }

  /// Retrieves or generates the user's persistent X25519 key pair.
  Future<SimpleKeyPair> getOrCreateKeyPair() async {
    if (_myKeyPair != null) return _myKeyPair!;

    final prefs = _sharedPreferences ?? await SharedPreferences.getInstance();
    final savedPrivBase64 = prefs.getString(_prefPrivateKey);
    final savedPubBase64 = prefs.getString(_prefPublicKey);

    if (savedPrivBase64 != null && savedPubBase64 != null) {
      try {
        final privBytes = base64.decode(savedPrivBase64);
        final pubBytes = base64.decode(savedPubBase64);

        if (privBytes.length == 32 && pubBytes.length == 32) {
          final pubKey = SimplePublicKey(pubBytes, type: KeyPairType.x25519);
          final keyPair = SimpleKeyPairData(
            privBytes,
            publicKey: pubKey,
            type: KeyPairType.x25519,
          );
          _myKeyPair = keyPair;
          return keyPair;
        }
      } on Object catch (e) {
        debugPrint(
          'Error restoring stored X25519 key pair: $e. Generating new.',
        );
      }
    }

    // Generate fresh keypair
    final newPair = await _x25519.newKeyPair();
    final pubKey = await newPair.extractPublicKey();
    final privBytes = await newPair.extractPrivateKeyBytes();

    final privBase64 = base64.encode(privBytes);
    final pubBase64 = base64.encode(pubKey.bytes);

    await prefs.setString(_prefPrivateKey, privBase64);
    await prefs.setString(_prefPublicKey, pubBase64);

    _myKeyPair = newPair;
    return newPair;
  }

  /// Returns user's 32-byte X25519 public key as Base64 string (44 chars).
  Future<String> getMyPublicKeyBase64() async {
    final keyPair = await getOrCreateKeyPair();
    final pubKey = await keyPair.extractPublicKey();
    return base64.encode(pubKey.bytes);
  }

  /// Publishes current user's public key to Supabase `encryption_keys` table.
  Future<void> publishPublicKey({String? userId}) async {
    final client = _supabase;
    final pubKeyBase64 = await getMyPublicKeyBase64();
    final effectiveUserId =
        userId ?? client?.auth.currentUser?.id ?? 'user-athlete-1';

    if (client == null) {
      debugPrint(
        'CryptoService: Supabase uninitialized, cached public key locally.',
      );
      _peerPublicKeys[effectiveUserId] = pubKeyBase64;
      return;
    }

    try {
      await client.from('encryption_keys').upsert(<String, dynamic>{
        'user_id': effectiveUserId,
        'public_key': pubKeyBase64,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on Object catch (e) {
      debugPrint('CryptoService publishPublicKey error: $e');
    }
  }

  /// Resolves the peer's public key from cache or Supabase `encryption_keys`.
  Future<String> getPeerPublicKey(String peerUserId) async {
    if (_peerPublicKeys.containsKey(peerUserId)) {
      return _peerPublicKeys[peerUserId]!;
    }

    final client = _supabase;
    if (client != null) {
      try {
        final row = await client
            .from('encryption_keys')
            .select('public_key')
            .eq('user_id', peerUserId)
            .maybeSingle();

        if (row != null && row['public_key'] is String) {
          final pk = row['public_key'] as String;
          _peerPublicKeys[peerUserId] = pk;
          return pk;
        }
      } on Object catch (e) {
        debugPrint('CryptoService getPeerPublicKey error: $e');
      }
    }

    // Default / fallback deterministic key for offline / preview mode
    final fallbackBytes = List<int>.generate(32, (i) => (i * 7 + 13) % 256);
    final fallback = base64.encode(fallbackBytes);
    _peerPublicKeys[peerUserId] = fallback;
    return fallback;
  }

  /// Derives symmetric 256-bit AES-GCM key for communication with [peerUserId]
  /// using X25519 ECDH + HKDF-SHA256 with domain separation.
  Future<SecretKey> getSharedKey(
    String peerUserId, {
    String? peerPublicKeyBase64,
  }) async {
    if (_sessionKeys.containsKey(peerUserId)) {
      return _sessionKeys[peerUserId]!;
    }

    final resolvedPeerPubBase64 =
        peerPublicKeyBase64 ?? await getPeerPublicKey(peerUserId);
    final peerPubBytes = base64.decode(resolvedPeerPubBase64);

    if (peerPubBytes.length != 32) {
      throw ArgumentError(
        'Invalid X25519 public key length: '
        'expected 32 bytes, got ${peerPubBytes.length}',
      );
    }

    final remotePublicKey = SimplePublicKey(
      peerPubBytes,
      type: KeyPairType.x25519,
    );

    final myKeyPair = await getOrCreateKeyPair();

    // 1. X25519 ECDH Key Agreement
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: remotePublicKey,
    );

    // 2. HKDF-SHA256 Key Derivation (32 bytes output)
    final derivedKey = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: utf8.encode(hkdfSaltString),
      info: utf8.encode(hkdfInfoString),
    );

    _sessionKeys[peerUserId] = derivedKey;
    return derivedKey;
  }

  /// Encrypts plaintext message client-side with AES-256-GCM and fresh nonce.
  Future<EncryptedPayload> encrypt({
    required String plaintext,
    required String recipientUserId,
    String? recipientPublicKeyBase64,
  }) async {
    final key = await getSharedKey(
      recipientUserId,
      peerPublicKeyBase64: recipientPublicKeyBase64,
    );

    final plaintextBytes = utf8.encode(plaintext);

    // Fresh 96-bit (12-byte) CSPRNG nonce
    final random = Random.secure();
    final nonceBytes = List<int>.generate(12, (_) => random.nextInt(256));

    final secretBox = await _aesGcm.encrypt(
      plaintextBytes,
      secretKey: key,
      nonce: nonceBytes,
    );

    // Wire format per PROJECT.md:
    // ciphertext contains raw AES ciphertext + 16-byte GCM authentication tag
    final wireCiphertextBytes = <int>[
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ];

    return EncryptedPayload(
      ciphertext: base64.encode(wireCiphertextBytes),
      nonce: base64.encode(secretBox.nonce),
      mac: base64.encode(secretBox.mac.bytes),
    );
  }

  /// Decrypts ciphertext message client-side with AES-256-GCM.
  /// Authenticates against 128-bit MAC tag; throws on bit-level tampering.
  Future<String> decrypt({
    required String ciphertext,
    required String nonce,
    required String peerUserId,
    String mac = '',
    String? peerPublicKeyBase64,
  }) async {
    final key = await getSharedKey(
      peerUserId,
      peerPublicKeyBase64: peerPublicKeyBase64,
    );

    final cipherBytes = base64.decode(ciphertext);
    final nonceBytes = base64.decode(nonce);

    if (nonceBytes.length != 12) {
      throw ArgumentError(
        'Invalid nonce length: expected 12 bytes, got ${nonceBytes.length}',
      );
    }

    List<int> rawCipher;
    List<int> tag;

    if (mac.isNotEmpty) {
      final macBytes = base64.decode(mac);
      if (macBytes.length != 16) {
        throw ArgumentError('Invalid MAC length: expected 16 bytes');
      }

      if (cipherBytes.length >= 16 &&
          _listEquals(
            cipherBytes.sublist(cipherBytes.length - 16),
            macBytes,
          )) {
        rawCipher = cipherBytes.sublist(0, cipherBytes.length - 16);
        tag = macBytes;
      } else {
        rawCipher = cipherBytes;
        tag = macBytes;
      }
    } else {
      if (cipherBytes.length < 16) {
        throw ArgumentError(
          'Ciphertext is too short: must contain at least 16 bytes of GCM tag',
        );
      }
      rawCipher = cipherBytes.sublist(0, cipherBytes.length - 16);
      tag = cipherBytes.sublist(cipherBytes.length - 16);
    }

    final secretBox = SecretBox(
      rawCipher,
      nonce: nonceBytes,
      mac: Mac(tag),
    );

    final decryptedBytes = await _aesGcm.decrypt(
      secretBox,
      secretKey: key,
    );

    return utf8.decode(decryptedBytes);
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
