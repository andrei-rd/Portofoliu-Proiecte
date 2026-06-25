# 🅿️ Parkly

> **RO:** Parchează repede și ieftin — platformă marketplace pentru găsirea și rezervarea instantanee a locurilor de parcare.
> **EN:** Park fast and cheap — a marketplace platform for instant finding and booking of parking spots.

[![pipeline status](https://gitlab.com/parklyteam/parkly/badges/main/pipeline.svg)](https://gitlab.com/parklyteam/parkly/-/pipelines)
[![coverage report](https://gitlab.com/parklyteam/parkly/badges/main/coverage.svg)](https://gitlab.com/parklyteam/parkly/-/jobs)
[![Flutter](https://img.shields.io/badge/Flutter-3.5%2B-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Backend-FFCA28?logo=firebase)](https://firebase.google.com)

**Languages / Limbi:** [🇷🇴 Română](#-română) · [🇬🇧 English](#-english)

---

## 🇷🇴 Română

### 📱 Despre & Viziune
Parkly este "Airbnb-ul locurilor de parcare". Este o soluție multi-platformă care digitalizează activele imobiliare subutilizate (parcări private, curți, garaje), oferind șoferilor o experiență de rezervare fără stres, bazată pe geolocație și date în timp real.

### ✨ Funcționalități Avansate

- 🔐 **Securitate de Top** — Autentificare prin Telefon (OTP), Google și Email. Protecție prin Firebase App Check.
- 💳 **Portofel Virtual** — Sistem de plată închis, transferuri P2P între utilizatori și alimentare securizată.
- 📈 **Dynamic Pricing Engine** — Ajustare automată a prețului:
    - *Surge Pricing* (ore de vârf/evenimente).
    - *Discounts* (noapte, weekend sau perioade lungi).
- 🧾 **Facturare Automată** — Generare instantanee de facturi PDF fiscale pentru fiecare rezervare.
- 🚨 **Incident Management** — Protocol de raportare a locurilor ocupate abuziv cu dovadă foto și arbitraj admin.
- 🗺️ **Hartă Interactivă** — Clusterizare inteligentă, status live (Liber/Ocupat/Mentenanță) și navigare externă (Waze/Google Maps).
- 🛠️ **Panou Admin/Owner** — Gestionare orar săptămânal, vizualizare încasări și moderare locuri.

### 🏗️ Stack Tehnic Actualizat

| Categorie | Tehnologie |
|-----------|------------|
| Framework | Flutter 3.5+ / Dart (Null-Safety) |
| Backend | Firebase (Firestore + Auth + Messaging + Storage) |
| Analytics | Firebase Crashlytics |
| Securitate | Firebase App Check (Play Integrity) |
| Hartă | `google_maps_flutter` + `geolocator` |
| Documente | `pdf` + `printing` |

### 📁 Structura Proiectului (Scurtătura)

```
lib/
├── models/           # Logică de date (ParkingSpace, Reservation)
├── services/         # Motoarele: Auth, Parking, Invoice, Wallet, Config (Dynamic Pricing)
├── screens/          # Interfață: Map, Wallet, Admin, Dashboard, Incident Report
└── widgets/          # Componente UI reutilizabile (ParkingCard)
```

---

## 🇬🇧 English

### 📱 About & Vision
Parkly is the "Airbnb of parking spots". It is a cross-platform solution that digitalizes underutilized real estate assets (private parking, yards, garages), providing drivers with a stress-free booking experience based on geolocation and real-time data.

### ✨ Advanced Features

- 🔐 **Top-Tier Security** — Phone Auth (OTP), Google, and Email. Protection via Firebase App Check.
- 💳 **Virtual Wallet** — Closed-loop payment system, P2P transfers, and secure top-ups.
- 📈 **Dynamic Pricing Engine** — Automated price adjustments:
    - *Surge Pricing* (peak hours/events).
    - *Discounts* (night, weekend, or long-stay).
- 🧾 **Automated Invoicing** — Instant fiscal PDF invoice generation for every reservation.
- 🚨 **Incident Management** — Protocol for reporting occupied spots with photo evidence and admin arbitration.
- 🗺️ **Interactive Map** — Smart clustering, live status (Free/Occupied/Maintenance), and external navigation (Waze/Google Maps).
- 🛠️ **Admin/Owner Panel** — Weekly schedule management, earnings visualization, and spot moderation.

### 🏗️ Updated Tech Stack

| Category | Technology |
|----------|------------|
| Framework | Flutter 3.5+ / Dart (Null-Safety) |
| Backend | Firebase (Firestore + Auth + Messaging + Storage) |
| Analytics | Firebase Crashlytics |
| Security | Firebase App Check (Play Integrity) |
| Maps | `google_maps_flutter` + `geolocator` |
| Documents | `pdf` + `printing` |

### 🔄 CI/CD & Production Ready
Our GitLab pipeline ensures that every commit is **Production-Ready**:
- **Validate:** Static analysis & formatting check.
- **Test:** Unit & Widget tests with coverage report.
- **Build:** Automated APK & Web artifact generation.

### 🤝 Contributing & Conventions
- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `chore:`, `docs:`).
- **Branching:** `feature/` or `fix/` branches only. Merging to `master` requires a Merge Request (MR) and passing CI.

---

## 👥 Team / Echipă

Developed by **Hexacore** (ParklyTeam):

- Turtea George Alex
- Andrei Roba
- Radu Bogdan
- Stefan Trimbitas
- Vacaru Julia
- Talenus Valentina

## 📄 License / Licență

Proprietary project — Hexacore / ParklyTeam. All rights reserved.
