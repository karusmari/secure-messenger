Faas 1: Vundament (Firebase + Auth)
Seo äpp Firebase'iga ära (nagu eelmises vastuses vaatasime flutterfire configure).

Tee valmis tavaline emaili/parooliga sisselogimine ja registreerimine.

Lisa sinna otsa biomeetria kontroll (local_auth).

Faas 2: Kasutajad ja kontaktid
Kasutajaprofiili loomine ja pildi üleslaadimine (firebase_storage + image_picker).

Otsinguriba, kus saab andmebaasist teisi kasutajaid otsida.

Faas 3: Tavaline chat (Tekst + Meedia)
Sõnumite saatmine Firestore'i (andmebaasi struktuur: chats -> messages).

Piltide ja videote saatmine (fail laetakse Firebase Storage'isse, link pannakse sõnumi sisse).

Faas 4: Turvalisus (Secret Chat)
Lisa krüpteerimise loogika. Kui valitakse "Secret Chat", siis enne Firestore'i saatmist jooksutad teksti läbi encrypt paki.