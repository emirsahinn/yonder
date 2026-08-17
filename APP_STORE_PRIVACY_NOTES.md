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

**"Data Used to Track You"** → Hayır. Yonder üçüncü taraf reklam ağlarıyla veri paylaşmaz.

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
- **DİKKAT**: Dosya `73342ee` ("Initial commit") commit'inde bir süre track edilmiş ve `origin/main`'e (github.com/emirsahinn/yonder) push edilmiş durumda. Git geçmişinde hâlâ mevcut — repo public ise `API_KEY`, `CLIENT_ID`, `REVERSED_CLIENT_ID`, `GOOGLE_APP_ID`, `PROJECT_ID`, `STORAGE_BUCKET` değerleri erişilebilir. Repo görünürlüğünü kontrol edin; public ise ya private'a alın ya da `git filter-repo`/BFG ile geçmişten temizleyip force-push yapmayı ve Firebase Console'da API key'i bundle ID kısıtlamasıyla sınırlamayı değerlendirin.

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
- [ ] Privacy Policy URL hazırla ve App Store Connect metadata'ya ekle
- [ ] Terms of Use URL hazırla veya Apple Standard EULA kullan
- [ ] App Store Connect'te Yonder PRO subscription group + monthly/yearly ürünlerini oluştur
- [ ] Sandbox/TestFlight satın alma ve restore testi yap
- [ ] TestFlight gerçek cihaz testi: bildirim izni + fotoğraf seçici
