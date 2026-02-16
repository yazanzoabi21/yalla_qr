# Organization Statistics Integration - Setup Guide

This guide explains how to set up and use the organization-level statistics feature in your Flutter application.

## 📋 Overview

The statistics feature provides organization owners with comprehensive analytics including:
- QR code and scan metrics
- Product inventory status
- Order statistics and trends
- Revenue tracking (LBP and USD)
- Delivery status monitoring
- Time-based activity (today, this week, this month)

## 🚀 Setup Instructions

### 1. Database Setup

Run the SQL migration file in your Supabase SQL editor:

```bash
# File: create_org_statistics_table.sql
```

This creates:
- `org_statistics` table with all required columns
- Row Level Security (RLS) policies for data protection
- Indexes for performance optimization
- `update_org_statistics()` function for calculating statistics

### 2. Flutter Dependencies

The `intl` package has been added to `pubspec.yaml` for number formatting. Dependencies are already installed.

### 3. File Structure

The following files have been created:

**Models:**
- `lib/models/org_statistics.dart` - Data model for organization statistics

**Services:**
- `lib/services/org_statistics_service.dart` - Service for fetching and updating statistics

**Screens:**
- `lib/screens/org/org_home_screen.dart` - Main screen with bottom navigation
- `lib/screens/org/org_statistics_screen.dart` - Statistics display screen

**Migration:**
- `create_org_statistics_table.sql` - Database migration file

### 4. Navigation Updates

The app navigation has been updated:
- `client_categories_screen.dart` now navigates to `OrgHomeScreen` instead of `OrganizationCategoriesScreen`
- `OrgHomeScreen` provides bottom navigation with two tabs: **Home** and **Statistics**

## 📊 Using the Statistics Feature

### For Organization Owners:

1. **Access Statistics:**
   - Login as an organization owner
   - Navigate to your organization page
   - Tap the "Statistics" tab in the bottom navigation bar

2. **Refresh Statistics:**
   - Pull down to refresh on the statistics screen
   - Statistics are automatically recalculated from the latest data

3. **View Metrics:**
   - Overview: QR codes, scans, visitors
   - Products: Total, in stock, out of stock
   - Orders: Total, pending, completed, cancelled
   - Revenue: LBP and USD totals
   - Deliveries: Total, active, completed
   - Timeline: Today, this week, this month metrics

### Manual Statistics Update (Optional):

You can manually trigger statistics calculation using the Supabase function:

```sql
SELECT update_org_statistics('your-account-id-here');
```

### Automated Updates (Recommended):

For real-time statistics, you can set up triggers to automatically update statistics when:
- New orders are created
- Products are added/updated
- Scans occur
- Deliveries status changes

Example trigger:

```sql
CREATE OR REPLACE FUNCTION trigger_update_org_statistics()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM update_org_statistics(NEW.account_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on orders table
CREATE TRIGGER on_order_change
  AFTER INSERT OR UPDATE OR DELETE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_org_statistics();
```

## 🎨 UI Features

The statistics screen includes:
- Beautiful gradient header
- Color-coded stat cards with icons
- Sectioned layout for easy navigation
- Responsive design for all screen sizes
- Pull-to-refresh functionality
- Loading and error states
- Last updated timestamp

## 🔒 Security

Row Level Security (RLS) ensures:
- Only organization owners can view their own statistics
- Statistics are automatically filtered by user's account
- No cross-organization data leakage

## 🐛 Troubleshooting

**Statistics not showing:**
1. Ensure you're logged in as an organization owner
2. Check that the SQL migration has been run
3. Verify RLS policies are enabled
4. Try refreshing statistics manually

**Data not updating:**
1. Pull down to refresh the statistics screen
2. Check that the `update_org_statistics()` function exists
3. Verify your account has the required data (orders, products, etc.)

**Navigation issues:**
1. Ensure you're accessing the org screen from the client categories
2. Check that the account has the 'ORG' role

## 📝 Next Steps

Consider adding:
1. Charts and graphs for visual analytics
2. Date range filters for custom time periods
3. Export functionality for reports
4. Comparison metrics (e.g., vs. last month)
5. Real-time updates using Supabase Realtime
6. Push notifications for key metrics

## 🔗 Related Files

- Models: `lib/models/org_statistics.dart`
- Services: `lib/services/org_statistics_service.dart`
- Screens: `lib/screens/org/org_home_screen.dart`, `lib/screens/org/org_statistics_screen.dart`
- Migration: `create_org_statistics_table.sql`

---

**Last Updated:** February 5, 2026
