# 🔬 Boxino: Deep Technical Analysis

This document provides a comprehensive breakdown of the Boxino production system, analyzing the Backend, UI, Navigation, and Cloud layers.

---

## 1. Backend Layer (PostgreSQL & Supabase)
The backend is built on **PostgreSQL** within the Supabase ecosystem, leveraging advanced DB features for speed and security.

### 📝 Data Integrity (Numeric Fix)
- **Problem**: Storing prices as `INTEGER` caused crashes when users entered decimals (e.g., `50.0`). 
- **Solution**: We executed `ALTER TABLE ... TYPE numeric`. 
- **Impact**: `NUMERIC` is the industry standard for financial data as it avoids floating-point rounding errors and accepts any decimal precision.

### 🛡️ Security Model (RLS & Roles)
- **get_user_role()**: A server-side PL/pgSQL function runs inside the database to identify if the current user is an `admin`, `delivery`, or `user`.
- **Row Level Security (RLS)**: Instead of filtering data in the app, the **Database** itself filters it. 
    - *Example*: A delivery boy's query `SELECT * FROM orders` only returns rows where `delivery_id = his_id`. This is unhackable from the frontend.

### ⚡ Realtime Infrastructure
- **REPLICA IDENTITY FULL**: This Postgres command ensures that whenever a row changes, the *entire* old and new row is sent to the realtime stream.
- **Publication**: The `orders` table is added to the `supabase_realtime` publication, enabling the app to "listen" for changes via WebSockets.

---

## 2. UI Layer (Flutter & Riverpod)
The frontend uses a reactive architecture where the UI is a function of the state.

### 🧠 State Management (Riverpod)
- **StreamProviders**: Used for `adminOrdersProvider` and `deliveryOrdersProvider`. They maintain a constant link to the database. When the DB changes, the UI rebuilds automatically.
- **FutureProviders**: Used for `userProfileProvider`. This is "one-time" data that doesn't change frequently.
- **ref.listen**: This is our **Notification Engine**. It watches a provider and triggers a `SnackBar` or `Dialog` without rebuilding the whole screen.

### 🎨 Interaction Design
- **StatefulBuilders**: Used in Admin dialogs to keep the form state (like Veg/Non-Veg checkboxes) isolated from the main screen, preventing unnecessary UI refreshes.
- **Layout Precision**: We use `Column` with `Flexible` and `ListView` to prevent "RenderFlex overflow" (Yellow/Black bars) on different screen sizes.

---

## 3. Navigation Layer (GoRouter)
Navigation is managed centrally to ensure users only see what they are authorized to see.

### 🚦 Navigation Guards
- **RouterNotifier**: A specialized class that listens to the `AuthNotifier`. 
- **Redirection Logic**: 
    - If a user logs out (`authenticated = false`), the router detects this and pushes them to `/login`.
    - If a regular user tries to type `/admin` in the URL/deep-link, the router checks their JWT role and kicks them back to `/home`.

### 🔗 Deep Linking
- Routes are defined as strings (`/admin`, `/delivery`, `/order-tracking/:id`), making it easy to implement push notification clicks that open specific orders.

---

## 4. Cloud Integration (Supabase Cloud)
- **Authentication**: Managed via Supabase Auth. It handles session persistence, meaning the app remembers you even after a restart.
- **Storage**: Kitchen and Menu images are stored as URLs. The system is ready to integrate Supabase Storage buckets.
- **Notifications**: While we use in-app SnackBars for now, the architecture is ready for **Firebase Cloud Messaging (FCM)** via the `fcm_token` column in the `users` table.

---

### **Summary of Flow**
1. **Cloud** detects a change (new order).
2. **Backend** filters the change (only admin/user see it).
3. **Navigation** ensures the user is on the right screen.
4. **UI** listens to the stream and pops up a notification.
5. **Real-time** syncs the map marker for the user.

**This is a professional-grade "Full-Stack" mobile architecture.**
