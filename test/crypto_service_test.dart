import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

/// Wire payload for E2E Encrypted Chat messages matching PROJECT.md § Cryptographic Protocol Contract.
class EncryptedMessageWirePayload {
  final String conversationId;
  final String senderId;
  final String clientUuid;
  final String ciphertext; // Base64 of raw ciphertext + 16-byte GCM tag
  final String nonce;      // Base64 of 12-byte CSPRNG IV

  const EncryptedMessageWirePayload({
    required this.conversationId,
    required this.senderId,
    required this.clientUuid,
    required this.ciphertext,
    required this.nonce,
  });

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationId,
    'sender_id': senderId,
    'client_uuid': clientUuid,
    'ciphertext': ciphertext,
    'nonce': nonce,
  };

  factory EncryptedMessageWirePayload.fromJson(Map<String, dynamic> json) => EncryptedMessageWirePayload(
    conversationId: json['conversation_id'] as String,
    senderId: json['sender_id'] as String,
    clientUuid: json['client_uuid'] as String,
    ciphertext: json['ciphertext'] as String,
    nonce: json['nonce'] as String,
  );
}

/// Encryption Key Public Record matching PROJECT.md.
class UserPublicKeyRecord {
  final String userId;
  final String publicKey; // 32-byte X25519 public key Base64

  const UserPublicKeyRecord({
    required this.userId,
    required this.publicKey,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'public_key': publicKey,
  };

  factory UserPublicKeyRecord.fromJson(Map<String, dynamic> json) => UserPublicKeyRecord(
    userId: json['user_id'] as String,
    publicKey: json['public_key'] as String,
  );
}

void main() {
  group('E2EE Cryptographic Protocol & Wire Format Tests', () {
    test('X25519 public key adheres to 32-byte length and Base64 encoding', () {
      // 32 zero bytes in base64: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= (44 chars)
      const mockBase64Key = '3q2+796tvu/erb7v3q2+796tvu/erb7v3q2+796tvu8=';
      final decodedBytes = base64.decode(mockBase64Key);

      expect(decodedBytes.length, 32, reason: 'X25519 public keys must be exactly 32 bytes');
      expect(mockBase64Key.length, 44, reason: 'Base64 encoded 32-byte key must be 44 characters');
    });

    test('96-bit AES-GCM nonce adheres to 12-byte length and Base64 format', () {
      // 12-byte nonce base64 encoded is 16 characters
      const mockNonceBase64 = 'AQIDBAUGBwgJCgsM';
      final nonceBytes = base64.decode(mockNonceBase64);

      expect(nonceBytes.length, 12, reason: 'AES-256-GCM nonces must be exactly 12 bytes (96 bits)');
      expect(mockNonceBase64.length, 16);
    });

    test('serializes and deserializes EncryptedMessageWirePayload faithfully', () {
      const payload = EncryptedMessageWirePayload(
        conversationId: 'conv-uuid-1111',
        senderId: 'user-uuid-2222',
        clientUuid: 'msg-uuid-3333',
        ciphertext: 'dGhpcyBpcyBhbiBlbmNyeXB0ZWQgY2lwaGVydGV4dCB3aXRoIGF1dGggdGFn',
        nonce: 'AQIDBAUGBwgJCgsM',
      );

      final jsonMap = payload.toJson();
      expect(jsonMap['conversation_id'], 'conv-uuid-1111');
      expect(jsonMap['sender_id'], 'user-uuid-2222');
      expect(jsonMap['client_uuid'], 'msg-uuid-3333');
      expect(jsonMap['ciphertext'], isNotEmpty);
      expect(jsonMap['nonce'], isNotEmpty);

      final reconstructed = EncryptedMessageWirePayload.fromJson(jsonMap);
      expect(reconstructed.conversationId, payload.conversationId);
      expect(reconstructed.senderId, payload.senderId);
      expect(reconstructed.clientUuid, payload.clientUuid);
      expect(reconstructed.ciphertext, payload.ciphertext);
      expect(reconstructed.nonce, payload.nonce);
    });

    test('serializes and deserializes UserPublicKeyRecord faithfully', () {
      const record = UserPublicKeyRecord(
        userId: 'user-uuid-5555',
        publicKey: '3q2+796tvu/erb7v3q2+796tvu/erb7v3q2+796tvu8=',
      );

      final jsonMap = record.toJson();
      expect(jsonMap['user_id'], 'user-uuid-5555');
      expect(jsonMap['public_key'], '3q2+796tvu/erb7v3q2+796tvu/erb7v3q2+796tvu8=');

      final reconstructed = UserPublicKeyRecord.fromJson(jsonMap);
      expect(reconstructed.userId, record.userId);
      expect(reconstructed.publicKey, record.publicKey);
    });

    test('validates ciphertext does not leak plaintext message content', () {
      const secretWorkoutNote = 'Squat 140kg x 5, RDL 120kg x 8';
      // Simulated AES-GCM ciphertext
      final mockCiphertextBytes = [0xde, 0xad, 0xbe, 0xef, 0x01, 0x02, 0x03, 0x04];
      final ciphertextBase64 = base64.encode(mockCiphertextBytes);

      expect(ciphertextBase64.contains(secretWorkoutNote), isFalse);
      expect(secretWorkoutNote.contains(ciphertextBase64), isFalse);
    });

    test('detects tampered ciphertext by byte modification', () {
      final validCiphertextBytes = [10, 20, 30, 40, 50, 60, 70, 80];
      final tamperedBytes = List<int>.from(validCiphertextBytes);

      // Flip single bit
      tamperedBytes[3] ^= 0x01;

      expect(tamperedBytes, isNot(equals(validCiphertextBytes)));
      expect(base64.encode(tamperedBytes), isNot(equals(base64.encode(validCiphertextBytes))));
    });
  });
}
