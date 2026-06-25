### 🛠️ Production-Grade Stack
* **Frontend & Cross-Platform:** `Flutter 3.5+` / `Dart` (Full Null-Safety)
* **Backend & Serverless:** `Firebase Cloud Functions` (Node.js orchestration)
* **Real-time Database:** `Firebase Firestore` (NoSQL Document architecture with `<200ms` sync propagation)
* **Security & Integrity:** `Firebase App Check` (Play Integrity), advanced Firestore Rules
* **Geospatial Engines:** `Maps_flutter` + `geolocator` with smart clustering
* **Fiscal Infrastructure:** `pdf` + `printing` automated serverless billing engine

---

## 📂 Repository Structure & Modules

### 1. [📱 Parkly App](./app)
The flagship consumer application. It acts as the "Airbnb for parking spaces," allowing automated, location-based spot matching, reservation routing, and frictionless digital transactions.
* **Advanced Features:** Secure Phone OTP/Google Auth, live dynamic map navigation (Waze/Google Maps integration), and photo-verified dispute/incident management.

### 2. [📊 Admin Dashboard](./admin-dashboard)
The enterprise command center. Designed for full-scale operational oversight, platform health tracking, and precise financial auditing.
* **Advanced Features:** Live Asset Monitors, automated **Low-Rating Audits** (auto-suspends poor spots), Cryptographic Audit Logging, and a Romanian-compliant fiscal PDF engine (**CIF: RO48291022**).

---

## 🛡️ Enterprise Engineering Standards

* **Robust CI/CD Pipelines:** Automated GitLab orchestrations executing strict static analysis (`Validate`), Unit & Widget testing (`Test`), and continuous deployment builds (`Build` for APK & Web artifacts).
* **Production Conventions:** Adherence to **Conventional Commits** (`feat:`, `fix:`, `chore:`, `docs:`) and isolated feature-branching strategies requiring mandatory green pipelines prior to main branch merging.

---

## 👥 Hexacore Engineering Team

Behind Parkly is **Team Hexacore**, an agile team managing full-stack mobile development, system security, and cloud architecture:

* 🚀 **Turtea George Alex**
* 💻 **Andrei Roba**
* 📊 **Radu Bogdan**
* 🛠️ **Stefan Trimbitas**
* 🎨 **Vacaru Julia**
* 🛡️ **Talenus Valentina**

---

### 🚀 Getting Started
Each subsystem contains dedicated environment setup guides. Navigate to either `/app` or `/admin-dashboard` to view detailed configuration steps for local development, Firebase initialization, and Flutter environment dependencies.
"""

with open("README_root.md", "w", encoding="utf-8") as f:
    f.write(readme_content)
print("File generated successfully.")