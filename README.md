# Online Bookstore — Full Stack (Flutter + PHP + MySQL)

This project has two parts:

```
bookstore/
├── backend/          PHP REST API + MySQL schema
└── flutter_app/       Flutter mobile app (import this folder into Android Studio)
```

## 1. Set up the backend

1. Install **XAMPP** (or WAMP/MAMP) and start **Apache** + **MySQL**.
2. Copy the `backend/` folder into your web root, e.g.
   `C:\xampp\htdocs\bookstore\backend` (Windows) or `/Applications/XAMPP/htdocs/bookstore/backend` (Mac).
3. Open **phpMyAdmin** → *Import* → select `backend/schema.sql`. This creates
   the `bookstore_db` database, all tables, and seed data (5 sample books, 3 demo users).
4. **Important:** the bcrypt password hashes in `schema.sql` are placeholders.
   Run `backend/generate_hash.php` once (open it in a browser, e.g.
   `http://localhost/bookstore/backend/generate_hash.php`) and execute the
   `UPDATE` statements it prints in phpMyAdmin's SQL tab. This sets the demo
   accounts' password to `Password123`.
5. Check `backend/config/db.php` — default credentials (`root` / no password,
   database `bookstore_db`) match a stock XAMPP install. Edit if yours differs.
6. Test it works by visiting `http://localhost/bookstore/backend/api/books.php`
   in a browser — you should see a JSON list of books.

### Demo accounts (after step 4)
| Role  | Email | Password |
|---|---|---|
| Administrator | admin@bookstore.com | Password123 |
| Store Staff   | staff@bookstore.com | Password123 |
| Customer      | jane@bookstore.com  | Password123 |

## 2. Open the app in Android Studio

1. Android Studio → **Open** → select the `flutter_app` folder (not `bookstore`).
2. Let Gradle sync. If prompted, install the Flutter/Dart plugins
   (Settings → Plugins → search "Flutter", which pulls in "Dart" too).
3. `android/local.properties` has placeholder SDK paths — Android Studio
   usually rewrites this automatically on first sync. If not, edit it to
   point at your Android SDK and Flutter SDK install locations.
4. In a terminal at the `flutter_app` root, run `flutter pub get`.
5. Check `lib/services/api_service.dart` — `baseUrl` defaults to
   `http://10.0.2.2/bookstore/backend/api`, which is correct **for the
   Android emulator only** (10.0.2.2 = your host machine's localhost from
   inside the emulator). If you're using a physical device on the same
   Wi-Fi, change it to `http://<your-computer's-LAN-IP>/bookstore/backend/api`.
6. Run the app (▶ in Android Studio, or `flutter run`).

## 3. How the three roles map to the brief

| Requirement | Where it lives |
|---|---|
| Browse/search books, view details | `screens/customer/book_list_screen.dart`, `book_detail_screen.dart` |
| Cart + place orders | `screens/customer/cart_screen.dart`, `checkout_screen.dart` |
| API-based backend, data validation | every file in `backend/api/`, both server-side (PHP) and client-side (Flutter `Form` validators) |
| Customer role | `screens/customer/` — browse, cart, checkout, own order history |
| Store Staff role | `screens/staff/` — manage catalogue (add/edit books, restock), process orders (advance status). Cannot delete books or manage accounts. |
| Administrator role | `screens/admin/` — everything Staff can do, **plus** delete books and manage user accounts/roles (`manage_users_screen.dart`) |
| Role-specific permissions | Enforced in **two places** (worth mentioning in your report): the Flutter UI only shows relevant screens/buttons per role (`HomeRouter`, the `isAdmin` check in `manage_books_screen.dart`), and the PHP backend re-checks the role server-side on every request via `requireRole()` in `config/helpers.php` — so the enforcement isn't just cosmetic. |

## 4. Notes for your written report

This section is scaffolding to help you write your own critical analysis —
the actual comparison/reflection/evaluation should be in your words based on
what you observe running and testing the app.

**OS & web technology comparison** — things this build actually demonstrates
that you can compare/contrast: Flutter (cross-platform, single Dart codebase,
compiles to native ARM code) vs. native Android (Kotlin/Java, Android SDK
only) vs. a pure web app (would need a responsive framework, no offline
shell, relies on a browser). This app talks to the backend over a REST API
using `http` + `dart:convert` (JSON), authenticated with a bearer token
stored via `shared_preferences` — compare that to session-cookie auth in a
traditional server-rendered web app.

