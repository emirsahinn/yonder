# Yonder — Firestore Schema Documentation

Bu döküman Yonder uygulamasının Firebase Firestore veri şemasını,
hangi servisin hangi collection'ı okuduğunu/yazdığını ve
güvenlik kuralları için dikkat edilmesi gereken noktaları belgeler.

---

## Collection Haritası

```
firestore
├── users/
│   └── {uid}/
│       ├── sessions/
│       │   └── {sessionId}   ← SyncService tarafından yönetilir (iki yönlü)
│       ├── subjects/
│       │   └── {subjectId}   ← SyncService tarafından yönetilir (iki yönlü)
│       └── goals/
│           └── {goalId}      ← SyncService tarafından yönetilir (iki yönlü)
│
└── rooms/
    └── {code}                ← RoomService tarafından yönetilir
        └── participants/
            └── {uid}         ← RoomService tarafından yönetilir
```

---

## 1. `users/{uid}/sessions/{sessionId}`

### Açıklama
Tamamlanmış odak oturumlarının Firestore yedekleri. Yalnızca Google hesabı bağlı kullanıcılar için yazılır.

### Yazar: `SyncService`
- `syncSession(_:)` — tek oturum yazma
- `backfillSessions(_:)` — hesap bağlantısı sonrası toplu yükleme
- `deleteSession(_:)` — oturum silme

### Okuyucu
Şu an yalnızca Firebase Console (geliştirici). Uygulamada okuma endpoint'i yok.

### Field Şeması

| Field | Tip | Açıklama | Örnek |
|-------|-----|----------|-------|
| `id` | String (UUID) | Yerel SwiftData ID'si | `"7F3A..."` |
| `date` | Timestamp | Oturum başlangıç tarihi | |
| `durationSeconds` | Number (Int) | Gerçekleşen odak süresi | `1500` |
| `completed` | Boolean | Oturum tamamlandı mı | `true` |
| `intentionNote` | String | Kullanıcının niyet notu | `"Matematik"` |
| `subject` | String | Konu/çalışma alanı adı | `"Matematik"` |
| `mode` | String | `"solo"` veya `"room"` | `"solo"` |
| `startedAt` | Timestamp? | Null olabilir | |
| `endedAt` | Timestamp? | Null olabilir | |
| `plannedDurationSeconds` | Number? | Null olabilir | `1500` |
| `roomId` | String? | Oda ID'si, sadece room modda | `"AB4K9Z"` |
| `syncedAt` | ServerTimestamp | Firestore'a yazılma zamanı | |

### Privacy Notu
- `intentionNote` ve `subject` alanları serbest metin içerir; kullanıcının kendi yazdığı içerik.
- Bu alanlar yalnızca `uid` sahip kullanıcı tarafından okunabilmeli.

---

## 2. `rooms/{code}`

### Açıklama
Aktif sessiz odaların meta verisi. Oda kodu (`code`) hem document ID hem de join kodu.

### Yazar: `RoomService`
- `createRoom()` — yeni oda yazar
- `startRoom()` — `status: waiting → running`, `endTimestamp` ekler (transaction)
- `endRoom()` — `status: running → ended` (transaction, idempotent)

### Okuyucu: `RoomService`
- `joinRoom()` — oda snapshot okur (status kontrolü)
- `listenToRoom()` — real-time listener

### Field Şeması

| Field | Tip | Açıklama | Değerler |
|-------|-----|----------|---------|
| `hostId` | String (Firebase UID) | Odayı açan kullanıcı | |
| `duration` | Number (Int, saniye) | Oturum süresi | `900..7200` |
| `status` | String | Oda durumu | `"waiting"` / `"running"` / `"ended"` |
| `subject` | String | Odanın konusu (opsiyonel) | `""` veya konu adı |
| `createdAt` | Timestamp | Oda oluşturulma zamanı | |
| `endTimestamp` | Timestamp? | startRoom sonrası eklenir | |
| `endedAt` | Timestamp? | endRoom sonrası eklenir (erken bitiş / bitiş anı) | |

### Privacy Notu
- `subject` field'ı tüm katılımcılar tarafından okunabilir.
- Bu tasarımsal bir karar; gizlilik kaygısı yoksa sorun değil.

