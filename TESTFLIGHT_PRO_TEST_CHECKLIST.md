# Yonder PRO — TestFlight / Sandbox Test Checklist

Bu dosya Yonder PRO satın alma akışını TestFlight veya sandbox ortamında test ederken kullanılacak kısa kontrol listesidir. Ürün kurulumu ve App Store Connect adımları için [PRO_RELEASE_CHECKLIST.md](PRO_RELEASE_CHECKLIST.md) dosyasına bakın.

## Ön Koşullar

- [ ] Xcode scheme → Edit Scheme → Run → Options → StoreKit Configuration alanı **None** (gerçek App Store Connect ürünlerini kullanmak için).
- [ ] Sandbox tester hesabıyla cihazda oturum açık (Ayarlar → App Store → Sandbox Account) veya TestFlight build'i gerçek cihaza yüklü.
- [ ] `debug_pro_override` kapalı (DEBUG build'de "Debug: Unlock PRO" butonuna basılmadıysa zaten kapalı).

## 1. Ürün Yükleme

- [ ] Paywall açıldığında aylık ürün (`com.emir.Yonder.pro.monthly`) görünüyor.
- [ ] Paywall açıldığında yıllık ürün (`com.emir.Yonder.pro.yearly`) görünüyor ve "BEST VALUE / ÖNERİLEN" etiketi taşıyor.
- [ ] Fiyatlar cihazın bölge/para birimine göre localize geliyor (`product.displayPrice`), sabit "$" gibi bir sembol görünmüyor.
- [ ] Her ürün satırında süre + otomatik yenilenme bilgisi görünüyor ("1 aylık abonelik · Otomatik yenilenir" / "1-year subscription · Auto-renews").
- [ ] Uçak modunda veya ağ kapalıyken paywall açıldığında "Ürünler yüklenemedi" paneli görünüyor, uygulama çökmüyor.
- [ ] "Tekrar Dene" butonu ağ geri geldiğinde ürünleri başarıyla yüklüyor.

## 2. Satın Alma Akışı

- [ ] Aylık ürüne dokunulduğunda sistem ödeme sayfası açılıyor.
- [ ] Satın alma tamamlandığında paywall otomatik kapanıyor ve PRO aktif oluyor.
- [ ] Yıllık ürün için aynı akış tekrarlanıyor (ayrı bir sandbox tester veya restore ile).
- [ ] Satın alma sırasında "Satın Alımı Geri Yükle" ve ürün butonları `isPurchasing` sırasında devre dışı kalıyor (çift tıklama önleniyor).

## 3. Satın Almayı İptal Etme (Cancel Purchase)

- [ ] Sistem ödeme sayfası açıldıktan sonra "Cancel" ile kapatılıyor.
- [ ] Uygulamada hata alert'i **görünmüyor** (sessiz iptal — beklenen davranış).
- [ ] PRO durumu değişmiyor, paywall açık kalıyor.

## 4. Restore Purchases

- [ ] Daha önce satın alım yapılmış bir sandbox hesabıyla, uygulamayı silip yeniden yükledikten sonra "Satın Alımı Geri Yükle" ile PRO geri geliyor.
- [ ] Hiç satın alım yapılmamış bir hesapla restore denendiğinde sessizce başarısız oluyor (gereksiz hata alert'i yok).

## 5. Hedef Kilidi (Goals Lock)

- [ ] Free hesapla Hedefler → Genel Çalışma Hedefleri'nde "Hedefi Kaydet" butonuna basıldığında paywall açılıyor.
- [ ] Free hesapla bir çalışma alanının hedef detay sayfasında "Hedefi Kaydet" butonuna basıldığında paywall açılıyor.
- [ ] Paywall'ı kapatıp (satın almadan) geri dönüldüğünde hiçbir hedef kaydedilmemiş oluyor.

## 6. Satın Alma Sonrası Hedef Kaydetme

- [ ] Genel hedef ekranında değerleri girip "Hedefi Kaydet"e basınca paywall açılıyor → satın alma tamamlanınca **otomatik olarak** genel hedef kaydediliyor ve toast görünüyor (ekstra bir "Kaydet" tıklaması gerekmiyor).
- [ ] Çalışma bazlı hedef detay sayfasında aynı akış: satın alma sonrası hedef otomatik kaydediliyor, sheet kapanıyor.
- [ ] Satın almadan önce var olan hedef verileri (varsa) silinmemiş, PRO sonrası da yerinde duruyor.
- [ ] PRO aktifken hedef ekranındaki "Kilitli" rozetleri kalkıyor, kilitli çalışma alanları düzenlenebiliyor.

## 7. Abonelik İptal / Expire Simülasyonu

Sandbox'ta abonelikler hızlandırılmış sürede yenilenir/expire olur (örn. 1 ay = birkaç dakika). Bunu kullanarak:

- [ ] Sandbox'ta satın alma yapıp App Store Connect → Sandbox Testers üzerinden ya da cihazda "Ayarlar → App Store → Sandbox Account → Manage" ile aboneliği iptal et.
- [ ] Aboneliğin sandbox süresi dolana kadar bekle (birkaç dakika), sonra uygulamayı **arka plana alıp tekrar öne getir** (foreground refresh tetiklenmeli).
- [ ] PRO durumu otomatik olarak kapanıyor mu kontrol et (Hedefler'de kilit rozetleri geri geliyor mu, `is_premium_user` false oluyor mu).
- [ ] Uygulamayı tamamen kapatıp yeniden açtığında da PRO durumu doğru (expired) görünüyor.
- [ ] Alternatif: DEBUG build'de "Debug: PRO Aç" ile manuel olarak PRO açılıp kapatılarak UI kilidinin doğru tepki verdiği hızlıca doğrulanabilir (bu StoreKit'i test etmez, sadece UI kilidini test eder).

## 8. Genel Sağlamlık

- [ ] Ayarlar → Aboneliği Yönet satırı Apple'ın abonelik yönetim ekranına yönlendiriyor.
- [ ] Paywall'daki "Kullanım Koşulları" ve "Gizlilik Politikası" linkleri açılıyor ve doğru sayfaya gidiyor.
- [ ] Uygulama arka plan/ön plan geçişlerinde veya ağ kesintilerinde çökmüyor.
