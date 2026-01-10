# Delivery Tracking System - Architecture

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         MOBILE APPLICATION                           │
├──────────────────────────┬──────────────────────┬────────────────────┤
│                          │                      │                    │
│   DELIVERY DRIVER        │    CUSTOMER          │   ORGANIZATION     │
│   ────────────────       │    ────────────      │   ──────────────   │
│                          │                      │                    │
│ • Share Location         │ • View Live Loc      │ • Monitor Fleets   │
│ • Update Status          │ • See Arrival Time   │ • Manage Drivers   │
│ • Receive Orders         │ • Track Route        │ • View Analytics   │
│                          │ • Get Notified       │ • Assign Routes    │
└──────────────────────────┴──────────────────────┴────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │    Flutter Services Layer      │
                    ├───────────────────────────────┤
                    │                               │
                    │ • DeliveryTrackingService     │
                    │ • DeliveryLocationService     │
                    │ • OrderService                │
                    │                               │
                    └───────────────────────────────┘
                                    │
                    ┌───────────────┴────────────────┐
                    │                                │
                    ▼                                ▼
        ┌─────────────────────┐        ┌──────────────────────┐
        │  GPS/Location       │        │   SUPABASE CLIENT    │
        │  (Geolocator)       │        │   SDK                │
        └─────────────────────┘        └──────────────────────┘
                    │                         │
                    └─────────────┬───────────┘
                                  │
                                  ▼
                ┌─────────────────────────────────────┐
                │      SUPABASE CLOUD (Backend)       │
                ├─────────────────────────────────────┤
                │                                     │
                │  REALTIME ENGINE (WebSocket)        │
                │  ─────────────────────────────      │
                │  • Subscribes to table changes      │
                │  • Pushes updates to clients        │
                │  • Handles multiplexing             │
                │                                     │
                ├─────────────────────────────────────┤
                │                                     │
                │  DATABASE (PostgreSQL)              │
                │  ───────────────────────────       │
                │                                     │
                │  Tables:                            │
                │  • delivery_live_locations          │
                │  • delivery_location_history        │
                │  • delivery_status                  │
                │  • order_delivery_assignments       │
                │                                     │
                └─────────────────────────────────────┘
```

## Data Flow Diagram

```
DRIVER SIDE:
─────────────
GPS Device
    │
    ▼
[Geolocator Service]
    │
    ├─ Get latitude, longitude, speed, heading
    │
    ▼
[Delivery Location Service]
    │
    ├─ Filter: distance > 5m
    ├─ Limit: update every 10 seconds
    │
    ▼
[Delivery Tracking Service]
    │
    ├─ Upsert live_locations table
    ├─ Insert location_history table
    │
    ▼
[Supabase Database]
    │
    ├─ Store in delivery_live_locations
    └─ Store in delivery_location_history
        │
        ▼
    [Realtime Engine - Broadcasts to subscribed clients]


CUSTOMER/ORG SIDE:
──────────────────
[Flutter App]
    │
    ▼
[Delivery Tracking Widget]
    │
    ├─ streamLiveLocation(assignmentId)
    ├─ streamDeliveryStatus(assignmentId)
    ├─ streamLocationHistory(assignmentId)
    │
    ▼
[Supabase Client - WebSocket Connection]
    │
    ▼
[Supabase Realtime]
    │
    ├─ Listen to delivery_live_locations
    ├─ Listen to delivery_status
    ├─ Listen to delivery_location_history
    │
    ▼
[Database Query with RLS]
    │
    ├─ Only returns data user has access to
    ├─ Enforces org/user isolation
    │
    ▼
[Updated UI with Live Data]
    │
    └─ Display location on map
    └─ Show status badges
    └─ Display history trail