### Kod Güvenliği
- Charset: `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (32 karakter, karışıklık veren I/O/0/1 hariç)
- Uzunluk: 6 karakter → 32^6 = ~1 milyar kombinasyon
- Collision retry: 8 deneme (`uniqueRoomCode()`)
- **Risk**: Kaba kuvvet (brute force) saldırısıyla aktif oda kodları tahmin edilebilir.
  - Şu an için MVP düzeyinde kabul edilebilir risk.
  - Öneri: Firestore'da rate limiting (Security Rules içinde `request.time`) veya server-side validation.

---

## 3. `rooms/{code}/participants/{uid}`

### Açıklama
Bir odadaki katılımcıların anlık durumu.

### Yazar/Okuyucu: `RoomService`
- `joinRoom()` — participant doc yazar
- `updateMyStatus()` — sadece `status` field'ı günceller
- `updateMyReadyState()` — sadece `ready` field'ı günceller
- `leaveRoom()` — kendi participant doc'unu siler
- `listenToParticipants()` — real-time collection listener

### Field Şeması

| Field | Tip | Açıklama | Değerler |
|-------|-----|----------|---------|
| `displayName` | String | Kullanıcının görünen adı | |
| `status` | String | Anlık durum | `"studying"` / `"break"` / `"left"` |
| `ready` | Boolean | Lobby'de hazır mı | `true` / `false` |
| `joinedAt` | Timestamp | Odaya katılma zamanı | |
| `workItemName` | String? | Katılımcının çalıştığı alan adı (max 100 char) | `"Matematik"` |
| `workItemId` | String? | Katılımcının çalıştığı alan ID'si (opsiyonel) | |
| `workItemUpdatedAt` | Timestamp? | Çalışma alanının son güncellenme zamanı | |
| `activeSeconds` | Number (Int) | Katılımcının toplam aktif çalışma süresi (saniye) | `1800` |
| `breakSeconds` | Number (Int) | Katılımcının toplam mola süresi (saniye) | `300` |
| `lastStatusChangedAt` | Timestamp? | Durumun son değiştiği an | |
| `leftAt` | Timestamp? | Odadan ayrılma zamanı (opsiyonel) | |
| `finalizedActiveSeconds` | Number? | Bitişte dondurulmuş aktif çalışma süresi (opsiyonel) | |
| `finalizedBreakSeconds` | Number? | Bitişte dondurulmuş mola süresi (opsiyonel) | |

### Privacy Notu
- `displayName` yalnızca aynı odanın katılımcıları tarafından görülebilir.
- Oda dışındaki authenticated kullanıcılar `participants` alt koleksiyonunu okuyamaz.
- Kullanıcı bu ismi `ProfileEditSheet`'te kendisi belirler.

---

## 4. Servis → Collection Erişim Matrisi

| Servis | Collection | İşlem |
|--------|-----------|-------|
| `SyncService` | `users/{uid}/sessions` | write, delete |
| `SyncService` | `users/{uid}/subjects` | read, write, delete |
| `SyncService` | `users/{uid}/goals` | read, write, delete |
| `AccountDeletionService` | `users/{uid}` ve tüm subcollection'lar | delete |
| `AccountDeletionService` | `rooms/{code}/participants` | collectionGroup read/delete (yalnızca kendi participant doc'u) |
| `AccountDeletionService` | `rooms` (hostId == uid) | list/update (status=ended) |
| `RoomService` | `rooms` | get, create, update, delete |
| `RoomService` | `rooms/{code}/participants` | read (oda üyeleri), write, delete |
| `RoomTimerView` | (RoomService üzerinden) | — |

---

## 5. Tespit Edilen Uyumsuzluk: `endRoom` Yetki Kontrolü

### Mevcut Durum
- `RoomTimerView.endRoomIfNeeded()` → timer `0`'a düştüğünde **tüm client'lar** `RoomService.endRoom()` çağırır.
- `RoomService.endRoom()` — authentication kontrolü içermez; her authenticated kullanıcı çağırabilir.
- Transaction ile idempotent yapılmış (`currentStatus != "ended"` guard'ı var) — bu doğru.

### Rules Çatışması
Eğer security rules `endRoom` yazımını yalnızca `hostId == request.auth.uid` ile kısıtlarsak:
- Non-host katılımcılar `endRoom` çağırdığında rules redder → `try?` olduğu için sessiz başarısız olur.
- Host zaten çağıracağı için pratikte oda yine `ended` olur.
- **Önerilen rule stratejisi**: `ended` durumuna geçişe sadece host ya da `endTimestamp < request.time` koşuluyla izin ver.

### Küçük Güvenli Düzeltme Önerisi (kod değişikliği yapmadan)
Rules'ta şu logic kullanılabilir:
```
// status "ended" güncellemesine izin ver:
// a) Caller host ise, VEYA
// b) Mevcut status "running" ve endTimestamp geçmiş ise (timer dolmuş)
```
Bu sayede non-host client'lar sadece süre dolduğunda `ended` yapabilir.
