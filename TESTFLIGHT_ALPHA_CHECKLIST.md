# Yonder — TestFlight Alpha Checklist

Bu build'in amacı ödeme altyapısı tamamlanmadan uygulamanın genel stabilitesini test etmektir.

## Bu Build'de Test Edilecekler

- Onboarding ve dil seçimi
- Ana ekran yerleşimi
- Odaklan akışı
- Sayaç / kronometre
- Kaydet ekranı
- Çalışmalarım ekleme, silme, yeniden adlandırma
- 10 çalışma limiti ve PRO kilit davranışı
- Rapor ekranı temel metrikleri
- Hedefler ekranı kilit/paywall davranışı
- Hatırlatıcılar ve bildirim izni
- Saat görünümleri ve PRO kilitleri
- Yatay/dikey geçişler
- Tam ekran saatten çıkış
- Online oda oluşturma, katılma, ayrılma, oda bitirme
- Google giriş ve cihazlar arası sync
- Profil fotoğrafı seçici
- Live Activity / Dynamic Island davranışı

## Bu Build'de Tam Test Edilmeyecekler

- Gerçek App Store satın alma
- Gerçek abonelik yenileme/iptal
- Sandbox/TestFlight PRO satın alma
- App Store abonelik ürün fiyatlarının görünmesi

Bu maddeler Paid Apps Agreement, bank account, tax form ve App Store Connect subscription ürünleri tamamlandıktan sonraki TestFlight build'inde test edilecek.

## Test Cihazları

- iPhone 11 gerçek cihaz
- iPad Air 4 gerçek cihaz
- iPhone 17 Pro Simulator
- iPad Pro Simulator

## TestFlight'a Göndermeden Önce

- [ ] Release build başarılı.
- [ ] `GoogleService-Info.plist` git'e stage edilmedi.
- [ ] Firebase rules deploy edildi.
- [ ] Uygulama gerçek cihazda en az bir kez açıldı.
- [ ] Onboarding layout kontrol edildi.
- [ ] Yatay/dikey timer geçişleri kontrol edildi.
- [ ] PRO paywall ürün yokken çökmeden açılıyor.

## Xcode Archive Adımları

1. Xcode'da `Yonder.xcodeproj` aç.
2. Üst cihaz hedefini `Any iOS Device (arm64)` seç.
3. Menüden `Product > Archive`.
4. Archive tamamlanınca Organizer açılır.
5. `Distribute App`.
6. `App Store Connect`.
7. `Upload`.
8. Otomatik imzalamayı kullan.
9. Upload bitince App Store Connect → TestFlight'ta build processing'i bekle.

## App Store Connect TestFlight Adımları

1. App Store Connect → My Apps → `Yonder - Focus App`.
2. TestFlight sekmesine gir.
3. Build processing bitince Internal Testing grubuna ekle.
4. Kendini internal tester olarak ekle.
5. TestFlight uygulamasından build'i indir.

## Alpha Notu

Bu build ödeme tamamlanmadan gönderildiği için PRO ekranında App Store ürünleri hazır değil mesajı görülebilir. Bu beklenen davranıştır.