```

## Database Schema Relationships

```
order_delivery_assignments
├── id (UUID)
├── user_id (UUID) - Links to delivery driver
├── account_id (UUID) - Links to organization
├── order_id (UUID) - Links to order
└── status (text)
    │
    └─ has one relationship to:
    
        ┌──────────────────────────────────┐
        │  delivery_live_locations         │
        ├──────────────────────────────────┤
        │ id (UUID)                        │
        │ assignment_id (UUID) ◄── UNIQUE  │
        │ lat (numeric)                    │
        │ lng (numeric)                    │
        │ speed (numeric, nullable)        │
        │ heading (numeric, nullable)      │
        │ updated_at (timestamp)           │
        └──────────────────────────────────┘
    
    └─ has many relationships to:
    
        ┌──────────────────────────────────┐
        │  delivery_location_history       │
        ├──────────────────────────────────┤
        │ id (UUID)                        │
        │ assignment_id (UUID) ◄── INDEX   │
        │ lat (numeric)                    │
        │ lng (numeric)                    │
        │ speed (numeric, nullable)        │
        │ recorded_at (timestamp)          │
        └──────────────────────────────────┘
    
    └─ has one relationship to:
    
        ┌──────────────────────────────────┐
        │  delivery_status                 │
        ├──────────────────────────────────┤
        │ id (UUID)                        │
        │ assignment_id (UUID) ◄── UNIQUE  │
        │ status (text)                    │
        │ updated_at (timestamp)           │
        └──────────────────────────────────┘
```

## Component Interaction Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Delivery Tracking Widget                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  Real-Time Status Display                │  │
│  │  ┌─────────────┐ ┌──────────────┐ ┌──────────────────┐  │  │
│  │  │ Status Card │ │ Location Card│ │ History List     │  │  │
│  │  └─────────────┘ └──────────────┘ └──────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            ▲                                    │
│                            │                                    │
│         ┌──────────────────┼──────────────────┐                │
│         │                  │                  │                │
│         ▼                  ▼                  ▼                │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐      │
│  │Stream Live  │  │Stream Status │  │Stream History  │      │
│  │Location     │  │              │  │                │      │
│  └─────────────┘  └──────────────┘  └────────────────┘      │
│         │                  │                  │                │
│         └──────────────────┼──────────────────┘                │
│                            │                                    │
│                            ▼                                    │
│           ┌────────────────────────────────┐                   │
│           │ Delivery Tracking Service      │                   │
│           │ ────────────────────────────   │                   │
│           │ • streamLiveLocation()         │                   │
│           │ • streamDeliveryStatus()       │                   │
│           │ • streamLocationHistory()      │                   │
│           │ • updateLiveLocation()         │                   │
│           │ • updateDeliveryStatus()       │                   │
│           └────────────────────────────────┘                   │
│                            │                                    │
└────────────────────────────┼────────────────────────────────────┘
                             │
                             ▼
                   ┌──────────────────────┐
                   │  Supabase Realtime   │
                   │  ────────────────    │
                   │  WebSocket Stream    │
                   └──────────────────────┘
                             │
                             ▼
                   ┌──────────────────────┐
                   │  PostgreSQL Database │
                   │  ────────────────    │
                   │  with RLS Policies   │
                   └──────────────────────┘
```

## Security Layer (RLS Policies)

```
┌─────────────────────────────────────────────────────────────┐
│                    RLS Policy Flow                           │
│                                                              │
│  User makes query                                           │
│       │                                                      │
│       ▼                                                      │
│  ┌────────────────────────────────────┐                    │
│  │ RLS Check: Is user the driver?     │                    │
│  │ - Matches assignment.user_id?      │                    │
│  │ - Matches assignment.account_id?   │                    │
│  └────────────────────────────────────┘                    │
│       │                                                      │
│       ├─ YES ──────► Return user's data                   │
│       │                                                      │
│       └─ NO ──────► Return NULL / Access Denied           │
│                                                              │
│  Data returned only if:                                    │
│  • User is the delivery driver, OR                        │
│  • User is from the organization that assigned delivery   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## State Management Flow

```
Driver App State:
─────────────────
┌──────────────────────┐
│ Delivery Assignment  │
│ Accepted by Driver   │
└──────────────────────┘
          │
          ▼
