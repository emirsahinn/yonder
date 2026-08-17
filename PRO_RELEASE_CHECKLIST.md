# Yonder PRO — StoreKit & Release Checklist

Bu doküman Yonder PRO ödeme altyapısını App Store'a hazır hale getirmek için kullanılacak canlı kontrol listesidir.

## 1. Kodda Tanımlı Product ID'ler

Kod tarafındaki product ID'ler:

| Paket | Product ID | Tür |
| --- | --- | --- |
| Yonder PRO Monthly | `com.emir.Yonder.pro.monthly` | Auto-renewable subscription |
| Yonder PRO Yearly | `com.emir.Yonder.pro.yearly` | Auto-renewable subscription |

Kod konumu:

- `Yonder/Services/ProStore.swift`

Bu ID'ler App Store Connect'te birebir aynı yazılmalı. Harf, nokta ve büyük/küçük karakter farkı satın alma ürünlerinin yüklenmemesine neden olur.

## 2. PRO ile Açılan Özellikler

| Özellik | Free | PRO |
| --- | --- | --- |
| Çalışma alanı sayısı | 10 aktif çalışma | Sınırsız |
| Hedefler | Kilitli | Genel + çalışma bazlı hedefler |
| Hatırlatıcılar | 1 aktif hatırlatıcı | Daha fazla aktif hatırlatıcı |
| Saat görünümleri | Flip Clock | Tüm PRO saat stilleri |

Kilit mantığı hâlâ merkezi `is_premium_user` değeriyle çalışır. Bu değer artık `ProStore` tarafından StoreKit entitlement durumuna göre güncellenir.

## 3. App Store Connect Kurulumu

1. App Store Connect → My Apps → Yonder → Monetization / In-App Purchases.
2. Yeni bir subscription group oluştur:
   - Önerilen ad: `Yonder PRO`
3. İki auto-renewable subscription ekle:
   - `com.emir.Yonder.pro.monthly`
   - `com.emir.Yonder.pro.yearly`
4. Her ürün için lokalizasyon ekle:
   - Display Name EN: `Yonder PRO Monthly`, `Yonder PRO Yearly`
   - Display Name TR: `Yonder PRO Aylık`, `Yonder PRO Yıllık`
   - Description EN: `Unlock unlimited work areas, goals, reminders, and clock styles.`
   - Description TR: `Sınırsız çalışma, hedefler, hatırlatıcılar ve saat görünümlerini aç.`
5. Fiyatları seç.
6. Ürünleri App Review için hazır duruma getir.

## 4. Xcode StoreKit Local Test

App Store Connect ürünleri hazır değilken local test için:

1. Xcode → File → New → File from Template.
2. `StoreKit Configuration File` seç.
3. Dosya adı önerisi: `YonderStoreKit.storekit`.
4. İçine aynı product ID'lerle monthly/yearly subscription ekle.
5. Scheme → Edit Scheme → Run → Options → StoreKit Configuration alanından bu dosyayı seç.
6. Uygulamayı simulator veya gerçek cihazda çalıştır.
7. Ayarlar → Yonder PRO → satın alma, restore ve iptal/yenileme senaryolarını test et.

Not: StoreKit local test App Store sunucusuna gitmez. Sandbox/TestFlight testi ayrıca yapılmalı.

## 5. Sandbox ve TestFlight Test Sırası

1. App Store Connect product ID'leri oluştur.
2. Sandbox tester hesabı oluştur.
3. Xcode scheme içindeki StoreKit configuration seçimini `None` yap.
4. Gerçek cihazda sandbox satın alma dene.
5. Satın alma sonrası:
   - Ayarlar'da `PRO aktif` görünüyor mu?
   - 11. çalışma eklenebiliyor mu?
   - Hedefler açılıyor mu?
   - PRO saat stili seçilip timer/saatte görünüyor mu?
   - Restore Purchase çalışıyor mu?
   - Aboneliği Yönet satırı Apple abonelik yönetimine gidiyor mu?
6. TestFlight build'i yükle.
7. Aynı senaryoları TestFlight'ta tekrar et.

## 6. App Review İçin Gerekli Dış Bağlantılar

Auto-renewable subscription yayınından önce App Store metadata içinde şunlar bulunmalı:

- Privacy Policy URL
- Terms of Use URL

Standart Apple EULA kullanılacaksa Terms alanında Apple Standard EULA URL'si kullanılabilir. Privacy Policy için Yonder'a ait ayrı bir URL gerekir.

## 7. Yayın Öncesi Son Kontrol

- [ ] App Store Connect product ID'leri kodla birebir aynı.
- [ ] Subscription group oluşturuldu.
- [ ] Monthly/yearly fiyatları seçildi.
- [ ] Ürün lokalizasyonları eklendi.
- [ ] Privacy Policy URL hazır.
- [ ] Terms of Use URL hazır.
- [ ] StoreKit local test geçti.
- [ ] Sandbox gerçek cihaz testi geçti.
- [ ] TestFlight satın alma/restore testi geçti.
- [ ] GoogleService-Info.plist git'e stage edilmedi.
- [ ] Firebase rules deploy edildi.
- [ ] App Store Privacy Nutrition Label dolduruldu.
