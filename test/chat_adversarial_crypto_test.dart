import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:fitness_app/features/chat/models/chat_message.dart';
import 'package:fitness_app/features/chat/services/crypto_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Chat Adversarial Cryptographic Verification Suite', () {
    late CryptoService aliceCrypto;
    late CryptoService bobCrypto;
    late String alicePubBase64;
    late String bobPubBase64;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      aliceCrypto = CryptoService(storagePrefix: 'alice_adv');
      bobCrypto = CryptoService(storagePrefix: 'bob_adv');

      alicePubBase64 = await aliceCrypto.getMyPublicKeyBase64();
      bobPubBase64 = await bobCrypto.getMyPublicKeyBase64();

      aliceCrypto.registerPeerPublicKey('bob-user-id', bobPubBase64);
      bobCrypto.registerPeerPublicKey('alice-user-id', alicePubBase64);
    });

    group('1. 1-Bit Tamper Stress Testing (>= 500 bit-tamper vectors)', () {
      test(
        '200 random 1-bit flips in ciphertext payload throw '
        'SecretBoxAuthenticationError (100% reject, 0% bypass)',
        () async {
          const originalMessage =
              'Adversarial workout telemetry: '
              'heartRate=172, lactate=4.2mM, cadence=92rpm';
          final encrypted = await aliceCrypto.encrypt(
            plaintext: originalMessage,
            recipientUserId: 'bob-user-id',
          );

          // Verify baseline integrity first (0% false positives)
          final baseline = await bobCrypto.decrypt(
            ciphertext: encrypted.ciphertext,
            nonce: encrypted.nonce,
            mac: encrypted.mac,
            peerUserId: 'alice-user-id',
          );
          expect(baseline, equals(originalMessage));

          final cipherBytes = base64.decode(encrypted.ciphertext);
          final rng = Random(1001);
          var totalRejections = 0;

          const iterations = 200;
          for (var i = 0; i < iterations; i++) {
            final byteIndex = rng.nextInt(cipherBytes.length);
            final bitIndex = rng.nextInt(8);

            final tamperedBytes = List<int>.from(cipherBytes);
            tamperedBytes[byteIndex] ^= 1 << bitIndex;
            final tamperedCiphertext = base64.encode(tamperedBytes);

            expect(
              () async => bobCrypto.decrypt(
                ciphertext: tamperedCiphertext,
                nonce: encrypted.nonce,
                mac: encrypted.mac,
                peerUserId: 'alice-user-id',
              ),
              throwsA(isA<SecretBoxAuthenticationError>()),
              reason:
                  'Tampering byte $byteIndex bit $bitIndex '
                  'MUST fail authentication',
            );
            totalRejections++;
          }

          expect(
            totalRejections,
            equals(iterations),
            reason: '100% of ciphertext bit flips must be rejected',
          );
        },
      );

      test(
        '200 random 1-bit flips in 12-byte CSPRNG nonce throw '
        'SecretBoxAuthenticationError',
        () async {
          const originalMessage =
              'Session confirmation: '
              '1-on-1 coach call scheduled at 10:00 UTC';
          final encrypted = await aliceCrypto.encrypt(
            plaintext: originalMessage,
            recipientUserId: 'bob-user-id',
          );

          final nonceBytes = base64.decode(encrypted.nonce);
          expect(nonceBytes.length, 12);

          final rng = Random(2002);
          var totalRejections = 0;

          const iterations = 200;
          for (var i = 0; i < iterations; i++) {
            final byteIndex = rng.nextInt(nonceBytes.length);
            final bitIndex = rng.nextInt(8);

            final tamperedNonceBytes = List<int>.from(nonceBytes);
            tamperedNonceBytes[byteIndex] ^= 1 << bitIndex;
            final tamperedNonce = base64.encode(tamperedNonceBytes);

            expect(
              () async => bobCrypto.decrypt(
                ciphertext: encrypted.ciphertext,
                nonce: tamperedNonce,
                mac: encrypted.mac,
                peerUserId: 'alice-user-id',
              ),
              throwsA(isA<SecretBoxAuthenticationError>()),
              reason:
                  'Tampering nonce byte $byteIndex bit $bitIndex '
                  'MUST fail authentication',
            );
            totalRejections++;
          }

          expect(totalRejections, equals(iterations));
        },
      );

      test(
        '200 random 1-bit flips in 16-byte MAC tag throw '
        'SecretBoxAuthenticationError',
        () async {
          const originalMessage =
              'Strict macro prescription: '
              '240g protein, 65g fat, 310g carbs';
          final encrypted = await aliceCrypto.encrypt(
            plaintext: originalMessage,
            recipientUserId: 'bob-user-id',
          );

          final macBytes = base64.decode(encrypted.mac);
          expect(macBytes.length, 16);

          final rng = Random(3003);
          var totalRejections = 0;

          const iterations = 200;
          for (var i = 0; i < iterations; i++) {
            final byteIndex = rng.nextInt(macBytes.length);
            final bitIndex = rng.nextInt(8);

            final tamperedMacBytes = List<int>.from(macBytes);
            tamperedMacBytes[byteIndex] ^= 1 << bitIndex;
            final tamperedMac = base64.encode(tamperedMacBytes);

            expect(
              () async => bobCrypto.decrypt(
                ciphertext: encrypted.ciphertext,
                nonce: encrypted.nonce,
                mac: tamperedMac,
                peerUserId: 'alice-user-id',
              ),
              throwsA(isA<SecretBoxAuthenticationError>()),
              reason:
                  'Tampering MAC byte $byteIndex bit $bitIndex '
                  'MUST fail authentication',
            );
            totalRejections++;
          }

          expect(totalRejections, equals(iterations));
        },
      );

      test(
        '100 multi-bit coordinated tamper vectors across ciphertext, '
        'nonce, and tag throw SecretBoxAuthenticationError',
        () async {
          const originalMessage =
              'Security critical payload: '
              'bank details & split transaction token';
          final encrypted = await aliceCrypto.encrypt(
            plaintext: originalMessage,
            recipientUserId: 'bob-user-id',
          );

          final cipherBytes = base64.decode(encrypted.ciphertext);
          final nonceBytes = base64.decode(encrypted.nonce);
          final macBytes = base64.decode(encrypted.mac);
          final rng = Random(4004);

          const iterations = 100;
          for (var i = 0; i < iterations; i++) {
            final tamperedCipher = List<int>.from(cipherBytes);
            final tamperedNonce = List<int>.from(nonceBytes);
            final tamperedMac = List<int>.from(macBytes);

            // Flip 2 to 4 random bits across elements
            final flips = 2 + rng.nextInt(3);
            for (var f = 0; f < flips; f++) {
              tamperedCipher[rng.nextInt(tamperedCipher.length)] ^=
                  1 << rng.nextInt(8);
              tamperedNonce[rng.nextInt(tamperedNonce.length)] ^=
                  1 << rng.nextInt(8);
              tamperedMac[rng.nextInt(tamperedMac.length)] ^=
                  1 << rng.nextInt(8);
            }

            expect(
              () async => bobCrypto.decrypt(
                ciphertext: base64.encode(tamperedCipher),
                nonce: base64.encode(tamperedNonce),
                mac: base64.encode(tamperedMac),
                peerUserId: 'alice-user-id',
              ),
              throwsA(isA<SecretBoxAuthenticationError>()),
            );
          }
        },
      );
    });

    group('2. Domain Separation Tampering', () {
      test(
        'Deriving key with wrong salt (PulseFit-E2EE-v2-Salt) '
        'fails decryption 100% of the time',
        () async {
          const testMessages = <String>[
            'Trainer consultation notes',
            'Nutritional plan revision 2',
            'Payment split authorization key',
            'Cardio heart rate zones [Z1-Z5]',
            'Bench press form critique video URL',
          ];

          final x25519 = X25519();
          final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
          final aesGcm = AesGcm.with256bits();

          final aliceKeyPair = await aliceCrypto.getOrCreateKeyPair();
          final bobKeyPair = await bobCrypto.getOrCreateKeyPair();
          final alicePub = await aliceKeyPair.extractPublicKey();

          // Bob computes shared secret
          final bobSharedSecret = await x25519.sharedSecretKey(
            keyPair: bobKeyPair,
            remotePublicKey: alicePub,
          );

          // Attacker / misconfigured client uses wrong salt v2
          final wrongSaltKey = await hkdf.deriveKey(
            secretKey: bobSharedSecret,
            nonce: utf8.encode('PulseFit-E2EE-v2-Salt'),
            info: utf8.encode(CryptoService.hkdfInfoString),
          );

          for (final msg in testMessages) {
            final encrypted = await aliceCrypto.encrypt(
              plaintext: msg,
              recipientUserId: 'bob-user-id',
            );

            final cipherBytes = base64.decode(encrypted.ciphertext);
            final nonceBytes = base64.decode(encrypted.nonce);
            final rawCipher = cipherBytes.sublist(0, cipherBytes.length - 16);
            final tag = cipherBytes.sublist(cipherBytes.length - 16);

            final box = SecretBox(
              rawCipher,
              nonce: nonceBytes,
              mac: Mac(tag),
            );

            expect(
              () async => aesGcm.decrypt(box, secretKey: wrongSaltKey),
              throwsA(isA<SecretBoxAuthenticationError>()),
              reason: 'Wrong salt MUST cause AES-GCM tag verification failure',
            );
          }
        },
      );

      test(
        'Deriving key with wrong info (PulseFit-Wrong-Info) '
        'fails decryption 100% of the time',
        () async {
          const testMessages = <String>[
            'Target heart rate: 165 bpm',
            'Post-workout recovery protein shake',
            'Next session scheduled for Friday',
          ];

          final x25519 = X25519();
          final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
          final aesGcm = AesGcm.with256bits();

          final aliceKeyPair = await aliceCrypto.getOrCreateKeyPair();
          final bobKeyPair = await bobCrypto.getOrCreateKeyPair();
          final alicePub = await aliceKeyPair.extractPublicKey();

          final bobSharedSecret = await x25519.sharedSecretKey(
            keyPair: bobKeyPair,
            remotePublicKey: alicePub,
          );

          // Derivation with wrong HKDF info
          final wrongInfoKey = await hkdf.deriveKey(
            secretKey: bobSharedSecret,
            nonce: utf8.encode(CryptoService.hkdfSaltString),
            info: utf8.encode('PulseFit-Wrong-Info'),
          );

          for (final msg in testMessages) {
            final encrypted = await aliceCrypto.encrypt(
              plaintext: msg,
              recipientUserId: 'bob-user-id',
            );

            final cipherBytes = base64.decode(encrypted.ciphertext);
            final nonceBytes = base64.decode(encrypted.nonce);
            final rawCipher = cipherBytes.sublist(0, cipherBytes.length - 16);
            final tag = cipherBytes.sublist(cipherBytes.length - 16);

            final box = SecretBox(
              rawCipher,
              nonce: nonceBytes,
              mac: Mac(tag),
            );

            expect(
              () async => aesGcm.decrypt(box, secretKey: wrongInfoKey),
              throwsA(isA<SecretBoxAuthenticationError>()),
              reason: 'Wrong info MUST cause AES-GCM tag verification failure',
            );
          }
        },
      );

      test(
        'Both wrong salt and wrong info produce orthogonal keys with '
        '100% decryption failure',
        () async {
          final x25519 = X25519();
          final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
          final aliceKeyPair = await aliceCrypto.getOrCreateKeyPair();
          final bobKeyPair = await bobCrypto.getOrCreateKeyPair();
          final alicePub = await aliceKeyPair.extractPublicKey();

          final sharedSecret = await x25519.sharedSecretKey(
            keyPair: bobKeyPair,
            remotePublicKey: alicePub,
          );

          final correctKey = await hkdf.deriveKey(
            secretKey: sharedSecret,
            nonce: utf8.encode(CryptoService.hkdfSaltString),
            info: utf8.encode(CryptoService.hkdfInfoString),
          );

          final corruptedKey = await hkdf.deriveKey(
            secretKey: sharedSecret,
            nonce: utf8.encode('PulseFit-E2EE-v2-Salt'),
            info: utf8.encode('PulseFit-Wrong-Info'),
          );

          final correctBytes = await correctKey.extractBytes();
          final corruptedBytes = await corruptedKey.extractBytes();

          expect(correctBytes, isNot(equals(corruptedBytes)));

          // Assert high hamming distance
          var differingBits = 0;
          for (var i = 0; i < 32; i++) {
            var xor = correctBytes[i] ^ corruptedBytes[i];
            while (xor > 0) {
              differingBits += xor & 1;
              xor >>= 1;
            }
          }
          expect(
            differingBits,
            greaterThan(80),
            reason: 'Hamming distance should be near pseudorandom ~128 bits',
          );
        },
      );
    });

    group('3. Cross-Identity Eavesdropping & Impersonation Resistance', () {
      test(
        'Party C (adversary Eve) intercepts Alice->Bob messages and fails '
        '100% of decryption attempts',
        () async {
          final eveCrypto = CryptoService(
            storagePrefix: 'eve_eavesdropper',
          )..registerPeerPublicKey('alice-user-id', alicePubBase64);

          const confidentialMessages = <String>[
            'Secret medical history: knee meniscus tear in 2024',
            r'Private financial arrangement: $150/hr direct coaching retainer',
            'Home gym access code: 4892#',
          ];

          for (final secretMsg in confidentialMessages) {
            final encrypted = await aliceCrypto.encrypt(
              plaintext: secretMsg,
              recipientUserId: 'bob-user-id',
            );

            // Eve attempts to decrypt Alice's message
            expect(
              () async => eveCrypto.decrypt(
                ciphertext: encrypted.ciphertext,
                nonce: encrypted.nonce,
                mac: encrypted.mac,
                peerUserId: 'alice-user-id',
              ),
              throwsA(isA<SecretBoxAuthenticationError>()),
              reason:
                  'Adversary Eve must NEVER decrypt Alice->Bob payload',
            );
          }
        },
      );

      test(
        'Multi-party isolation: 20 distinct random adversary keypairs '
        'all fail decryption',
        () async {
          const secretPayload =
              'High-priority workout feedback: '
              'reduce load to 100kg immediately';
          final encrypted = await aliceCrypto.encrypt(
            plaintext: secretPayload,
            recipientUserId: 'bob-user-id',
          );

          const adversaryCount = 20;
          for (var i = 0; i < adversaryCount; i++) {
            final adversaryService = CryptoService(
              storagePrefix: 'adversary_$i',
            )..registerPeerPublicKey(
              'alice-user-id',
              alicePubBase64,
            );

            expect(
              () async => adversaryService.decrypt(
                ciphertext: encrypted.ciphertext,
                nonce: encrypted.nonce,
                mac: encrypted.mac,
                peerUserId: 'alice-user-id',
              ),
              throwsA(isA<SecretBoxAuthenticationError>()),
              reason:
                  'Adversary $i MUST NOT decrypt payload between Alice and Bob',
            );
          }
        },
      );

      test(
        'Key confusion resistance: recipient decrypting with wrong '
        'sender identity fails authentication',
        () async {
          final charlieCrypto = CryptoService(storagePrefix: 'charlie_third');
          final charliePubBase64 = await charlieCrypto.getMyPublicKeyBase64();
          bobCrypto.registerPeerPublicKey('charlie-user-id', charliePubBase64);

          final encrypted = await aliceCrypto.encrypt(
            plaintext: 'Leg extension 4x15 failure sets',
            recipientUserId: 'bob-user-id',
          );

          // Bob mistakenly attempts to decrypt Alice's ciphertext
          // as if it came from Charlie
          expect(
            () async => bobCrypto.decrypt(
              ciphertext: encrypted.ciphertext,
              nonce: encrypted.nonce,
              mac: encrypted.mac,
              peerUserId: 'charlie-user-id',
            ),
            throwsA(isA<SecretBoxAuthenticationError>()),
            reason:
                'Decrypting with mismatched peer identity key must '
                'fail authentication',
          );
        },
      );
    });

    group('4. Extreme Unicode, Edge Cases & Payload Stress', () {
      test(
        'Empty string round-trip produces valid payload and restores empty',
        () async {
          const emptyPlaintext = '';
          final encrypted = await aliceCrypto.encrypt(
            plaintext: emptyPlaintext,
            recipientUserId: 'bob-user-id',
          );

          expect(encrypted.ciphertext.isNotEmpty, isTrue);
          expect(encrypted.nonce.isNotEmpty, isTrue);
          expect(encrypted.mac.isNotEmpty, isTrue);

          final decrypted = await bobCrypto.decrypt(
            ciphertext: encrypted.ciphertext,
            nonce: encrypted.nonce,
            mac: encrypted.mac,
            peerUserId: 'alice-user-id',
          );

          expect(decrypted, equals(emptyPlaintext));
        },
      );

      test(
        'Extreme payload: 100KB long string round-trip preserves integrity',
        () async {
          // Construct 100KB (102,400 chars) payload with mixed data
          final buffer = StringBuffer();
          const chunk =
              'PulseFit-E2EE-StressTest-AlphaNumeric-0123456789-'
              r'!@#$%^&*()_+{}-';
          while (buffer.length < 102400) {
            buffer.write(chunk);
          }
          final hugePlaintext = buffer.toString().substring(0, 102400);
          expect(hugePlaintext.length, 102400);

          final encrypted = await aliceCrypto.encrypt(
            plaintext: hugePlaintext,
            recipientUserId: 'bob-user-id',
          );

          expect(encrypted.ciphertext.length, greaterThan(100000));

          final decrypted = await bobCrypto.decrypt(
            ciphertext: encrypted.ciphertext,
            nonce: encrypted.nonce,
            mac: encrypted.mac,
            peerUserId: 'alice-user-id',
          );

          expect(decrypted.length, 102400);
          expect(decrypted, equals(hugePlaintext));
        },
      );

      test(
        'Embedded null bytes and binary control characters round-trip cleanly',
        () async {
          final specialCharacters = String.fromCharCodes(<int>[
            0x00, // null byte
            0x01, // SOH
            0x07, // bell
            0x08, // backspace
            0x09, // tab
            0x0A, // newline
            0x0D, // carriage return
            0x1B, // ESC
            0x7F, // DEL
            0x00, // embedded null
            0x41, // 'A'
            0x00, // embedded null
            0x42, // 'B'
          ]);

          final encrypted = await aliceCrypto.encrypt(
            plaintext: specialCharacters,
            recipientUserId: 'bob-user-id',
          );

          final decrypted = await bobCrypto.decrypt(
            ciphertext: encrypted.ciphertext,
            nonce: encrypted.nonce,
            mac: encrypted.mac,
            peerUserId: 'alice-user-id',
          );

          expect(decrypted, equals(specialCharacters));
          expect(decrypted.codeUnits, equals(specialCharacters.codeUnits));
        },
      );

      test(
        'Bidirectional text, RTL markers, and zero-width characters '
        'round-trip cleanly',
        () async {
          const bidiText =
              'English start '
              '\u202E' // Right-to-Left Override
              'עברית וערבית: مرحبا يا مدرب '
              '\u202C' // Pop Directional Formatting
              '\u200E' // Left-to-Right Mark
              'Back to English '
              '\u200D' // Zero-Width Joiner
              '\u200C' // Zero-Width Non-Joiner
              'End of sentence.';

          final encrypted = await aliceCrypto.encrypt(
            plaintext: bidiText,
            recipientUserId: 'bob-user-id',
          );

          final decrypted = await bobCrypto.decrypt(
            ciphertext: encrypted.ciphertext,
            nonce: encrypted.nonce,
            mac: encrypted.mac,
            peerUserId: 'alice-user-id',
          );

          expect(decrypted, equals(bidiText));
        },
      );

      test(
        'Complex emoji sequences: multi-code-point, flags, and skin-tone '
        'modifiers round-trip cleanly',
        () async {
          const complexEmojis =
              '🏋🏽‍♀️ 👨‍👩‍👧‍👦 🏳️‍🌈 🧑🏾‍🦱 '
              '🏃🏿‍♂️💨 🧘🏼 🧗🏻‍♂️ 🥇🔥💯⚡ '
              'Mixed with text: Great job on the 200kg deadlift! 🦾';

          final encrypted = await aliceCrypto.encrypt(
            plaintext: complexEmojis,
            recipientUserId: 'bob-user-id',
          );

          final decrypted = await bobCrypto.decrypt(
            ciphertext: encrypted.ciphertext,
            nonce: encrypted.nonce,
            mac: encrypted.mac,
            peerUserId: 'alice-user-id',
          );

          expect(decrypted, equals(complexEmojis));
        },
      );
    });

    group('5. Zero-Knowledge Payload Audit & Leakage Resistance', () {
      test(
        'ChatMessage.toJson() strictly excludes plaintext from keys '
        'and serialized values',
        () async {
          const secretText =
              'TOP_SECRET_MEDICAL_CONDITION_HYPERTENSION_RESTRICTED';

          final encrypted = await aliceCrypto.encrypt(
            plaintext: secretText,
            recipientUserId: 'bob-user-id',
          );

          final message = ChatMessage(
            id: 'msg-zk-100',
            conversationId: 'conv-zk-1',
            senderId: 'alice-user-id',
            clientUuid: '11111111-2222-3333-4444-555555555555',
            ciphertext: encrypted.ciphertext,
            nonce: encrypted.nonce,
            mac: encrypted.mac,
            plaintext: secretText,
            createdAt: DateTime.utc(2026, 10, 16, 12),
          );

          final json = message.toJson();

          // 1. Audit keys
          expect(
            json.containsKey('plaintext'),
            isFalse,
            reason: 'toJson() keys MUST NOT include plaintext',
          );
          expect(
            json.containsKey('plain_text'),
            isFalse,
            reason: 'toJson() keys MUST NOT include plain_text',
          );

          // 2. Audit string serialization
          final serialized = jsonEncode(json);
          expect(
            serialized.contains(secretText),
            isFalse,
            reason:
                'JSON serialized string MUST NOT contain raw plaintext string',
          );
          expect(
            serialized.contains('TOP_SECRET'),
            isFalse,
          );
          expect(
            serialized.contains('HYPERTENSION'),
            isFalse,
          );

          // 3. Verify allowed cryptographic keys are present
          expect(json['ciphertext'], equals(encrypted.ciphertext));
          expect(json['nonce'], equals(encrypted.nonce));
          expect(json['mac'], equals(encrypted.mac));
        },
      );

      test(
        'ChatMessage.toInsertPayload() strictly excludes plaintext from keys '
        'and serialized values',
        () async {
          const secretText =
              'TOP_SECRET_CLIENT_PAYMENT_PIN_9876_AND_ROUTING_NUMBER';

          final encrypted = await aliceCrypto.encrypt(
            plaintext: secretText,
            recipientUserId: 'bob-user-id',
          );

          final message = ChatMessage(
            id: 'msg-zk-200',
            conversationId: 'conv-zk-2',
            senderId: 'alice-user-id',
            clientUuid: '22222222-3333-4444-5555-666666666666',
            ciphertext: encrypted.ciphertext,
            nonce: encrypted.nonce,
            mac: encrypted.mac,
            plaintext: secretText,
            createdAt: DateTime.utc(2026, 10, 16, 12),
          );

          final insertPayload = message.toInsertPayload();

          // 1. Audit keys
          expect(
            insertPayload.containsKey('plaintext'),
            isFalse,
            reason: 'toInsertPayload() MUST NOT include plaintext key',
          );
          expect(
            insertPayload.containsKey('plain_text'),
            isFalse,
          );

          // 2. Audit serialized payload
          final serialized = jsonEncode(insertPayload);
          expect(
            serialized.contains(secretText),
            isFalse,
            reason: 'Wire insert payload MUST NOT contain plaintext',
          );
          expect(
            serialized.contains('TOP_SECRET'),
            isFalse,
          );
          expect(
            serialized.contains('PAYMENT_PIN'),
            isFalse,
          );

          // 3. Permitted wire fields only
          expect(
            insertPayload.keys,
            containsAll(<String>[
              'conversation_id',
              'sender_id',
              'client_uuid',
              'ciphertext',
              'nonce',
              'mac',
            ]),
          );
          expect(insertPayload.length, 6);
        },
      );

      test(
        'ChatMessage.createOptimistic maintains zero-knowledge wire invariant',
        () async {
          const optimisticPlaintext = 'Instant optimistic chat bubble text';

          final encrypted = await aliceCrypto.encrypt(
            plaintext: optimisticPlaintext,
            recipientUserId: 'bob-user-id',
          );

          final optimisticMsg = ChatMessage.createOptimistic(
            conversationId: 'conv-opt-1',
            senderId: 'alice-user-id',
            clientUuid: '33333333-4444-5555-6666-777777777777',
            plaintext: optimisticPlaintext,
            ciphertext: encrypted.ciphertext,
            nonce: encrypted.nonce,
            mac: encrypted.mac,
          );

          expect(optimisticMsg.plaintext, equals(optimisticPlaintext));

          final json = optimisticMsg.toJson();
          final payload = optimisticMsg.toInsertPayload();

          expect(json.containsKey('plaintext'), isFalse);
          expect(payload.containsKey('plaintext'), isFalse);
          expect(jsonEncode(json).contains(optimisticPlaintext), isFalse);
          expect(jsonEncode(payload).contains(optimisticPlaintext), isFalse);
        },
      );

      test(
        'ChatMessage.copyWith maintains zero-knowledge wire invariant '
        'under mutation',
        () async {
          const updatedPlaintext = 'Updated in-memory plaintext representation';

          final encrypted = await aliceCrypto.encrypt(
            plaintext: 'Original in-memory text',
            recipientUserId: 'bob-user-id',
          );

          final original = ChatMessage(
            id: 'msg-zk-300',
            conversationId: 'conv-zk-3',
            senderId: 'alice-user-id',
            clientUuid: '44444444-5555-6666-7777-888888888888',
            ciphertext: encrypted.ciphertext,
            nonce: encrypted.nonce,
            mac: encrypted.mac,
            plaintext: 'Original in-memory text',
            createdAt: DateTime.utc(2026, 10, 16, 12),
          );

          final mutated = original.copyWith(plaintext: updatedPlaintext);

          expect(mutated.plaintext, equals(updatedPlaintext));
          expect(mutated.toJson().containsKey('plaintext'), isFalse);
          expect(mutated.toInsertPayload().containsKey('plaintext'), isFalse);
          expect(
            jsonEncode(mutated.toJson()).contains(updatedPlaintext),
            isFalse,
          );
          expect(
            jsonEncode(mutated.toInsertPayload()).contains(updatedPlaintext),
            isFalse,
          );
        },
      );

      test(
        'EncryptedPayload.toJson() wire format conforms strictly to '
        'cryptographic contract',
        () async {
          const payloadSecret = 'EncryptedPayload test text';
          final encrypted = await aliceCrypto.encrypt(
            plaintext: payloadSecret,
            recipientUserId: 'bob-user-id',
          );

          final payloadJson = encrypted.toJson();
          expect(
            payloadJson.keys.toSet(),
            equals(<String>{'ciphertext', 'nonce', 'mac'}),
          );
          expect(
            payloadJson.values.any((v) => v.contains(payloadSecret)),
            isFalse,
          );
          expect(jsonEncode(payloadJson).contains(payloadSecret), isFalse);
        },
      );
    });
  });
}
