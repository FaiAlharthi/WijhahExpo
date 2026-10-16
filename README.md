# وجهة · Wijhah — Expo 2030 Riyadh Companion

رفيقك في إكسبو 2030 الرياض: خطة ليومك بالذكاء الاصطناعي، خريطة واضحة، جواز تجمع فيه طوابع الدول، ومجموعات تزورون فيها الإكسبو سوا.

A visitor companion app for Expo 2030 Riyadh — an AI‑planned day, a clear site map, a passport of country stamps, reviews, a live crowd layer, an assistant chatbot, and group visits.

---

## 🗂️ Structure (Monorepo)

```
WijhahExpo/
├── frontend/WijhaApp/   # iOS app — SwiftUI
└── backend/             # REST API — Spring Boot (Java)
```

> The backend here is a snapshot. Its full commit history lives in the separate **ExpoProject** repository.

---

## ✨ Features

- **Smart day plans (Roadmaps):** AI builds a route from your interests, time and pace, ordered on the shortest walk, with prayer/meal/rest breaks.
- **Site map:** illustrated and photo styles, live route playback, directions, zones, gates — accessibility‑aware (step‑free routing).
- **Passport & stamps:** a country stamp per pavilion, repeated stamps for repeated visits, visit history.
- **Reviews & crowd:** rate pavilions, see the expected queue, and get WhatsApp alerts when a crowded pavilion calms down.
- **AI assistant:** a RAG chatbot answering about the expo, replying in the question's own language.
- **Find a group:** publish your plan, browse same‑day plans ranked by shared interests, send a join request, and coordinate on WhatsApp.

---

## 🧰 Tech stack

**Backend** — Java 17 · Spring Boot 4.1.1 · Spring Security · Spring Data JPA · MySQL · Thymeleaf + OpenHTMLtoPDF (journey PDF) · Google Gemini (RAG chat + embeddings) · UltraMsg (WhatsApp).

**Frontend** — SwiftUI (iOS 17+) · Xcode.

---

## 🚀 Backend setup (`backend/`)

**Requirements:** JDK 17, MySQL, Maven (the included `./mvnw` wrapper works too).

1. **Create the database**
   ```sql
   CREATE DATABASE Expo_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```
   Tables are created automatically on first run (`spring.jpa.hibernate.ddl-auto=update`).

2. **Add your secrets** in `backend/src/main/resources/application-local.properties` (git‑ignored — not pushed):
   ```properties
   spring.datasource.password=YOUR_MYSQL_PASSWORD
   ai.api.key=YOUR_GEMINI_API_KEY
   ultramsg.instance-id=YOUR_ULTRAMSG_INSTANCE
   ultramsg.token=YOUR_ULTRAMSG_TOKEN
   ```
   Default DB user is `root` on `localhost:3306` (change in `application.properties` if needed).

3. **Run**
   ```bash
   cd backend
   ./mvnw spring-boot:run
   ```
   The API starts on **`http://localhost:8080`**, base path **`/api/v1`**.

---

## 📱 Frontend setup (`frontend/WijhaApp/`)

**Requirements:** Xcode (iOS 17+).

1. Open `frontend/WijhaApp/Wijha.xcodeproj` in Xcode.
2. Make sure the API address matches your backend — in `Wijha/Core/APIClient.swift`:
   ```swift
   var baseURL: String = "http://localhost:8080"
   ```
3. Run on a simulator or device (⌘R).

> Run the backend first so the app has data to load.

---

## 🔐 Notes

- `application-local.properties`, `target/`, Xcode `DerivedData/` and `.DS_Store` are git‑ignored.
- Never commit API keys or database passwords — keep them in `application-local.properties` only.

---

**Tuwaiq Academy — Expo 2030 Riyadh challenge.**
