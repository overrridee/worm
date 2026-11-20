#!/usr/bin/env python3
"""
words.txt dosyasındaki tüm kelimeleri part_of_speech (İsim / Fiil / Sıfat / Zarf / İfade)
ve Türkçe-İngilizce karışık yaratıcı hafıza ipuçları (memory_hint) ile birlikte
standalone SQLite veritabanına (assets/worm.db) aktarır.
"""

import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORDS_FILE = ROOT / "words.txt"
DB_PATH = ROOT / "assets" / "worm.db"

# Öne çıkan YDS/YÖKDİL kelimeleri için özel yaratıcı Türkçe-İngilizce çağrışım ipuçları
CUSTOM_HINTS: dict[str, str] = {
    "abolish": "A-bol-iş: Gereksiz bol işleri ve eski yasayı tek kalemde abolish et (yürürlükten kaldır).",
    "abolition": "Abolish (kaldırmak) + -tion = Kaldırma, yürürlükten kaldırma süreci.",
    "absorb": "Ab-sorb: Sünger gibi suyu içine 'sorb'up çek — absorb = emmek, dengelemek.",
    "abuse": "Ab-use: 'Use' (kullanmak) ama abartılı/kötüye use = abuse (suistimal etmek).",
    "academic": "Akademi + -ic: Üniversite ve academic world (akademik dünya) ile ilgili.",
    "accelerator": "Accelerate (hızlanmak) + -or: Arabada hızı artıran pedal = gaz pedalı.",
    "accent": "Aksan: Konuşurken kelimelere verdiğin ton ve şive (foreign accent).",
    "access": "Ac-cess: Kapıdan içeri 'es'ip geçme hakkı = access (erişim, giriş yolu).",
    "accessible": "Access + -ible: Erişimi mümkün (able to access) = ulaşılabilir, kolay bulunur.",
    "accounting": "Account (hesap) + -ing: Hesapları sayma ve tutma işi = muhasebe.",
    "accumulate": "A-cumul-ate: 'Cumulative' (toplam) gibi üst üste yığ — accumulate = biriktirmek.",
    "accused": "Accuse (suçlamak) + -ed: Mahkemede 'accuse' edilen kişi = sanık, suçlanan.",
    "accustom": "A-custom: 'Custom' (alışkanlık/gelenek) haline getirmek = alıştırmak.",
    "accustomed": "Be accustomed to: Custom'a (alışkanlığa) dönüşmüş = alışık, alışkın.",
    "achieve": "A-chieve: 'Chief' (şef) gibi zirveye çıkıp başarmak = achieve.",
    "achievement": "Achieve + -ment: Başarının somut sonucu = büyük başarı.",
    "acknowledged": "Knowledge (bilgi) kökünden: Bildiğini kabul ve onay etmek.",
    "acknowledge": "Ac-knowledge: Bilgiyi ('knowledge') görüp kabul ve onay etmek.",
    "acquire": "Ac-quire: 'Require' (gerekmek) kardeşidir; gerekeni kendi tarafına çekip edinmek.",
    "acquisition": "Acquire + -tion: Yeni bir beceri veya şirket satın alma (edinim).",
    "addict": "Ad-dict: Bir şeye 'dik'ilip kopamayan kişi = bağımlı, müptela.",
    "admission": "Admit (kabul/itiraf etmek) -> Admission: Hem itiraf hem içeri giriş bileti.",
    "adopt": "Ad-opt: Bir fikri veya çocuğu 'opt' (seçip) sahiplenmek = benimsemek / evlat edinmek.",
    "adverse": "Ad-verse: Ters yöne ('reverse' gibi) esen rüzgâr = olumsuz, zararlı (adverse effects).",
    "allocate": "Al-locate: 'Locate' (konumlandırmak) -> Bütçeyi yerli yerine dağıtmak, tahsis etmek.",
    "allow": "All-ow: Herkese izin vermek.",
    "allowance": "Allow + -ance: Düzenli izin verilen para = harçlık, ödenek.",
    "ally": "Al-ly: 'Alliance' (ittifak) kökünden; sırtını yasladığın dost = müttefik.",
    "alter": "Alt-er: Klavyedeki 'Alt' tuşu gibi bir şeyi başka hale değiştirmek.",
    "alternative": "Alter + -native: Değiştirilebilecek diğer seçenek = alternatif.",
    "amend": "A-mend: 'Mend' (onarmak) kökünden; yasa veya metni düzeltip iyileştirmek.",
    "ample": "Amp-le: 'Amplify' (büyütmek) gibi geniş, bol ve ferah (ample time).",
    "anticipate": "Anti-cip-ate: 'Avant' (önden) kapmak -> Geleceği öngörmek ve beklemek.",
    "apparently": "Appear (görünmek) + -ly: Görünüşe göre, belli ki, anlaşılan.",
    "aspect": "A-spect: 'Spect' (bakmak) kökünden -> Bir konuya baktığın yön, açı, durum.",
    "asset": "As-set: Elindeki en değerli set/varlık = asset (kıymet, artı değer).",
    "assurance": "Assure + -ance: 'Sure' (emin) kılma durumu = güvence, teminat.",
    "assure": "As-sure: Karşındakini 'sure' (emin) hale getirmek = söz verip ikna etmek.",
    "augment": "Aug-ment: 'August' (yüce/büyük) kökünden; miktarı büyütüp artırmak.",
    "authority": "Author (yazar/kurucu) + -ity: Sözü geçen yetkili makam ve otorite.",
    "awkward": "Awk-ward: Ters yöne ('-ward') düşen sakar, garip ve anlaşılması güç durum.",
    "banish": "Ban-ish: 'Ban' (yasak) koyup ülkeden veya aklından sürgüne göndermek.",
    "beforehand": "Before + hand: Her şey elinin ('hand') altında olmadan önce = önceden.",
    "bias": "Bi-as: Tek tarafa eğilen terazi gibi = önyargı, taraflı eğilim.",
    "boundary": "Bound (sınır) + -ary: İki alanı ayıran çizgi = sınır.",
    "brevity": "Brief (kısa) -> Brevity: Sözün kısa ve öz olması.",
    "bureaucracy": "Bureau (büro/ofis) + -cracy (yönetim) = Bürokrasi, evrak işleri.",
    "cancellation": "Cancel + -ation: Planın veya uçuşun tamamen iptali.",
    "capable": "Cap-able: Kapasitesi ('capacity') yeten = yetenekli, muktedir.",
    "caution": "Cau-tion: 'Caution!' tabelası gibi dikkat, uyarı ve ihtiyat.",
    "cease": "Cease-fire (ateşkes) buradan gelir: Durmak, sona ermek.",
    "cease-fire": "Cease (dur) + Fire (ateş) = Ateşin durması, ateşkes.",
    "co-operate": "Co (birlikte) + Operate (çalışmak) = El ele verip birlikte çalışmak.",
    "collapse": "Col-lapse: 'Lapse' (kayma/düşme) ile her şeyin birden çökmesi.",
    "colleague": "Col (birlikte) + League (birlik) = Aynı takımdaki meslektaş.",
    "come across": "Come + across: Yolun karşısına geçerken tesadüfen karşılaşmak / bulmak.",
    "commemorate": "Com + memory (hafıza) + -ate: Birlikte hafızada canlandırıp anmak.",
    "commit": "Com-mit: Bir işe kendini adamak veya suç işlemek (commit a crime).",
    "commitment": "Commit + -ment: Sözünde durma sorumluluğu ve taahhüt.",
    "commute": "Com-mute: Her gün ev-iş arası mekik dokumak (uzun yol gidip gelmek).",
    "compensate": "Com-pens-ate: Eksik kalan teraziyi eşitlemek = telafi etmek, karşılamak.",
    "complicated": "Complic-ated: İç içe katlanmış = karışık, komplike.",
    "compromise": "Com-promise: İki tarafın da biraz söz ('promise') verip ortada uzlaşması.",
    "concentrate": "Con-centr-ate: Tüm dikkati tek bir merkezde ('center') toplamak.",
    "concept": "Con-cept: Zihinde tutulan genel fikir, kavram.",
    "concern": "Con-cern: Bir konu hakkında endişe duymak veya seni ilgilendirmek.",
    "conclusion": "Conclude (sonuçlandırmak) -> Son karar, sonuç.",
    "condemn": "Con-demn: 'Damn' gibi sertçe kınamak veya mahkûm etmek.",
    "conduct": "Con-duct: Bir araştırmayı/orkestrayı yönetip yürütmek; davranış.",
    "confine": "Con-fine: 'Fine' (sınır) içine kapatmak = sınırlamak, hapsetmek.",
    "conflict": "Con-flict: İki fikrin çarpışması = çatışma, çelişki.",
    "consent": "Con-sent: Aynı hissi ('sense') paylaşıp onaylamak = rıza, onay.",
    "consequently": "Consequence (sonuç) + -ly: Bunun sonucu olarak, bundan dolayı.",
    "consistent": "Con-sist-ent: Başından sonuna aynı çizgide duran = tutarlı, uyumlu.",
    "constitute": "Con-stitute: Parçaların bir araya gelip bütünü oluşturması.",
    "consume": "Con-sume: Enerjiyi veya yiyeceği tamamen tüketmek.",
    "contribute": "Con-tribute: Ortaya kendi payını koyup katkıda bulunmak.",
    "convince": "Con-vince: 'Victory' kökünden -> Karşındakini ikna edip kazanmak.",
    "cope": "Cope with: Zorlukla başa çıkmak, idare etmek.",
    "corruption": "Corrupt (bozuk) + -ion: Sistemin bozulması = yolsuzluk, rüşvetçilik.",
    "criterion": "Kriter: Karar verirken baktığın temel ölçüt (çoğulu: criteria).",
    "crucial": "Crux (haç/kavşak) kökünden: Yol ayrımındaki en hayati, çok önemli nokta.",
    "deadline": "Dead + line: Geçersen işin 'ölü' sayılacağı çizgi = son teslim tarihi.",
    "deadlock": "Dead + lock: İki tarafın da kilitlenip kaldığı tam çıkmaz, açmaz.",
    "debate": "De-bate: İki karşıt fikrin tartışması (public debate).",
    "decay": "De-cay: Zamanla aşağı doğru bozulup çürümek.",
    "decline": "De-cline: Yokuş aşağı ('incline' tersi) inmek = azalmak, gerilemek.",
    "decrease": "De-crease: 'Increase' (artmak) kelimesinin tam zıttı = azalmak.",
    "defer": "De-fer: 'Delay' (ertele) ile aynı baş harf -> İleri bir tarihe ertelemek.",
    "deficit": "De-ficit: Kasada eksik ('deficient') kalan miktar = bütçe açığı.",
    "deliberately": "Deliberate + -ly: Düşünerek, kasten, bile bile.",
    "demoralize": "De- (boz) + Morale (moral) = Moral bozmak, cesaret kırmak.",
    "desperate": "De-sperate: Umudunu ('hope') kaybetmiş = umutsuz, çok acil/ciddi.",
    "despite": "De-spite: 'In spite of' ile aynı anlam = -e rağmen.",
    "disaster": "Dis-aster: Eski dilde 'kötü yıldız' -> Büyük felaket, afet.",
    "disclose": "Dis- (aç) + Close (kapalı) = Kapalı olanı açığa çıkarmak, ifşa etmek.",
    "disparity": "Dis- (farklı) + Parity (eşitlik) = Eşitsizlik, uçurum.",
    "dispatch": "Dis-patch: Paketi veya ekibi hızla yola çıkarmak, sevk etmek.",
    "displace": "Dis- (dışarı) + Place (yer) = Yerinden etmek, çıkarmak.",
    "distinction": "Distinct (ayrı) + -ion: İki şey arasındaki net ayrım, fark veya üstünlük.",
    "dominate": "Domin-ate: Dominant (baskın) olup her şeye hâkim olmak.",
    "donate": "Don-ate: 'Donor' (bağışçı) gibi gönülden bağış yapmak.",
    "embark": "Em-bark: 'Bark' (gemi) içine binmek veya yeni bir yolculuğa başlamak (embark on).",
    "embrace": "Em-brace: Kollarını ('brace') açıp kucaklamak; yeni fikri benimsemek.",
    "emphasis": "Em-phasis: Bir kelimenin veya konunun üzerine basılan vurgu.",
    "emphasize": "Emphasis + -ize: Üzerinde durup vurgulamak.",
    "enormous": "E-norm-ous: 'Normal' ölçülerin çok dışına çıkan = kocaman, devasa.",
    "entitle": "En-title: Sana bir 'title' (unvan/hak) vermek = yetki ve hak vermek.",
    "equip": "E-quip: Ekipmanlarla ('equipment') donatmak.",
    "evacuate": "E-vacu-ate: 'Vacuum' (boşluk) gibi alanı hızla boşaltıp tahliye etmek.",
    "evidence": "Evid-ence: 'Video' (görmek) kökünden -> Gözle görülür delil, kanıt.",
    "exceed": "Ex-ceed: Sınırın dışına ('ex-') çıkıp aşmak, geçmek.",
    "exclusive": "Ex-clusive: Dışarıdakilere kapalı ('exclude'), sadece özel kişilere açık.",
    "execute": "Ex-ecute: Bir planı eksiksiz yerine getirmek / uygulamak.",
    "exhaust": "Ex-haust: Tüm enerjiyi dışarı boşaltıp tüketmek, çok yormak.",
    "expand": "Ex-pand: Genişleyip büyümek (expand a business).",
    "expire": "Ex-pire: Son kullanma tarihinin/nefesinin dolması, sona ermek.",
    "extinguish": "Ex-tinguish: Ateşi veya ışığı söndürmek (fire extinguisher = yangın tüpü).",
    "fertile": "Fert-ile: Toprağın bereketli ve ürün vermeye çok elverişli olması.",
    "flee": "Flee -> Fly gibi: Tehlikeden hızla kaçıp uzaklaşmak.",
    "fluent": "Flu-ent: 'Fluid' (akışkan) gibi su gibi akıcı konuşmak.",
    "forever": "For + ever: Her zaman için = sonsuza dek.",
    "fragile": "Frag-ile: 'Fragment' (parça) gibi dokunsan kırılacak = kırılgan.",
    "fundamental": "Fund-amental: 'Foundation' (temel) gibi olmazsa olmaz temel unsur.",
    "furthermore": "Further + more: Üstelik, bunun yanı sıra, dahası.",
    "grateful": "Great + -ful: Yapılan iyiliğe karşı içi minnet dolu (minnettar).",
    "habitat": "Habit-at: Canlının alışıp ('habit') yaşadığı doğal yuva.",
    "halt": "Halt!: Askeri 'Dur!' komutu gibi durmak veya durdurmak.",
    "handicap": "Handi-cap: Yarışta önüne konan engel, dezavantaj.",
    "heritage": "Herit-age: 'Inherit' (miras almak) ile kardeş -> Kültürel miras.",
    "hinder": "Hind-er: 'Behind' (geride) bırakıp ilerlemeyi engellemek.",
    "ignore": "Ig-nore: Bilmezden ('ignorant') gelip önemsememek.",
    "illustrate": "Il-lustr-ate: Resim veya örnekle konuyu aydınlatıp göstermek.",
    "impair": "Im-pair: 'Pair' (çift/denge) düzenini bozup zayıflatmak, zarar vermek.",
    "implement": "Im-plement: Planı kâğıttan çıkarıp yürürlüğe koymak, uygulamak.",
    "imply": "Im-ply: Açıkça söylemeden satır arasında ima etmek.",
    "incentive": "In-cent-ive: Harekete geçiren teşvik, ödül (tax incentive).",
    "incidentally": "Incident + -ally: Bu arada, tesadüfen aklıma gelmişken.",
    "inevitable": "In- (değil) + Evit (kaçmak) + -able = Kaçınılması imkânsız, kaçınılmaz.",
    "infinite": "In- (sonsuz) + Finite (sınırlı) = Sınırı olmayan, sonsuz.",
    "inflation": "Inflate (şişirmek) + -ion: Fiyatların şişmesi = enflasyon.",
    "initiative": "Initial (ilk) kökünden: İlk adımı atma cesareti, girişim, inisiyatif.",
    "inspire": "In-spire: İçine ruh/nefes ('spirit') üflemek = ilham vermek.",
    "intangible": "In- (değil) + Tangible (dokunulur) = Elle tutulamayan, soyut, manevi.",
    "interfere": "Inter-fere: İki şeyin arasına ('inter') girip karışmak, müdahale etmek.",
    "involve": "In-volve: İçine alıp kapsamak, gerektirmek.",
    "ironically": "Irony + -ally: Ne gariptir ki, işin ilginç/ironik yanı.",
    "keen": "Keen on: Bir şeye çok hevesli, istekli ve keskin gözlü.",
    "launch": "Launch: Roketi fırlatmak veya yeni bir ürünü/projeyi başlatmak.",
    "limit": "Limit: Aşılmaması gereken sınır, had.",
    "maintain": "Main-tain: 'Main' (ana) durumu elinde ('tain') tutup sürdürmek, korumak.",
    "majority": "Major (büyük) + -ity: Büyük kısım, çoğunluk.",
    "mature": "Ma-ture: Meyvenin veya insanın olgunlaşmış hali.",
    "merely": "Mere + -ly: Sadece, yalnızca, ancak.",
    "merge": "Merge: İki yolun veya şirketin birleşip tek olması.",
    "might": "Might: Hem 'belki' ihtimali hem de büyük güç/kudret.",
    "miserable": "Misery (sefalet) + -able: Çok mutsuz, perişan, sefil.",
    "mutual": "Mut-ual: İki tarafın da birbirine karşı duyduğu = karşılıklı, ortak.",
    "negotiate": "Ne-goti-ate: Oturup pazarlık ve müzakere etmek.",
    "notorious": "Note + -orious: Herkesin bildiği ama KÖTÜ ünüyle adı çıkmış.",
    "oblige": "Ob-lige: Birini zorunlu kılmak veya iyilik yapıp minnettar bırakmak.",
    "occur": "Oc-cur: Olayın meydana gelmesi, gerçekleşmesi.",
    "omit": "O-mit: Bir maddeyi bilerek veya unutarak atlamak, hariç bırakmak.",
    "overdue": "Over + due: Vadesi ('due') üzerinden zaman geçmiş, gecikmiş.",
    "overtake": "Over + take: Yolda öndeki aracı geçip sollamak.",
    "participate": "Part (parça) + -icipate: Bir etkinliğin parçası olup katılmak.",
    "passive": "Pass-ive: Harekete geçmeyen, eylemsiz, pasif.",
    "peril": "Peril: 'Dangerous' ile yakın anlamlı -> Büyük tehlike.",
    "permanent": "Per-manent: 'Remain' (kalmak) gibi sürekli ve kalıcı.",
    "persist": "Per-sist: Vazgeçmeden ısrarla devam etmek.",
    "pessimist": "Pessim-ist: Her şeye kötü tarafından bakan = kötümser (zıttı: optimist).",
    "pioneer": "Pion-eer: Bilinmeyen alana ilk giren öncü.",
    "precious": "Preci-ous: 'Price' (değer) kökünden -> Çok kıymetli, değerli.",
    "precisely": "Precise + -ly: Kesinlikle, tam olarak, nokta atışı.",
    "preserve": "Pre-serve: Bozulmadan önceden ('pre-') koruyup saklamak.",
    "primarily": "Primary + -ly: Başlıca, esas olarak, ilk sırada.",
    "primary": "Prime (birinci) -> Ana, öncelikli, ilk.",
    "priority": "Prior (önce) + -ity: Her şeyden önce gelen öncelik.",
    "privilege": "Privi-lege: Sadece özel kişilere tanınan ayrıcalık, imtiyaz.",
    "prohibit": "Pro-hibit: Yasaklamak (prohibition = yasak).",
    "promote": "Pro-mote: İleri ('pro') hareket ettirmek = terfi ettirmek, teşvik ve tanıtım yapmak.",
    "proportion": "Pro-portion: Bütüne göre düşen pay, orantı.",
    "prosecute": "Pro-secute: Mahkemede peşine düşüp dava açmak, kovuşturmak.",
    "provoke": "Pro-voke: 'Voice' (ses) çıkarıp birini kışkırtmak, kızdırmak.",
    "punctual": "Punct-ual: 'Point' (nokta) gibi tam vaktinde gelen, dakik.",
    "qualified": "Qualify + -ed: Gerekli niteliklere (quality) sahip = ehliyetli, kalifiye.",
    "recession": "Re-cess-ion: Ekonominin geri ('re-') çekilip durgunluğa girmesi.",
    "reconcile": "Re-concile: Küskün tarafları tekrar ('re-') bir araya getirip uzlaştırmak.",
    "relevant": "Relev-ant: Konuyla doğrudan bağlantılı ve ilgili (zıttı: irrelevant).",
    "reliable": "Rely (güvenmek) + -able: Sırtını dayayabileceğin = güvenilir.",
    "reluctant": "Re-luct-ant: İçinden gelmeyen = isteksiz, gönülsüz.",
    "remedy": "Remedy: Hastalığa veya soruna iyi gelen çare, ilaç.",
    "reputation": "Reput-ation: Toplumda bıraktığın itibar ve ün.",
    "resent": "Re-sent: İçine oturup gücenmek, içerlemek.",
    "reside": "Re-side: Bir yerde ikamet edip oturmak (resident = oturan).",
    "respond": "Re-spond: Gelen soruya veya duruma cevap vermek.",
    "restore": "Re-store: Eski güzel haline geri ('re-') döndürüp onarmak.",
    "restrict": "Re-strict: 'Strict' (katı) kurallarla sınırlamak.",
    "resume": "Re-sume: Durduktan sonra kaldığı yerden yeniden başlamak.",
    "retaliation": "Re-tali-ation: Misilleme yapıp karşılık verme, tepki.",
    "revenue": "Re-venue: Şirkete veya devlete geri ('re-') dönen para = gelir.",
    "revise": "Re-vise: 'Vision' (görmek) -> Tekrar gözden geçirip düzeltmek.",
    "rid": "Get rid of: İstenmeyen bir şeyden kurtulup başından atmak.",
    "sacrifice": "Sacri-fice: Değerli bir şeyden vazgeçip fedakârlık yapmak.",
    "secure": "Se-cure: Endişeden uzak, emniyetli ve sağlam.",
    "shortage": "Short + -age: Bir kaynağın kısa/eksik kalması = kıtlık, yokluk.",
    "shrink": "Shrink: Sıcakta yıkanan kazak gibi çekip küçülmek.",
    "significant": "Sign-ificant: Dikkat çekici işareti olan = manalı, önemli.",
    "sincere": "Sin-cere: Yapmacıksız, içten ve samimi.",
    "sophisticated": "Sophistic-ated: Çok gelişmiş, karmaşık ve görmüş geçirmiş.",
    "stabilize": "Stable + -ize: Sallantıyı durdurup dengelemek, istikrara kavuşturmak.",
    "stable": "Stable: Sağlam duran, istikrarlı (veya ahır).",
    "steep": "Steep: Yokuşun çok dik olması veya fiyatların birden fırlaması.",
    "submit": "Sub-mit: İncelemeye/onaya sunmak veya boyun eğmek.",
    "subsidize": "Subsidy + -ize: Devlet desteğiyle maddi olarak desteklemek, sübvanse etmek.",
    "substitute": "Sub-stitute: Yedek oyuncu gibi birinin yerine geçmek / koymak.",
    "sufficient": "Suf-ficient: Yeterli miktarda (insufficient = yetersiz).",
    "summary": "Sum (toplam) + -ary: Uzun konunun kısa özeti.",
    "superior": "Super-ior: 'Super' kökünden -> Daha iyi, üstün, amir.",
    "supervise": "Super-vise: 'Super' (üstten) + 'Vis' (görmek) = Denetlemek, gözetmek.",
    "suppress": "Sup-press: Aşağı ('sub') bastırıp ('press') sindirmek, önlemek.",
    "surrender": "Sur-render: Mücadeleyi bırakıp teslim olmak.",
    "suspend": "Sus-pend: Havada asılı bırakmak = askıya almak, durdurmak.",
    "suspicion": "Sus-picion: 'Suspect' (şüpheli) kökünden -> İçine doğan şüphe.",
    "temporary": "Tempor-ary: 'Tempo/zaman' ile sınırlı = geçici (zıttı: permanent).",
    "tempt": "Tempt: Tatlı bir vitrin gibi insanı cezbedip aklını çelmek.",
    "tend": "Tend to: Bir yöne doğru eğilimli olmak, meyilli olmak.",
    "thoroughly": "Thorough + -ly: Hiçbir detayı atlamadan tamamen, ince eleyip sık dokuyarak.",
    "tough": "Tough: Zorlu, sert ve dayanıklı (tough times).",
    "transform": "Trans-form: Bir formdan ('form') bambaşka bir şekle dönüştürmek.",
    "transparent": "Trans-parent: Işığı öte tarafa ('trans-') geçiren = saydam, şeffaf.",
    "tremendous": "Tremend-ous: Titretecek kadar çok büyük, muazzam, harika.",
    "trigger": "Trigger: Tetiği çekip bir olayı tetiklemek, yol açmak.",
    "undergo": "Under + go: Zorlu bir ameliyat veya değişim sürecinden geçmek, maruz kalmak.",
    "urban": "Urb-an: 'Suburb' (banliyö) ile akraba -> Şehre ve kente ait (zıttı: rural).",
    "venture": "Venture: Adventure (macera) gibi riskli ama heyecanlı girişim.",
    "verdict": "Ver-dict: 'Verify' (doğru) + 'Dict' (söylemek) = Mahkemenin son hükmü.",
    "viable": "Vi-able: 'Vital' (yaşam) kökünden -> Yaşayabilir, uygulanabilir.",
    "vicious circle": "Vicious (kötü) + Circle (döngü) = İçinden çıkılamayan kısır döngü.",
    "victimize": "Victim (kurban) + -ize: Birini haksız yere mağdur etmek.",
    "vital": "Vit-al: Vitamin gibi yaşam için çok önemli, hayati.",
    "vulnerable": "Vulner-able: 'Wound' (yara) almaya açık = savunmasız, kırılgan.",
    "wisdom": "Wise (bilge) + -dom: Yılların getirdiği bilgelik ve sağduyu.",
}