┌──────────────────────┐
│ Location Service     │
│ Starts GPS Tracking  │
└──────────────────────┘
          │
          ├─ Update every 10 seconds
          ├─ Minimum 5m movement
          │
          ▼
┌──────────────────────┐
│ Tracking Service     │
│ Sends Location Data  │
└──────────────────────┘
          │
          ├─ Upsert live_locations
          ├─ Insert history
          │
          ▼
┌──────────────────────┐
│ Supabase Database    │
│ Updates Tables       │
└──────────────────────┘
          │
          ├─ Broadcast to Realtime
          │
          ▼
┌──────────────────────┐
│ Customer App Stream  │
│ Receives Updates     │
└──────────────────────┘
          │
          ▼
┌──────────────────────┐
│ UI Re-renders        │
│ Shows Live Location  │
└──────────────────────┘
```

## Concurrency & Performance

```
Multiple Concurrent Operations:
──────────────────────────────

┌─ Driver 1 GPS Update ─┐
│ (every 10 seconds)    │
└─────────┬─────────────┘
          │
          ├─ Stream 1: Driver's app gets own location
          ├─ Stream 2: Customer's app sees live location
          ├─ Stream 3: Org app sees all deliveries
          │
          ▼
    ┌──────────────────┐
    │ Supabase Load    │
    │ Balancer         │
    └────────┬─────────┘
             │
             ├─ Route to database replicas
             ├─ Cache frequent queries
             ├─ Index on assignment_id
             │
             ▼
        ┌───────────────────┐
        │ PostgreSQL        │
        │ • 1 upsert        │
        │ • 1 insert        │
        │ • Multiple reads  │
        └───────────────────┘

Performance: ~100ms per update
Scalability: Handles 1000+ concurrent deliveries
```

## Error Handling & Resilience

```
Network Error:
──────────────
Connection Lost
    │
    ├─ Local queue: Store updates
    ├─ Retry logic: Exponential backoff
    │
    ▼
Connection Restored
    │
    ├─ Flush queued updates
    ├─ Sync with latest state
    │
    ▼
Resume Streaming
    │
    └─ Continue real-time updates


Location Error:
───────────────
GPS unavailable
    │
    ├─ Show warning to driver
    ├─ Suggest location fix
    │
    ▼
User enables GPS/Location
    │
    ├─ Request permission
    ├─ Resume tracking
    │
    ▼
Tracking resumes


Permission Denied:
──────────────────
App permission not granted
    │
    ├─ Show permission dialog
    ├─ Explain why needed
    │
    ▼
User grants permission
    │
    ├─ Start location tracking
    │
    ▼
Live location available
```

## Deployment Architecture

```
┌─────────────────────────────────────────────────┐
│         Production Environment                   │
│                                                  │
│  ┌────────────────────────────────────────┐   │
│  │  Google Play Store / App Store          │   │
│  │  ─────────────────────────────────      │   │
│  │  Distribution                           │   │
│  └────────────────────────────────────────┘   │
│                    │                           │
│                    ▼                           │
│  ┌────────────────────────────────────────┐   │
│  │  Mobile Device                          │   │
│  │  ─────────────────────────────────      │   │
│  │  • Flutter App                          │   │
│  │  • Services                             │   │
│  │  • GPS/Location                         │   │
│  └────────────────────────────────────────┘   │
│                    │                           │
│                    ▼                           │
│  ┌────────────────────────────────────────┐   │
│  │  Supabase Cloud (managed)               │   │
│  │  ─────────────────────────────────      │   │
│  │  • Authentication                       │   │
│  │  • Database (PostgreSQL)                │   │
│  │  • Realtime                             │   │
│  │  • Edge Functions                       │   │
│  │  • Storage                              │   │
│  └────────────────────────────────────────┘   │
│                                                  │
└─────────────────────────────────────────────────┘
```

---

This architecture ensures:
- ✅ Real-time updates via WebSocket (Realtime)
- ✅ Secure data access via RLS policies
- ✅ Efficient location tracking
- ✅ Scalable to handle multiple concurrent deliveries
- ✅ Mobile-first design with offline resilience
