# 🍱 Boxino: Production System Overview

Boxino is a high-performance, real-time food delivery ecosystem built with **Flutter** and **Supabase (Postgres)**. This document explains how the entire system works "under the hood" and lists all the features you now have.

## 1. Core Architecture (How it Works)
- **Database (Supabase)**: The single source of truth. We use **PostgreSQL** with a consolidated `orders` table to track everything from placement to delivery.
- **Security (Row Level Security)**: Data is protected by RLS and a custom `get_user_role()` function. 
    - **Admins** see everything.
    - **Delivery Boys** only see their assigned tasks.
    - **Users** only see their own orders.
- **Real-time Engine**: We use **Supabase Streams**. When an Admin updates a status or a Delivery Boy moves his bike, the User's app updates **instantly** without refreshing.
- **State Management**: **Riverpod** handles the app's logic, ensuring that data is always fresh and shared across screens.

---

## 2. Key Features Across Apps

### 👑 Admin Panel (Control Center)
- **Live Stats Dashboard**: View total orders and performance at a glance.
- **Full Kitchen CRUD**: Add, Delete, or Update Kitchens with support for Pure Veg/Non-Veg filters.
- **Menu Management**: Update items, prices (decimal supported), and availability instantly.
- **Smart Assignment**: Manual or Auto-assign orders to Delivery Partners via a "Swiggy-style" bottom sheet.
- **Real-time Notifications**: Floating SnackBars notify you immediately when a new order is received.
- **Role Control**: Change any user's role (User -> Delivery -> Admin) directly from the UI.

### 🚴 Delivery Boy Dashboard (Rider App)
- **Personal Task List**: A dedicated tab for orders assigned only to you.
- **Real-time GPS Tracking**: Automatically sends live coordinates to the User when toggle "Online".
- **Dynamic Earnings**: Automatically calculates income from delivered orders.
- **Simple Lifecycle**: Quick status updates (Accepted -> Preparing -> Out for Delivery -> Delivered).
- **Navigation Navbar**: Evenly spaced, modern navigation bar for easy access.

### 👤 User App (Customer Experience)
- **Seamless Ordering**: Browse kitchens, add items to cart, and checkout with Cash/Online options.
- **Live Order Tracking**: A real-time map showing the rider's position moving toward the destination.
- **Status Alerts**: In-app notifications tell you exactly when your food is being prepared or is outside your door.
- **Profile Setup**: Manage delivery addresses and preferences.

---

## 3. Data Integrity & Safety
- **Decimal Precision**: Prices use `NUMERIC` types, meaning `99.99` works perfectly without integer errors.
- **Secure Logout**: Centralized authentication ensures all local state and tokens are wiped on logout.
- **Persistence**: Auth state is saved, so users don't have to log in every time the app restarts.

---

### **Final Verdict**
The system is now a **fully connected loop**:
1. **User** orders -> 2. **Admin** gets Alert -> 3. **Admin** assigns Partner -> 4. **Partner** gets Alert -> 5. **Partner** updates GPS -> 6. **User** sees Rider on Map -> 7. **Partner** completes delivery -> 8. **Admin** sees successful update.

**Everything is synchronized in real-time through the `orders` table.**
