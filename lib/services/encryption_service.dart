import 'package:encrypt/encrypt.dart' as enc;

class EncryptionService {
  // AES cryptography requires a key and an initialization vector (IV)
  static final _key = enc.Key.fromUtf8('my32characterslongsecretkey12345');
  
  // IV (Initialization Vector) has to be 16 bytes long for AES.
  static final _iv = enc.IV.fromUtf8('1234567890123456');

  // Encrypting the text (for secret messages before sending to Firestore)
  static String encryptText(String plainText) {
    final encrypter = enc.Encrypter(enc.AES(_key));
    final encrypted = encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64; 
  }

  // decrypting the text (for secret messages when reading from Firestore)
  static String decryptText(String encryptedText) {
    try {
      final encrypter = enc.Encrypter(enc.AES(_key));
      final decrypted = encrypter.decrypt64(encryptedText, iv: _iv);
      return decrypted;
    } catch (e) {
      // in case of any error during decryption (e.g., wrong key, corrupted data), we return an error message instead of crashing the app
      return encryptedText;
    }
  }
}