def infer_pos(word: str, meanings: list[str]) -> str:
    w = word.strip().lower()
    joined_tr = " ".join(meanings).lower()

    # İfade / kalıp kontrolü
    if " " in w or w in {"v.i.p.", "ufo", "co", "ex"}:
        if any(m.lower().endswith(("mek", "mak")) for m in meanings):
            return "Fiil İfadesi"
        return "İfade / Kalıp"

    has_verb_tr = any(
        re.search(r"(mek|mak)\b", m.strip().lower()) for m in meanings
    )
    has_non_verb_tr = any(
        not re.search(r"(mek|mak)\b", m.strip().lower()) for m in meanings
    )

    # Açık zarf ekleri
    if w.endswith("ly") and not w.endswith(("ally", "ily")) or w in {
        "beforehand",
        "forthwith",
        "forever",
        "precisely",
        "deliberately",
        "apparently",
        "anxiously",
        "consequently",
        "incidentally",
        "indefinitely",
        "ironically",
        "merely",
        "primarily",
        "thoroughly",
    }:
        return "Zarf"

    if w in {"despite", "upon", "via"}:
        return "Edat / Bağlaç"
    if w in {"furthermore"}:
        return "Bağlaç / Zarf"

    if has_verb_tr and has_non_verb_tr:
        return "Fiil / İsim"
    if has_verb_tr:
        return "Fiil"

    # Sıfat ekleri ve ipuçları
    adj_suffixes = (
        "able",
        "ible",
        "ous",
        "ful",
        "less",
        "ive",
        "ic",
        "al",
        "ant",
        "ent",
        "ary",
        "ory",
        "ish",
    )
    if (
        w.endswith(adj_suffixes)
        and not w.endswith(("animal", "hospital", "festival", "metal", "canal", "signal", "terminal", "editorial", "manual", "capital", "journal", "scandal", "medal", "pedal", "sandal", "rival", "trial", "arrival", "survival", "proposal", "approval", "removal", "refusal", "agent", "client", "patient", "parent", "student", "president", "resident", "accident", "incident", "moment", "comment", "element", "document", "instrument", "argument", "experiment", "department", "apartment", "government", "equipment", "achievement", "commitment", "entertainment", "environment", "management", "statement", "treatment", "agreement", "investment", "development", "improvement", "movement", "payment", "replacement", "requirement", "retirement", "settlement", "tournament", "accent", "talent", "cement", "tenant", "consent", "sergeant", "patent", "content", "extent", "percent", "event", "library", "secretary", "salary", "dictionary", "factory", "history", "memory", "theory", "victory", "category", "territory", "laboratory", "directory", "mystery", "story"))
    ) or w in {
        "awkward",
        "banal",
        "bony",
        "boring",
        "broken",
        "casual",
        "cheeky",
        "chilly",
        "crisp",
        "crude",
        "deaf",
        "decent",
        "desperate",
        "dim",
        "exclusive",
        "extreme",
        "fake",
        "fancy",
        "fed up",
        "fertile",
        "foul",
        "fragile",
        "frank",
        "gay",
        "huge",
        "insecure",
        "keen",
        "lonely",
        "loyal",
        "massive",
        "mature",
        "mild",
        "miserable",
        "mobile",
        "nasty",
        "naughty",
        "notorious",
        "odd",
        "old-fashioned",
        "opaque",
        "oval",
        "overdue",
        "packed",
        "passive",
        "precious",
        "primitive",
        "punctual",
        "pure",
        "qualified",
        "rash",
        "reluctant",
        "scarce",
        "second-rate",
        "secure",
        "senior",
        "shallow",
        "silly",
        "sincere",
        "smart",
        "sophisticated",
        "stable",
        "steep",
        "sterile",
        "swollen",
        "tiny",
        "tough",
        "transparent",
        "tremendous",
        "unfair",
        "upside-down",
        "urban",
        "viable",
        "vulnerable",
        "waterproof",
    }:
        return "Sıfat"

    if "sıfat" in joined_tr:
        return "Sıfat"

    return "İsim"


