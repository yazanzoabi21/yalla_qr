import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnrollmentService extends ChangeNotifier {
  EnrollmentService._private();
  static final EnrollmentService instance = EnrollmentService._private();

  final Set<String> _enrolled = {};
  bool _loaded = false;
  bool _categorySubscriptionsAvailable = true;

  Set<String> get enrolled => _enrolled;

  bool isEnrolled(String accountId) => _enrolled.contains(accountId);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final resp = await Supabase.instance.client
          .from('user_account_subscriptions')
          .select('account_id')
          .eq('user_id', user.id)
          .eq('subscribed', true);
      final ids = (resp as List<dynamic>).map((r) => r['account_id'] as String).toList();
      _enrolled.addAll(ids);
      notifyListeners();
    } catch (e) {
      // If the subscriptions table doesn't exist, avoid spamming errors.
      final msg = e.toString();
      if (msg.contains('does not exist') || msg.contains('42P01') || msg.contains('Not Found')) {
        _categorySubscriptionsAvailable = false;
      }
      debugPrint('EnrollmentService.load failed: $e');
    }
  }

  /// Merge a set of already-known enrollment IDs into the cache.
  ///
  /// This is used when we load additional information (e.g. from
  /// organization_visitors) that the primary `load` call doesn't cover.
  /// The change is notified so listeners can rebuild immediately.
  void mergeEnrollments(Iterable<String> ids) {
    bool changed = false;
    for (var id in ids) {
      if (_enrolled.add(id)) {
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  Future<void> enrollAccount(String accountId, {List<String>? categoryIds}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // optimistic update
    final already = _enrolled.contains(accountId);
    if (!already) {
      _enrolled.add(accountId);
      notifyListeners();
    }

    try {
      await Supabase.instance.client.from('user_account_subscriptions').upsert({
        'user_id': user.id,
        'account_id': accountId,
        'subscribed': true,
      });

      // best-effort sync category subscriptions if provided (if table exists)
      if (_categorySubscriptionsAvailable && categoryIds != null && categoryIds.isNotEmpty) {
        for (var cid in categoryIds) {
          try {
            await Supabase.instance.client.from('user_category_subscriptions').upsert({
              'user_id': user.id,
              'category_id': cid,
              'subscribed': true,
            });
          } catch (e) {
            final msg = e.toString();
            if (msg.contains('does not exist') || msg.contains('42P01') || msg.contains('Not Found')) {
              _categorySubscriptionsAvailable = false; // stop attempting further category upserts
              break;
            }
            // swallow per-category failures
            debugPrint('EnrollmentService: failed to upsert category $cid: $e');
          }
        }
      }
    } on PostgrestException catch (e) {
      // If the subscription tables or endpoints are missing (404), don't fail the whole flow.
      // Treat as best-effort: keep optimistic state and log a helpful message.
      debugPrint('EnrollmentService.enrollAccount: PostgrestException (fallback) - $e');
    } catch (e) {
      // rollback optimistic for unexpected errors
      if (!already) {
        _enrolled.remove(accountId);
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> unenrollAccount(String accountId, {List<String>? categoryIds}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final wasEnrolled = _enrolled.contains(accountId);
    if (wasEnrolled) {
      _enrolled.remove(accountId);
      notifyListeners();
    }

    try {
      await Supabase.instance.client.from('user_account_subscriptions').upsert({
        'user_id': user.id,
        'account_id': accountId,
        'subscribed': false,
      });

      if (_categorySubscriptionsAvailable && categoryIds != null && categoryIds.isNotEmpty) {
        for (var cid in categoryIds) {
          try {
            await Supabase.instance.client.from('user_category_subscriptions').upsert({
              'user_id': user.id,
              'category_id': cid,
              'subscribed': false,
            });
          } catch (e) {
            final msg = e.toString();
            if (msg.contains('does not exist') || msg.contains('42P01') || msg.contains('Not Found')) {
              _categorySubscriptionsAvailable = false;
              break;
            }
            debugPrint('EnrollmentService: failed to unset category $cid: $e');
          }
        }
      }
    } on PostgrestException catch (e) {
      // If the subscription endpoint doesn't exist, swallow and keep optimistic state
      debugPrint('EnrollmentService.unenrollAccount: PostgrestException (fallback) - $e');
    } catch (e) {
      // rollback optimistic
      if (wasEnrolled) {
        _enrolled.add(accountId);
        notifyListeners();
      }
      rethrow;
    }
  }
}
