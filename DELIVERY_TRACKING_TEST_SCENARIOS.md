# 🎬 Delivery Tracking - Visual Flow & Testing Scenarios

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    ORG Orders Management Screen                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Order #7b944e46 | Status: PREPARING | Items: 1            │ │
│  │ Customer: Jad Faour | Phone: +96176552369                 │ │
│  │ Location: Tripoli                                          │ │
│  │ Total: 890,000 LBP ≈ $9.94                               │ │
│  │ ┌──────────────┬──────────────────┐                       │ │
│  │ │ Update Status│ [View Details] ← CLICK HERE             │ │
│  │ └──────────────┴──────────────────┘                       │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              ↓ Navigate to
┌─────────────────────────────────────────────────────────────────┐
│                     Order Detail Screen                          │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Order #7b944e46 | [PREPARING BADGE]                       │ │
│  │                                                             │ │
│  │ Order Date: 2026-01-08 10:30:45                           │ │
│  │ Total Items: 1                                             │ │
│  │ Total Amount: 890,000 LBP                                 │ │
│  │                                                             │ │
│  │ ┌─────────────────────────────────────────────────────────┤ │
│  │ │ 🚚 Delivery Assignment                                  │ │
│  │ │ Driver: [Driver Name]                                  │ │
│  │ │ Phone: [Driver Phone]                                  │ │
│  │ │ Assigned: 2026-01-08 10:32:00                          │ │
│  │ └─────────────────────────────────────────────────────────┤ │
│  │                                                             │ │
│  │ 📍 LIVE TRACKING WIDGET                                    │ │
│  │ ┌─────────────────────────────────────────────────────────┤ │
│  │ │ 🟢 READY                                               │ │
│  │ │                                                         │ │
│  │ │ 📍 Current Location:                                   │ │
│  │ │    Lat: 25.2048, Lng: 55.2708                          │ │
│  │ │    Speed: 45 km/h, Heading: 123°                       │ │
│  │ │                                                         │ │
│  │ │ 📏 Distance: 2.5 km to destination                     │ │
│  │ │ ⏱️  ETA: ~3 minutes                                     │ │
│  │ │                                                         │ │
│  │ │ 📍 Location History:                                   │ │
│  │ │    • 10:32:00 - Start point                            │ │
│  │ │    • 10:33:15 - Moving East                            │ │
│  │ │    • 10:34:30 - On main road                           │ │
│  │ │    • 10:35:45 - Approaching destination                │ │
│  │ │                                                         │ │
│  │ │ Status History:                                        │ │
│  │ │    • ASSIGNED (10:32:00)                               │ │
│  │ │    • ARRIVING (10:35:00)                               │ │
│  │ └─────────────────────────────────────────────────────────┤ │
│  │                                                             │ │
│  │ [Start Tracking] [Stop Tracking]                           │ │
│  │ [Mark Ready]     [Delivered]                               │ │
│  │                                                             │ │
│  │ Order Items (1)                                            │ │
│  │ ┌─────────────────────────────────────────────────────────┤ │
│  │ │ Item Name          │ Qty: 1 │ Price: 890,000 LBP       │ │
│  │ └─────────────────────────────────────────────────────────┤ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Step-by-Step Testing Scenarios

### Scenario 1: Complete Flow (No Delivery Assigned Yet)

```
1. ORDER CREATED
   Status: PREPARING
   Order Detail Screen opens
   ↓
   Shows: "No delivery assigned yet" (orange alert)
   
2. ASSIGN DELIVERY (from org_orders_screen)
   Dialog: Select delivery driver
   Click: Save
   Status: Changes to READY
   ↓
   Order Detail Screen refreshes
   Shows: Driver name, phone, assigned time
   Shows: DeliveryTrackingWidget (empty - no location yet)
   
3. DRIVER ACCEPTS & STARTS MOVING
   Shows: "Start Tracking" button active
   Click: Start Tracking
   ↓
   GPS permission dialog appears → Grant access
   Location updates begin
   DeliveryTrackingWidget shows:
   - Live location (25.2048, 55.2708)
   - Speed: 45 km/h
   - Heading: 123°
   - Distance to destination: 2.5 km
   
4. DRIVER APPROACHING
   Location history shows breadcrumb trail
   Distance decreases: 2.5 → 2.0 → 1.5 km
   Status auto-updates to ARRIVING (if configured)
   
5. DELIVERY COMPLETE
   Click: "Delivered" button
   Status updates to DELIVERED
   Locations saved in database
   Location tracking can be stopped
```

### Scenario 2: Only Tracking Live Location

```
1. Order already assigned
2. Click "View Details"
3. Click "Start Tracking"
4. DeliveryTrackingWidget displays:
   - Real-time location updates
   - Speed and heading
   - Distance remaining
5. Refresh browser/app → Still shows live data from streams
6. Multiple users (ORG + CUSTOMER) see same live location
7. Click "Stop Tracking" → GPS stops, last location preserved
```

