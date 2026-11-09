import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

class VaultCrypto {
  VaultCrypto(this.sodium, this.owner, this.master);
  final SodiumSumo sodium;
  final String owner;
  final SecureKey master;
  static const ops = 2;
  static const memory = 64 * 1024 * 1024;

  static Future<
    ({VaultCrypto vault, Map<String, dynamic> header, String recovery})
  >
  create(SodiumSumo sodium, String owner, String password) async {
    final vault = VaultCrypto(sodium, owner, sodium.crypto.kdf.keygen());
    try {
      final wrapped = await vault.wrap(password);
      return (vault: vault, header: wrapped.header, recovery: wrapped.recovery);
    } catch (_) {
      vault.dispose();
      rethrow;
    }
  }

  Future<({Map<String, dynamic> header, String recovery})> wrap(
    String password,
  ) async {
    if (password.runes.length < 12) {
      throw const FormatException('加密口令至少 12 个字符，请使用较长且独有的口令');
    }
    final salt = sodium.randombytes.buf(sodium.crypto.pwhash.saltBytes);
    final passKey = await _passwordKey(sodium, password, salt);
    final recoveryKey = sodium.crypto.aeadXChaCha20Poly1305IETF.keygen();
    try {
      final header = <String, dynamic>{
        'v': 1,
        'salt': base64Encode(salt),
        'ops': ops,
        'mem': memory,
        'pass': master.runUnlockedSync(
          (bytes) => _seal(sodium, passKey, bytes, '$owner:vault:pass:1'),
        ),
        'recovery': master.runUnlockedSync(
          (bytes) =>
              _seal(sodium, recoveryKey, bytes, '$owner:vault:recovery:1'),
        ),
      };
      return (
        header: header,
        recovery: recoveryKey.runUnlockedSync(base64UrlEncode),
      );
    } finally {
      passKey.dispose();
      recoveryKey.dispose();
    }
  }

  static Future<SecureKey> _passwordKey(
    SodiumSumo sodium,
    String password,
    Uint8List salt,
  ) async {
    // Keep Argon2 off the UI isolate; its work factor is fixed by format v1.
    return sodium.runIsolated(
      (keys, pairs) => sodium.crypto.pwhash.callStr(
        outLen: 32,
        password: password,
        salt: salt,
        opsLimit: ops,
        memLimit: memory,
        alg: CryptoPwhashAlgorithm.argon2id13,
      ),
    );
  }

  static Future<VaultCrypto> unlock(
    SodiumSumo sodium,
    String owner,
    Map<String, dynamic> header,
    String secret, {
    bool recovery = false,
  }) async {
    if (header['v'] != 1 || header['ops'] != ops || header['mem'] != memory) {
      throw const FormatException('不支持的密钥格式');
    }
    final key = recovery
        ? sodium.secureCopy(
            base64Url.decode(base64Url.normalize(secret.trim())),
          )
        : await _passwordKey(
            sodium,
            secret,
            base64Decode(header['salt'] as String),
          );
    try {
      final plain = _open(
        sodium,
        key,
        Map<String, dynamic>.from(
          header[recovery ? 'recovery' : 'pass'] as Map,
        ),
        '$owner:vault:${recovery ? 'recovery' : 'pass'}:1',
      );
      try {
        if (plain.length != 32) throw const FormatException('无效的主密钥');
        return VaultCrypto(sodium, owner, sodium.secureCopy(plain));
      } finally {
        plain.fillRange(0, plain.length, 0);
      }
    } finally {
      key.dispose();
    }
  }

  SecureKey _subkey(bool attachment) => sodium.crypto.kdf.deriveFromKey(
    masterKey: master,
    context: attachment ? 'ATTACH01' : 'RECORD01',
    subkeyId: BigInt.one,
    subkeyLen: 32,
  );

  Map<String, dynamic> sealBytes(
    String id,
    Uint8List bytes, {
    bool attachment = false,
  }) {
    final key = _subkey(attachment);
    try {
      return _seal(
        sodium,
        key,
        bytes,
        '$owner:${attachment ? 'attachment' : 'record'}:$id:1',
      );
    } finally {
      key.dispose();
    }
  }

  Uint8List openBytes(
    String id,
    Map<String, dynamic> envelope, {
    bool attachment = false,
  }) {
    final key = _subkey(attachment);
    try {
      return _open(
        sodium,
        key,
        envelope,
        '$owner:${attachment ? 'attachment' : 'record'}:$id:1',
      );
    } finally {
      key.dispose();
    }
  }

  Map<String, dynamic> sealJson(String id, Map<String, dynamic> value) =>
      sealBytes(id, Uint8List.fromList(utf8.encode(jsonEncode(value))));

  Uint8List sealAttachment(String id, Uint8List bytes) {
    final key = _subkey(true);
    final aead = sodium.crypto.aeadXChaCha20Poly1305IETF;
    final nonce = sodium.randombytes.buf(aead.nonceBytes);
    try {
      return (BytesBuilder(copy: false)
            ..add([1])
            ..add(nonce)
            ..add(
              aead.encrypt(
                message: bytes,
                nonce: nonce,
                key: key,
                additionalData: Uint8List.fromList(
                  utf8.encode('$owner:attachment:$id:1'),
                ),
              ),
            ))
          .takeBytes();
    } finally {
      key.dispose();
    }
  }

  Uint8List openAttachment(String id, Uint8List frame) {
    final aead = sodium.crypto.aeadXChaCha20Poly1305IETF;
    if (frame.length < 1 + aead.nonceBytes + aead.aBytes || frame[0] != 1) {
      throw const FormatException('无效的加密附件');
    }
    final key = _subkey(true);
    try {
      return aead.decrypt(
        cipherText: Uint8List.sublistView(frame, 1 + aead.nonceBytes),
        nonce: Uint8List.sublistView(frame, 1, 1 + aead.nonceBytes),
        key: key,
        additionalData: Uint8List.fromList(
          utf8.encode('$owner:attachment:$id:1'),
        ),
      );
    } finally {
      key.dispose();
    }
  }

  Map<String, dynamic> openJson(String id, Map<String, dynamic> value) {
    final plain = openBytes(id, value);
    try {
      return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
  }

  static Map<String, dynamic> _seal(
    SodiumSumo sodium,
    SecureKey key,
    Uint8List bytes,
    String aad,
  ) {
    final aead = sodium.crypto.aeadXChaCha20Poly1305IETF;
    final nonce = sodium.randombytes.buf(aead.nonceBytes);
    return {
      'v': 1,
      'nonce': base64Encode(nonce),
      'box': base64Encode(
        aead.encrypt(
          message: bytes,
          nonce: nonce,
          key: key,
          additionalData: Uint8List.fromList(utf8.encode(aad)),
        ),
      ),
    };
  }

  static Uint8List _open(
    SodiumSumo sodium,
    SecureKey key,
    Map<String, dynamic> value,
    String aad,
  ) {
    if (value['v'] != 1) throw const FormatException('不支持的密文版本');
    return sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
      cipherText: base64Decode(value['box'] as String),
      nonce: base64Decode(value['nonce'] as String),
      key: key,
      additionalData: Uint8List.fromList(utf8.encode(aad)),
    );
  }

  void dispose() => master.dispose();
}