def build_hint(word: str, pos: str, meanings: list[str]) -> str:
    key = word.strip().lower()
    if key in CUSTOM_HINTS:
        return CUSTOM_HINTS[key]

    primary_meaning = meanings[0]
    alt = meanings[1] if len(meanings) > 1 else ""

    # İngilizce önek/sonek tabanlı akılda kalıcı çağrışımlar
    if key.startswith("un") and len(key) > 4:
        root = word[2:]
        return f"'{root}' kelimesinin başına 'un-' (olumsuzluk) gelmiş -> {primary_meaning}."
    if key.startswith("in") and pos == "Sıfat" and len(key) > 5:
        return f"'in-' öneki burada olumsuzluk/içerme katar: {word} = {primary_meaning}."
    if key.startswith("re") and len(key) > 4 and pos.startswith("Fiil"):
        return f"'re-' (tekrar/geri) vurgusuyla hatırla: {word} -> {primary_meaning}."
    if key.startswith("over") and len(key) > 5:
        rest = word[4:]
        return f"'Over' (aşırı/üzerinden) + '{rest}' -> {primary_meaning}."
    if key.endswith("less") and len(key) > 5:
        root = word[:-4]
        return f"'{root}' + '-less' (yok/olmadan) -> {primary_meaning}."
    if key.endswith("ful") and len(key) > 4:
        root = word[:-3]
        return f"'{root}' + '-ful' (dolu/taşıyan) -> {primary_meaning}."
    if key.endswith("tion") or key.endswith("sion"):
        return f"'-tion/-sion' eki isimleştirir: {word} ({primary_meaning})."
    if key.endswith("ment") and len(key) > 5:
        root = word[:-4]
        return f"'{root}' eyleminin sonucu (-ment) -> {primary_meaning}."
    if key.endswith("able") or key.endswith("ible"):
        return f"'-able/-ible' (yapılabilir/olabilir) ekiyle: {word} = {primary_meaning}."
    if key.endswith("ly") and pos == "Zarf":
        root = word[:-2]
        return f"'{root}' sıfatına '-ly' eklenerek zarf olmuş -> {primary_meaning}."

    if pos.startswith("Fiil"):
        if alt:
            return f"Aksiyon (Fiil): '{word}' dendiğinde aklına '{primary_meaning}' veya '{alt}' gelsin."
        return f"Eylem (Fiil): Cümlede '{word}' gördüğünde '{primary_meaning}' anlamını hatırla."

    if pos == "Sıfat":
        if alt:
            return f"Özellik (Sıfat): Bir şeyi '{primary_meaning}' / '{alt}' diye nitelemek için '{word}' kullanılır."
        return f"Niteleme (Sıfat): '{word}' = '{primary_meaning}' özelliğini anlatır."

    if pos == "Zarf":
        return f"Nasıl/Ne zaman? (Zarf): '{word}' eylemi '{primary_meaning}' şeklinde niteler."

    if pos.startswith("İfade"):
        return f"Kalıp İfade: Konuşma ve metinlerde '{word}' kalıbı '{primary_meaning}' anlamında geçer."

    # İsimler için ses/anlam çağrışımı
    if alt:
        return f"'{word}' (İsim) = '{primary_meaning}' / '{alt}' kavramını karşılar."
    return f"'{word}' kelimesini görsel olarak '{primary_meaning}' nesnesi/kavramıyla eşleştir."