**Design & implementation** — Provider is used for state management
(`AuthProvider`, `CartProvider`); the bottom-navigation shell pattern per
role; server-side prepared statements (`mysqli` bind_param) preventing SQL
injection; client-side `Form`/`TextFormField` validators plus server-side
validation in every PHP endpoint (defense in depth — mention both layers).

**Cloud deployment** — discuss what would change if `backend/` were deployed
to something like AWS (EC2 + RDS MySQL, or Elastic Beanstalk), a managed PHP
host, or a serverless rewrite. Talk about: HTTPS/TLS (this build defaults to
cleartext HTTP for local dev — see `network_security_config.xml` — a real
deployment must use HTTPS and you'd remove that cleartext exception),
horizontal scaling of the API tier, managed database backups/replication,
and cost/latency trade-offs.

**Reflection/challenges** — genuine candidates from this codebase: keeping
role permissions consistent across both the Flutter UI and the PHP API;
handling stock-level race conditions at checkout (this build validates stock
inside a MySQL transaction in `orders.php` before committing); token
expiry/session handling with no refresh-token flow (a real improvement:
add JWT refresh tokens); offline support is not implemented — the app
requires connectivity for every request, which is worth naming as a
limitation and possible extension (e.g. local caching with `sqflite`).

## 5. Example test plan (adapt with your own results)

| # | Test case | Steps | Expected result |
|---|---|---|---|
| T1 | Customer registration - valid data | Register with a new email, valid password (≥6 chars) | Account created, redirected to login |
| T2 | Customer registration - duplicate email | Register with an email already in `users` | Server returns 409, error shown on screen |
| T3 | Customer registration - invalid email | Enter "notanemail" | Client-side validator blocks submit before any request is sent |
| T4 | Login - correct credentials | Log in as jane@bookstore.com | Redirected to Customer shell (Browse tab) |
| T5 | Login - wrong password | Enter wrong password | 401 returned, "Invalid email or password" shown |
| T6 | Search books | Type "hobbit" in search | Grid filters to matching title within ~400ms (debounce) |
| T7 | Add to cart - sufficient stock | Open a book with stock > 0, add 2 | Cart badge updates to 2, cart total recalculates |
| T8 | Add to cart - exceeds stock | Try to add more than `stock_qty` | Server rejects with a clear "only N left" message |
| T9 | Checkout - empty address | Leave shipping address blank, submit | Client validator blocks; if bypassed, server also rejects (422) |
| T10 | Place order | Fill address, submit with items in cart | Order created, cart cleared, stock decremented, confirmation screen shown |
| T11 | Staff - add book | Log in as staff, add a new book with valid data | Book appears in catalogue and customer browse list |
| T12 | Staff - cannot delete book | Log in as staff, check catalogue screen | No delete icon shown (UI); direct DELETE call also returns 403 (server) |
| T13 | Staff - update order status | Advance an order from pending → processing | Status updates, visible to the customer in Order History |
| T14 | Admin - deactivate a user | Toggle a customer's active switch off | That user can no longer log in (403 on next login attempt) |
| T15 | Admin - change a user's role | Change a customer to staff | User gains Staff dashboard access on next login |
| T16 | Unauthorized access | Call `users.php` with a customer's token (e.g. via Postman) | Server returns 403 Forbidden, regardless of what the UI shows |
| T17 | Session persistence | Close and reopen the app after logging in | User remains logged in (token restored from `shared_preferences`) |
| T18 | Logout | Tap Log Out | Token cleared locally and deleted server-side; returns to Login screen |

Run these against both the emulator and, if possible, a physical device, and
capture screenshots for your "evidence of functionality" section — one per
role, showing a role-appropriate action succeeding and a forbidden action
being blocked.

## 6. Harvard referencing reminder

Any code patterns, libraries, or Stack Overflow / documentation snippets you
adapted while building or extending this (e.g. Flutter/Dart docs, PHP
manual, MySQL docs, package pages on pub.dev) must be cited in your report's
reference list per the brief's requirement.
