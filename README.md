# DukanSpace 📱📦
> Completely offline, ultra-fast Mobile Accessories Inventory Management app tailored for budget Android devices with low RAM.

---

## ⚡ Architectural Highlights (Clean Architecture & Low-RAM Optimizations)

- **MVVM with Provider**: Strict separation between UI, Business Logic (ViewModels), and Data Access (Repositories & Services).
- **Zero UI Freezes**: Large Excel parsing runs off-thread via Dart's background `Isolate.run()`.
- **Low-Footprint SQLite**: Configured with `PRAGMA journal_mode = WAL;`, `PRAGMA synchronous = NORMAL;`, and tuned cache size for maximum performance on slow eMMC storage.
- **B-Tree Database Indexing**: Lookups across `accessory_group_id` and `phone_name` are indexed ($O(\log N)$).
- **Virtualized Views**: All lists use `ListView.builder` to reuse widgets and prevent memory leaks.
- **Material 3 Design**: Clean typography (Google Fonts Inter), rounded corners, generous whitespace, and zero heavy animations.

---

## 📁 Project Structure

```
lib/
├── database/
│   ├── db_provider.dart              # SQLite database configuration & indexed table schemas
│   └── inventory_repository.dart      # SQL queries, batch inserts, upserts & transactions
├── models/
│   ├── inventory_item.dart           # Model for inventory accessories
│   └── phone_model.dart              # Model for phone-to-group mappings
├── services/
│   ├── excel_parser_service.dart     # Isolate-based background .xlsx / .xls parser
│   └── search_service.dart           # Cross-referencing phone models and accessory groups
├── viewmodels/
│   ├── import_viewmodel.dart         # State management for file picking & merge/replace
│   ├── inventory_viewmodel.dart      # State management for stock list, filtering & editing
│   └── search_viewmodel.dart         # Debounced search & compatibility state management
├── views/
│   ├── import_screen.dart            # Excel upload & Merge/Replace confirmation
│   ├── inventory_screen.dart         # Stock management with +/- stepper & add form
│   ├── main_navigation_screen.dart   # Bottom navigation bar
│   └── search_screen.dart            # Fast model lookup showing Shelf, Box, Stock & "Also fits"
└── main.dart                         # MultiProvider setup & Material 3 theme configuration
```

---

## 📊 Database Schema

### 1. `inventory` Table
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique row ID |
| `accessory_group_id` | TEXT | NOT NULL, **INDEXED** | Group code (e.g. `GRP-IP14`) |
| `item_type` | TEXT | NOT NULL | Item category (e.g. `Tempered Glass`, `Clear Case`) |
| `shelf_no` | TEXT | NOT NULL | Store shelf location (e.g. `S-03`) |
| `box_no` | TEXT | NOT NULL | Box or tray identifier (e.g. `B-12`) |
| `stock_count` | INTEGER | NOT NULL DEFAULT 0 | Current quantity in store |

### 2. `phone_models` Table
| Column | Type | Constraints | Description |
|---|---|---|---|
| `phone_name` | TEXT | PRIMARY KEY, **INDEXED** | Phone model name (e.g. `iPhone 13`, `iPhone 14`) |
| `accessory_group_id` | TEXT | NOT NULL, **INDEXED** | Group code matching `inventory` |

---

## 📑 Excel Import Format

Create an `.xlsx` or `.xls` file with the following columns:
- **Column A**: Phone Model Name (e.g. `Redmi Note 12 5G`)
- **Column B**: Accessory Group ID (e.g. `GRP-RN12`)

When importing:
- **Merge (Upsert)**: Adds new models and updates existing ones without deleting unmatched records.
- **Replace All**: Clears existing models table and inserts the freshly parsed catalog.

---

## 🚀 Automated APK Releases via GitHub Actions

Because you are developing on a Mac without Android Studio, this repository comes with `.github/workflows/apk-release.yml`.

### How to Build & Download the APK:
1. Initialize a git repository and commit the code:
   ```bash
   git init
   git add .
   git commit -m "feat: Initial commit for DukanSpace"
   ```
2. Push your project to GitHub:
   ```bash
   git remote add origin https://github.com/<your-username>/dukan-space.git
   git branch -M main
   git push -u origin main
   ```
3. Create and push a version tag (e.g., `v1.0.0`):
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
4. GitHub Actions will automatically:
   - Check out code on `ubuntu-latest`
   - Set up Java 17 Temurin
   - Set up Flutter 3.22.x
   - Run `flutter pub get`
   - Build the release APK (`flutter build apk --release`)
   - Create a GitHub Release and attach `app-release.apk` ready to download directly onto any Android phone!

