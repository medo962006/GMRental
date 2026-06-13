# Hostel Manager — Property Management System

A cross-platform Flutter application for managing hostel properties, built with Supabase (PostgreSQL) backend and Riverpod state management.

## Features

### Phase 1 — Digital Ledger
- **Tenant Management**: Full CRUD with payment tracking, insurance, due dates, gender, room assignment
- **Room Management**: Status tracking (occupied/void/maintenance), monthly rent configuration
- **Masareef (Expenses)**: Daily expense tracking with categories
- **Debt Collection Dashboard**: Overdue tenant alerts with call buttons, summary cards, net balance

### Phase 2 — Operations & Automation
- **Task Routines & Checklists**: Auto-spawned "Deep Clean & Prep Room" tasks on tenant checkout
- **Operational Costs**: Salary, ad spend, subscription tracking with monthly summaries
- **Visual Task Badges**: Purple (auto-checkout), Amber (daily routine), Grey (manual)

### Phase 3 — WhatsApp Engine & PDF Reports
- **WhatsApp Webhook Integration**: Send debt reminders, broadcast announcements
- **Template Variables**: `{name}`, `{room_number}` substitution
- **Executive PDF Reports**: Financial summaries with native print dialog

## Tech Stack
- **Framework**: Flutter (Windows, macOS, Linux, Android, iOS, Web)
- **State Management**: Riverpod with code generation
- **Database**: Supabase (PostgreSQL) with real-time streams
- **HTTP Client**: Dio (WhatsApp webhook)
- **PDF**: pdf + printing packages

## Setup

1. Clone the repository
2. Run `flutter pub get`
3. Update `lib/config/app_config.dart` with your Supabase credentials
4. Run `supabase_schema.sql` and `supabase_schema_phase2_3.sql` in Supabase SQL Editor
5. Run `flutter run`

## Supabase Schema
- `supabase_schema.sql` — Phase 1 tables (rooms, tenants, masareef)
- `supabase_schema_phase2_3.sql` — Phase 2+3 tables (task_routines, operational_costs, whatsapp_logs)