def parse_words_txt(path: Path) -> list[tuple[str, str, list[str], str]]:
    items: list[tuple[str, str, list[str], str]] = []
    seen: set[str] = set()
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        c1 = line.find(",")
        if c1 <= 0:
            continue
        c2 = line.find(",", c1 + 1)
        if c2 <= c1 + 1:
            continue

        word = line[:c1].strip()
        meanings_raw = line[c1 + 1 : c2].strip()
        sentence = line[c2 + 1 :].strip()
        meanings = [m.strip() for m in meanings_raw.split("#") if m.strip()]
        if not word or not meanings:
            continue

        key = word.lower()
        if key in seen:
            continue
        seen.add(key)
        items.append((key, word, meanings, sentence))
    return items


def main() -> None:
    items = parse_words_txt(WORDS_FILE)
    if DB_PATH.exists():
        DB_PATH.unlink()
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(DB_PATH)
    try:
        cur = conn.cursor()
        cur.execute(
            """
            CREATE TABLE words (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                word_key TEXT UNIQUE NOT NULL,
                foreign_word TEXT NOT NULL,
                meanings TEXT NOT NULL,
                example_sentence TEXT NOT NULL,
                part_of_speech TEXT NOT NULL,
                memory_hint TEXT NOT NULL,
                order_index INTEGER NOT NULL
            )
            """
        )
        cur.execute("CREATE INDEX idx_words_order ON words(order_index)")
        cur.execute("CREATE INDEX idx_words_key ON words(word_key)")

        rows = []
        for idx, (key, word, meanings, sentence) in enumerate(items):
            pos = infer_pos(word, meanings)
            hint = build_hint(word, pos, meanings)
            rows.append(
                (
                    key,
                    word,
                    "#".join(meanings),
                    sentence,
                    pos,
                    hint,
                    idx,
                )
            )

        cur.executemany(
            """
            INSERT INTO words (
                word_key, foreign_word, meanings, example_sentence,
                part_of_speech, memory_hint, order_index
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            rows,
        )
        conn.commit()
    finally:
        conn.close()

    print(f"SQLite veritabanı oluşturuldu: {DB_PATH} ({len(items)} kelime)")


if __name__ == "__main__":
    main()
