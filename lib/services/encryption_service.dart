import 'package:encrypt/encrypt.dart' as enc;

class EncryptionService {
  // AES krüpteerimine nõuab täpselt 32-märgist võtit (32 baiti)
  static final _key = enc.Key.fromUtf8('my32characterslongsecretkey12345');
  
  // IV (Initialization Vector) peab olema täpselt 16-märgine
  static final _iv = enc.IV.fromUtf8('1234567890123456');

  // Funktsioon 1: Muudab teksti krüpteeritud sodiks (Selle saadame Firebase'i)
  static String encryptText(String plainText) {
    final encrypter = enc.Encrypter(enc.AES(_key));
    final encrypted = encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64; 
  }

  // Funktsioon 2: Muudab sodi tagasi tekstiks (Seda näitame ekraanil)
  static String decryptText(String encryptedText) {
    try {
      final encrypter = enc.Encrypter(enc.AES(_key));
      final decrypted = encrypter.decrypt64(encryptedText, iv: _iv);
      return decrypted;
    } catch (e) {
      // Kui dekrüpteerimine ebaõnnestub, tagastame algse teksti (igaks juhuks)
      return encryptedText;
    }
  }
}