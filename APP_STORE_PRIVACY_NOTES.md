# Yonder — App Store Privacy & Permission Notes

Bu döküman Yonder'ın App Store yayın hazırlığında geliştiriciye rehber olmak üzere hazırlanmıştır.

---

## 1. Kullanılan İzinler (Permissions)

### Fotoğraf Kitaplığı (Photo Library)
- **Plist key**: `NSPhotoLibraryUsageDescription` ✅ eklendi
- **Değer**: "Profil fotoğrafını seçmek için fotoğraf kitaplığına erişim gerekir."
- **Kullanım yeri**: `ProfileEditSheet.swift` → `PhotosPicker`
- **Not**: SwiftUI PhotosPicker (iOS 16+) sistem UI'ı üzerinden çalışır; tam kütüphane erişimi gerektirmez. Ancak App Review için key bulundurulması önerilir.

### Bildirimler (Notifications)
- **Sistem diyaloğu**: Kullanıcı ilk hatırlatıcıyı oluşturduğunda `NotificationService.requestAuthorization()` çağrılır.
- **İzin tipi**: `.alert`, `.sound`, `.badge`
- **Plist key**: iOS'ta bildirimler için ayrı usage key gerekmez; sistem diyaloğu otomatik yönetilir.

### Live Activities
- **Plist key**: `NSSupportsLiveActivities = true` ✅ mevcut
- **Kullanım**: `LiveActivityService.swift` — timer başlayınca Dynamic Island / Lock Screen güncellenir.

### In-App Purchase / Yonder PRO
- **Kullanım**: `ProStore.swift` — StoreKit 2 ile monthly/yearly auto-renewable subscription.
- **Product ID'ler**:
  - `com.emir.Yonder.pro.monthly`
  - `com.emir.Yonder.pro.yearly`
- **Ödeme bilgisi**: Apple tarafından işlenir. Yonder kart bilgisi toplamaz veya saklamaz.

### Reklamlar / Google AdMob
- **SDK**: Google Mobile Ads SDK (`GoogleMobileAds`) + Google User Messaging Platform (`UserMessagingPlatform`)
- **Kullanım yeri**: `AdMobService.swift` — free kullanıcıda sayaç, kronometre ve online oda çıkışlarında interstitial reklam; PRO kullanıcıda reklam çağrısı yapılmaz.
- **Geçerli geliştirme ID'leri**: `GADApplicationIdentifier` (`ca-app-pub-5731421075090925~7511238594`) ve `YonderInterstitialAdUnitID` (`ca-app-pub-5731421075090925/1652356923`) gerçek AdMob değerleriyle güncellendi.
- **Test davranışı**: DEBUG build'leri interstitial için Google sample ad unit ID'sini kullanır; Release build `YonderInterstitialAdUnitID` değerini kullanır.
- **Canlıya almadan önce**: AdMob Privacy & messaging içinde UMP (GDPR/US states) mesajı oluşturulup yayınlanmalı; `website/app-ads.txt` Firebase Hosting'e deploy edildi, AdMob'da uygulama doğrulamasının tamamlandığı teyit edilmeli; AdMob'da ödeme ayarları tamamlanmalı.
- **PRO etkisi**: `is_premium_user = true` olduğunda reklam gösterilmez.
- **ATT kararı**: Şimdilik `NSUserTrackingUsageDescription` ve AppTrackingTransparency prompt'u eklenmedi. İlk reklam sürümü contextual/non-personalized ağırlıklı gidecek; IDFA bazlı kişiselleştirilmiş reklam istenirse ayrıca ATT akışı eklenmeli.
- **SKAdNetwork**: `Info.plist` Google'ın güncel AdMob quick-start listesindeki 50 `SKAdNetworkIdentifier` değerini içerir.

---

## 2. Toplanan Veri Türleri (App Store Privacy Nutrition Label)

### Kullanıcı Kimliği
| Veri | Kullanım | Kullanıcıyla İlişkilendirilir mi |
|------|----------|----------------------------------|
| Firebase UID (anonim veya Google) | Oturum senkronizasyonu | Hayır (anonim) / Evet (Google) |
| Google e-posta | Hesap bağlantısı | Evet |
| Özel görünen ad | Sessiz odalarda kimlik | Evet |

### Kullanım Verileri
| Veri | Bulut'a gönderilir mi |
|------|----------------------|
| Odak oturumu süresi | Evet (Google hesabı varsa) |
| Oturum tarihi/saati | Evet |
| Konu/niyet metni | Evet |
| Planlanan süre | Evet |
| Oda katılım bilgisi | Evet |

### Odak Odası (Quiet Rooms) — Firestore'da Tutulan Veri
- Oda kodu, hostId, katılımcı görünen adı, durum (studying/break), konu, süre, zaman damgaları

---

## 3. App Store Privacy Form Rehberi

**"Data Used to Track You"** → Reklam stratejisine göre yeniden değerlendir. AdMob kişiselleştirilmiş reklam/IDFA/çapraz uygulama takip kullanacaksa "Evet" olabilir. Sadece rıza kontrollü, kişiselleştirilmemiş/bağlamsal reklam kullanılacaksa App Store Connect ve Google AdMob ayarlarına göre doğrula.

**"Data Linked to You"** → Evet (Google hesabı bağlıysa): kullanıcı adı, e-posta, odak geçmişi.

**"Data Not Linked to You"** → Evet (anonim kullanımda): anonim Firebase UID ile oturum verisi.

