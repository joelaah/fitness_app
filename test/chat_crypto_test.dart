import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:fitness_app/features/chat/services/crypto_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Signal-Protocol E2EE CryptoService Unit Tests', () {
    late CryptoService aliceCrypto;
    late CryptoService bobCrypto;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      aliceCrypto = CryptoService(storagePrefix: 'alice');
      bobCrypto = CryptoService(storagePrefix: 'bob');
    });

    test(
      'X25519 key agreement symmetry produces identical 32-byte shared secret',
      () async {
        final aliceKeyPair = await aliceCrypto.getOrCreateKeyPair();
        final bobKeyPair = await bobCrypto.getOrCreateKeyPair();

        final alicePub = await aliceKeyPair.extractPublicKey();
        final bobPub = await bobKeyPair.extractPublicKey();

        expect(alicePub.bytes.length, 32);
        expect(bobPub.bytes.length, 32);
        expect(alicePub.bytes, isNot(equals(bobPub.bytes)));

        final x25519 = X25519();
        final aliceShared = await x25519.sharedSecretKey(
          keyPair: aliceKeyPair,
          remotePublicKey: bobPub,
        );
        final bobShared = await x25519.sharedSecretKey(
          keyPair: bobKeyPair,
          remotePublicKey: alicePub,
        );

        final aliceSharedBytes = await aliceShared.extractBytes();
        final bobSharedBytes = await bobShared.extractBytes();

        expect(aliceSharedBytes.length, 32);
        expect(bobSharedBytes.length, 32);
        expect(aliceSharedBytes, equals(bobSharedBytes));
      },
    );

    test(
      'HKDF-SHA256 derives 256-bit symmetric key with domain separation',
      () async {
        final alicePubBase64 = await aliceCrypto.getMyPublicKeyBase64();
        final bobPubBase64 = await bobCrypto.getMyPublicKeyBase64();

        aliceCrypto.registerPeerPublicKey('bob-id', bobPubBase64);
        bobCrypto.registerPeerPublicKey('alice-id', alicePubBase64);

        final aliceKey = await aliceCrypto.getSharedKey('bob-id');
        final bobKey = await bobCrypto.getSharedKey('alice-id');

        final aliceKeyBytes = await aliceKey.extractBytes();
        final bobKeyBytes = await bobKey.extractBytes();

        expect(
          aliceKeyBytes.length,
          32,
          reason: '256-bit AES key must be 32 bytes',
        );
        expect(bobKeyBytes.length, 32);
        expect(aliceKeyBytes, equals(bobKeyBytes));

        // Domain separation with a third party Eve
        final eveCrypto = CryptoService(storagePrefix: 'eve');
        final evePubBase64 = await eveCrypto.getMyPublicKeyBase64();
        aliceCrypto.registerPeerPublicKey('eve-id', evePubBase64);

        final aliceEveKey = await aliceCrypto.getSharedKey('eve-id');
        final aliceEveKeyBytes = await aliceEveKey.extractBytes();

        expect(aliceEveKeyBytes, isNot(equals(aliceKeyBytes)));
      },
    );

    test(
      'AES-256-GCM round-trip encryption and decryption with emojis & unicode',
      () async {
        final alicePubBase64 = await aliceCrypto.getMyPublicKeyBase64();
        final bobPubBase64 = await bobCrypto.getMyPublicKeyBase64();

        aliceCrypto.registerPeerPublicKey('bob-id', bobPubBase64);
        bobCrypto.registerPeerPublicKey('alice-id', alicePubBase64);

        final testMessages = <String>[
          'Good morning coach! Ready for leg day.',
          'Squat: 140kg x 5, RDL: 120kg x 8, Leg Press: 240kg x 12.',
          'Unicode & emojis: 🏋️‍♂️💪🔥 Keep your knees tracked over toes!',
          'Special characters: ~!@#\$%^&*()_+`-={}|[]\\:";\'<>?,./',
        ];

        for (final msg in testMessages) {
          // Alice encrypts for Bob
          final encrypted = await aliceCrypto.encrypt(
            plaintext: msg,
            recipientUserId: 'bob-id',
          );

          // Zero-knowledge verification: wire payload contains NO plaintext
          expect(encrypted.ciphertext.contains(msg), isFalse);
          expect(msg.contains(encrypted.ciphertext), isFalse);
          expect(base64.decode(encrypted.nonce).length, 12);
          expect(base64.decode(encrypted.mac).length, 16);

          // Bob decrypts from Alice
          final decrypted = await bobCrypto.decrypt(
            ciphertext: encrypted.ciphertext,
            nonce: encrypted.nonce,
            mac: encrypted.mac,
            peerUserId: 'alice-id',
          );

          expect(decrypted, equals(msg));
        }
      },
    );

    test(
      'tamper resistance: single bit flip in ciphertext fails authentication',
      () async {
        final alicePubBase64 = await aliceCrypto.getMyPublicKeyBase64();
        final bobPubBase64 = await bobCrypto.getMyPublicKeyBase64();

        aliceCrypto.registerPeerPublicKey('bob-id', bobPubBase64);
        bobCrypto.registerPeerPublicKey('alice-id', alicePubBase64);

        final encrypted = await aliceCrypto.encrypt(
          plaintext: 'Top secret workout schedule',
          recipientUserId: 'bob-id',
        );

        final cipherBytes = base64.decode(encrypted.ciphertext);
        final tamperedBytes = List<int>.from(cipherBytes);
        tamperedBytes[3] ^= 0x01; // flip single bit
        final tamperedCiphertext = base64.encode(tamperedBytes);

        expect(
          () async => bobCrypto.decrypt(
            ciphertext: tamperedCiphertext,
            nonce: encrypted.nonce,
            mac: encrypted.mac,
            peerUserId: 'alice-id',
          ),
          throwsA(anything),
        );
      },
    );

    test(
      'tamper resistance: modified nonce fails decryption authentication',
      () async {
        final alicePubBase64 = await aliceCrypto.getMyPublicKeyBase64();
        final bobPubBase64 = await bobCrypto.getMyPublicKeyBase64();

        aliceCrypto.registerPeerPublicKey('bob-id', bobPubBase64);
        bobCrypto.registerPeerPublicKey('alice-id', alicePubBase64);

        final encrypted = await aliceCrypto.encrypt(
          plaintext: 'Workout session confirmation',
          recipientUserId: 'bob-id',
        );

        final nonceBytes = base64.decode(encrypted.nonce);
        final tamperedNonceBytes = List<int>.from(nonceBytes);
        tamperedNonceBytes[0] ^= 0x01; // tamper with nonce
        final tamperedNonce = base64.encode(tamperedNonceBytes);

        expect(
          () async => bobCrypto.decrypt(
            ciphertext: encrypted.ciphertext,
            nonce: tamperedNonce,
            mac: encrypted.mac,
            peerUserId: 'alice-id',
          ),
          throwsA(anything),
        );
      },
    );

    test(
      'unauthorized recipient / wrong key fails decryption immediately',
      () async {
        final alicePubBase64 = await aliceCrypto.getMyPublicKeyBase64();
        final bobPubBase64 = await bobCrypto.getMyPublicKeyBase64();

        aliceCrypto.registerPeerPublicKey('bob-id', bobPubBase64);
        bobCrypto.registerPeerPublicKey('alice-id', alicePubBase64);

        final eveCrypto = CryptoService(storagePrefix: 'eve');
        // Eve only knows Alice's public key, but Eve's private key is different from Bob's
        eveCrypto.registerPeerPublicKey('alice-id', alicePubBase64);

        final encrypted = await aliceCrypto.encrypt(
          plaintext: 'Confidential macro targets: 2200 kcal, 180g P',
          recipientUserId: 'bob-id',
        );

        expect(
          () async => eveCrypto.decrypt(
            ciphertext: encrypted.ciphertext,
            nonce: encrypted.nonce,
            mac: encrypted.mac,
            peerUserId: 'alice-id',
          ),
          throwsA(anything),
        );
      },
    );

    test(
      'key pair persists and reloads across SharedPreferences instances',
      () async {
        final sharedStore = <String, Object>{};
        SharedPreferences.setMockInitialValues(sharedStore);

        final service1 = CryptoService();
        final pubKey1 = await service1.getMyPublicKeyBase64();

        // Simulate app restart with same persistent storage
        final service2 = CryptoService();
        final pubKey2 = await service2.getMyPublicKeyBase64();

        expect(pubKey1, equals(pubKey2));
        expect(pubKey1.length, 44);
      },
    );
  });
}