### Scenario 3: Review Delivery History

```
1. Order marked DELIVERED
2. Click "View Details" 
3. DeliveryTrackingWidget shows:
   - Complete route history (all points)
   - All status changes with timestamps
   - Total distance traveled
   - Duration
4. User and ORG can both view this history
```

---

## Database Entries Created

### When Order Created + Delivered

#### `delivery_live_locations` table
```sql
id: uuid
assignment_id: uuid (foreign key)
latitude: double (25.2048)
longitude: double (55.2708)
speed: double (45.2)
heading: double (123.4)
updated_at: timestamp (2026-01-08 10:35:45)

-- Only 1 record per assignment (upserted)
```

#### `delivery_location_history` table
```sql
id: uuid
assignment_id: uuid (same as above)
latitude: double
longitude: double
speed: double
recorded_at: timestamp

-- Multiple records:
-- 2026-01-08 10:32:00 - 25.2040, 55.2700, 0 km/h
-- 2026-01-08 10:32:30 - 25.2041, 55.2702, 15 km/h
-- 2026-01-08 10:33:00 - 25.2045, 55.2705, 35 km/h
-- 2026-01-08 10:33:30 - 25.2048, 55.2708, 45 km/h
-- ... (continues for entire delivery)
```

#### `delivery_status` table
```sql
id: uuid
assignment_id: uuid
status: enum ('assigned', 'arriving', 'delivered', 'cancelled')
updated_at: timestamp
notes: text (optional)

-- Multiple records (status changes):
-- ASSIGNED - 2026-01-08 10:32:00
-- ARRIVING - 2026-01-08 10:35:00 (auto or manual)
-- DELIVERED - 2026-01-08 10:38:00 (manual click)
```

---

## Real-Time Streams (What's Being Watched)

### From ORG's Perspective
```dart
// DeliveryTrackingWidget subscribes to:
1. streamLiveLocation(assignmentId)
   → Shows current location pin
   → Updates every 5-30 seconds

2. streamDeliveryStatus(assignmentId)
   → Shows status badge (ASSIGNED/ARRIVING/DELIVERED)
   → Updates when driver changes status

3. streamLocationHistory(assignmentId)
   → Shows breadcrumb trail
   → Appends new points as they arrive
```

### From CUSTOMER's Perspective (if implemented)
- Same streams (RLS allows)
- Can track their delivery in real-time
- Can't modify data (read-only)

### From DRIVER's Perspective (if implemented)
- Can UPDATE their location
- Can UPDATE their status
- Can't see other deliveries (RLS filters)

---

## Error Scenarios & Recovery

### Error 1: No GPS Signal
```
User clicks "Start Tracking"
↓
Error: "Location service not enabled"
↓
App shows: "Open Location Settings" button
↓
User clicks → Opens device settings
↓
User enables GPS
↓
Retry "Start Tracking"
```

### Error 2: Permission Denied
```
User clicks "Start Tracking"
↓
Permission dialog appears
↓
User taps "Don't Allow"
↓
Error: "Location permission denied"
↓
App shows: "Go to Settings" button
↓
User manually allows location in Settings
↓
Retry "Start Tracking"
```

### Error 3: Network Offline
```
Tracking starts
↓
Driver moves but no internet
↓
Geolocator keeps recording locally
↓
Internet returns
↓
Locations sync to Supabase
↓
ORG sees location updates appear
```

---

## Performance Metrics to Track

| Metric | Expected Value |
|--------|---|
| GPS update frequency | Every 5+ meters or 30 seconds |
| Database write latency | < 2 seconds |
| Stream update latency | < 1 second |
| Location history size | 5-10 KB per delivery |
| Widget rebuild time | < 100ms |

---

## Testing Checklist

- [ ] Create order
- [ ] Assign delivery driver
- [ ] Open order details
- [ ] See delivery assignment info
- [ ] Click "Start Tracking"
- [ ] Grant location permission
- [ ] See live location appear in widget
- [ ] Walk/drive with device
- [ ] Location updates in real-time
- [ ] Distance decreases as you approach
- [ ] Location history grows with breadcrumbs
- [ ] Click "Mark Ready" → status changes
- [ ] Click "Delivered" → status changes
- [ ] Click "Stop Tracking" → GPS stops
- [ ] Reload app → data still visible
- [ ] Both ORG and USER can view same data

---

## Console Logs to Expect

```
📍 Location update: 25.2048, 55.2708
🟢 Delivery status: READY
📏 Distance to destination: 2500 meters
✅ Location saved to delivery_live_locations
✅ History point saved to delivery_location_history
🔄 Streams initialized for assignment [id]
📱 GPS tracking started
🛑 GPS tracking stopped
```

---

This guide gives you everything needed to test the complete delivery tracking system end-to-end!