### Veri Kategorileri (App Store Connect → Privacy → Data Types)
| Kategori | Alt kategori | Durum |
|----------|--------------|-------|
| Contact Info | Email Address | Google bağlantısı kurulursa |
| Identifiers | User ID | Evet |
| Usage Data | Product Interaction | Evet |
| Usage Data | Other Usage Data | Evet (odak süreleri) |
| Purchases | Purchase History | Apple yönetir; uygulama yalnızca PRO entitlement durumunu okur |
| Identifiers | Device ID / Advertising ID | AdMob yapılandırmasına ve ATT/consent ayarlarına göre değerlendir |
| Location | Coarse Location | AdMob reklam ölçümü/hedeflemesi için Google tarafından işlenebilir; AdMob ayarlarına göre doğrula |
| Diagnostics | Crash / Performance Data | Google Mobile Ads SDK privacy manifest ve App Store Connect formuna göre doğrula |

---

## 4. Entitlement Durumu

| Entitlement | Durum |
|-------------|-------|
| `com.apple.security.application-groups` | ✅ Yonder.entitlements'ta mevcut (WidgetKit) |
| `NSSupportsLiveActivities` | ✅ Info.plist'te mevcut |
| `aps-environment` (Remote Push) | ❌ Yok — sadece local notifications kullanılıyor |

---

## 5. GoogleService-Info.plist Durumu

- Dosya konumu: `/Yonder/GoogleService-Info.plist` ✅ disk üzerinde mevcut
- Build süreci başarıyla tamamlanıyor ✅
- `.gitignore`'a eklendi ve şu an git tarafından takip edilmiyor ✅
- **ÇÖZÜLDÜ**: Dosya `73342ee` ("Initial commit") commit'inde bir süre track edilmiş ve `origin/main`'e push edilmiş durumdaydı. Repo tek bir temiz "Initial commit" ile yeniden yazılıp force-push edildi (2026-08-17); dosya artık git geçmişinin hiçbir yerinde yok, `.gitignore` ile takip dışı bırakıldı.

---

## 6. Kalan Belirsizlikler / Dikkat Edilecekler

- **NSPhotoLibraryUsageDescription lokalizasyonu**: EN ve TR ikisi de `InfoPlist.xcstrings`'te mevcut ✅ (bu notun eski hali yanlıştı).
- **Bildirim öncesi açıklama**: Kullanıcı hatırlatıcı eklemeden önce opsiyonel bir ön bilgi mesajı eklenebilir.
- **SyncService**: Anonim kullanıcılar için Firestore yazımı yapılmıyor — güvenli mimari ✅.
- **Hesap/veri silme akışı TAMAMLANDI**: Ayarlar ekranında bağlı hesaplar için "TEHLİKELİ ALAN / DANGER ZONE" altında iki aşamalı onay ve "SİL"/"DELETE" doğrulama kelimeli hesap ve veri silme akışı eklendi (`AccountDeletionService.swift`). Apple Guideline 5.1.1(v) uyumu sağlandı ✅.
- **Hesap değişimi veri sızıntısı düzeltildi**: Daha önce `signOut()` sonrası local SwiftData (sessions/subjects) ve `WorkGoalStore` temizlenmiyordu; aynı cihazda farklı bir hesapla giriş yapıldığında önceki kullanıcının verileri "bu cihazın verilerini hesaba ekle" akışıyla yeni kullanıcının Firestore hesabına yüklenebiliyordu. `ContentView.swift` içinde sign-out sonrası local cache temizliği eklendi (bkz. güvenlik denetimi raporu, P0-1).
- **`rooms` koleksiyonu enumeration**: Firestore rules'ta `allow read` yerine `allow get` kullanılarak oda koleksiyonunun toplu sorgulanması (aktif oda kodu/host/subject toplama) engellendi.

---

## 7. Hızlı Kontrol Listesi (App Store Gönderimi Öncesi)

- [x] NSPhotoLibraryUsageDescription → Info.plist'e eklendi
- [x] NSSupportsLiveActivities → Info.plist'te mevcut
- [x] com.apple.security.application-groups → entitlements'ta mevcut
- [x] Google Sign-In URL scheme → Info.plist'te kayıtlı
- [x] Firebase raw hata mesajları UI'da görünmüyor (SignInView düzeltildi)
- [ ] GoogleService-Info.plist → .gitignore kontrolü
- [ ] NSPhotoLibraryUsageDescription EN çevirisi → InfoPlist.xcstrings
- [ ] App Store Connect Privacy Nutrition Label formu doldur
- [x] Privacy Policy URL hazırla
- [x] Terms of Use URL hazırla veya Apple Standard EULA kullan
- [ ] App Store Connect'te Yonder PRO subscription group + monthly/yearly ürünlerini oluştur
- [ ] Sandbox/TestFlight satın alma ve restore testi yap
- [ ] TestFlight gerçek cihaz testi: bildirim izni + fotoğraf seçici
- [x] AdMob gerçek App ID + Interstitial Ad Unit ID değerlerini Info.plist'e gir
- [x] `website/app-ads.txt` Firebase Hosting'e deploy et
- [ ] App Store Connect 1.0.1 Marketing URL alanına `https://yonderfocusapp.com` girip kaydet
- [ ] App Store Connect Support URL alanını `https://yonderfocusapp.com` veya support/contact sayfasına taşı
- [ ] AdMob Privacy & messaging içinde UMP consent mesajını oluştur ve EEA/UK/CH testini yap
- [ ] App Store Connect Privacy Nutrition Label'ı AdMob veri kullanımıyla güncelle
- [ ] Kişiselleştirilmiş reklam hedeflenirse ATT prompt metni ve AppTrackingTransparency akışını ekle
