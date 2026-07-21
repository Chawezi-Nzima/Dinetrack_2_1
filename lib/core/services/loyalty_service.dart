import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/user_models.dart';

/// Loyalty tier enum
enum LoyaltyTier {
  bronze,
  silver,
  gold,
  platinum,
  diamond,
}

/// Loyalty account model
class LoyaltyAccount {
  final String id;
  final String userId;
  final int totalCoins;
  final int availableCoins;
  final int lifetimeEarned;
  final int lifetimeRedeemed;
  final LoyaltyTier tier;
  final int tierProgress;
  final int nextTierThreshold;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LoyaltyAccount({
    required this.id,
    required this.userId,
    required this.totalCoins,
    required this.availableCoins,
    required this.lifetimeEarned,
    required this.lifetimeRedeemed,
    required this.tier,
    required this.tierProgress,
    required this.nextTierThreshold,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LoyaltyAccount.fromJson(Map<String, dynamic> json) {
    return LoyaltyAccount(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      totalCoins: json['total_coins'] ?? 0,
      availableCoins: json['available_coins'] ?? 0,
      lifetimeEarned: json['lifetime_earned'] ?? 0,
      lifetimeRedeemed: json['lifetime_redeemed'] ?? 0,
      tier: _parseTier(json['tier']),
      tierProgress: json['tier_progress'] ?? 0,
      nextTierThreshold: json['next_tier_threshold'] ?? 1000,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  static LoyaltyTier _parseTier(String? tier) {
    switch (tier?.toLowerCase()) {
      case 'silver':
        return LoyaltyTier.silver;
      case 'gold':
        return LoyaltyTier.gold;
      case 'platinum':
        return LoyaltyTier.platinum;
      case 'diamond':
        return LoyaltyTier.diamond;
      default:
        return LoyaltyTier.bronze;
    }
  }

  /// Get tier display name
  String get tierName {
    switch (tier) {
      case LoyaltyTier.bronze:
        return 'Bronze';
      case LoyaltyTier.silver:
        return 'Silver';
      case LoyaltyTier.gold:
        return 'Gold';
      case LoyaltyTier.platinum:
        return 'Platinum';
      case LoyaltyTier.diamond:
        return 'Diamond';
    }
  }

  /// Get tier color
  Color get tierColor {
    switch (tier) {
      case LoyaltyTier.bronze:
        return const Color(0xFFCD7F32);
      case LoyaltyTier.silver:
        return const Color(0xFFC0C0C0);
      case LoyaltyTier.gold:
        return const Color(0xFFFFD700);
      case LoyaltyTier.platinum:
        return const Color(0xFFE5E4E2);
      case LoyaltyTier.diamond:
        return const Color(0xFFB9F2FF);
    }
  }

  /// Get tier icon
  IconData get tierIcon {
    switch (tier) {
      case LoyaltyTier.bronze:
        return Icons.emoji_events;
      case LoyaltyTier.silver:
        return Icons.emoji_events;
      case LoyaltyTier.gold:
        return Icons.emoji_events;
      case LoyaltyTier.platinum:
        return Icons.diamond;
      case LoyaltyTier.diamond:
        return Icons.diamond;
    }
  }

  /// Get discount percentage for this tier
  int get tierDiscountPercent {
    switch (tier) {
      case LoyaltyTier.bronze:
        return 0;
      case LoyaltyTier.silver:
        return 5;
      case LoyaltyTier.gold:
        return 10;
      case LoyaltyTier.platinum:
        return 15;
      case LoyaltyTier.diamond:
        return 20;
    }
  }

  /// Get progress to next tier (0.0 to 1.0)
  double get tierProgressPercent {
    if (nextTierThreshold <= 0) return 1.0;
    return (tierProgress / nextTierThreshold).clamp(0.0, 1.0);
  }

  /// Get coins needed for next tier
  int get coinsToNextTier {
    return (nextTierThreshold - tierProgress).clamp(0, nextTierThreshold);
  }

  /// Get tier benefits list
  List<String> get tierBenefits {
    switch (tier) {
      case LoyaltyTier.bronze:
        return ['Earn 1 DineCoin per MWK spent', 'Birthday bonus: 50 coins'];
      case LoyaltyTier.silver:
        return [
          'Earn 1.2 DineCoins per MWK spent',
          '5% discount on all orders',
          'Birthday bonus: 100 coins',
        ];
      case LoyaltyTier.gold:
        return [
          'Earn 1.5 DineCoins per MWK spent',
          '10% discount on all orders',
          'Priority seating',
          'Birthday bonus: 250 coins',
        ];
      case LoyaltyTier.platinum:
        return [
          'Earn 2 DineCoins per MWK spent',
          '15% discount on all orders',
          'Priority seating & service',
          'Free dessert on birthdays',
          'Birthday bonus: 500 coins',
        ];
      case LoyaltyTier.diamond:
        return [
          'Earn 3 DineCoins per MWK spent',
          '20% discount on all orders',
          'VIP priority service',
          'Free appetizer + dessert on birthdays',
          'Exclusive menu access',
          'Birthday bonus: 1000 coins',
        ];
    }
  }
}

/// Loyalty transaction model
class LoyaltyTransaction {
  final String id;
  final String accountId;
  final String type; // 'earn', 'redeem', 'bonus', 'expiry', 'referral'
  final int amount;
  final String description;
  final String? orderId;
  final DateTime? expiryDate;
  final DateTime createdAt;

  const LoyaltyTransaction({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.description,
    this.orderId,
    this.expiryDate,
    required this.createdAt,
  });

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransaction(
      id: json['id'] ?? '',
      accountId: json['account_id'] ?? '',
      type: json['type'] ?? 'earn',
      amount: json['amount'] ?? 0,
      description: json['description'] ?? '',
      orderId: json['order_id'],
      expiryDate: json['expiry_date'] != null ? DateTime.parse(json['expiry_date']) : null,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  bool get isCredit => amount > 0;
  bool get isDebit => amount < 0;

  String get typeLabel {
    switch (type) {
      case 'earn':
        return 'Earned';
      case 'redeem':
        return 'Redeemed';
      case 'bonus':
        return 'Bonus';
      case 'expiry':
        return 'Expired';
      case 'referral':
        return 'Referral';
      default:
        return type;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case 'earn':
        return Icons.add_circle;
      case 'redeem':
        return Icons.remove_circle;
      case 'bonus':
        return Icons.card_giftcard;
      case 'expiry':
        return Icons.timer_off;
      case 'referral':
        return Icons.people;
      default:
        return Icons.swap_horiz;
    }
  }
}

/// Reward catalog item
class LoyaltyReward {
  final String id;
  final String name;
  final String? description;
  final int coinCost;
  final double? discountAmount;
  final String? freeItemId;
  final String? freeItemName;
  final bool isActive;
  final DateTime createdAt;

  const LoyaltyReward({
    required this.id,
    required this.name,
    this.description,
    required this.coinCost,
    this.discountAmount,
    this.freeItemId,
    this.freeItemName,
    required this.isActive,
    required this.createdAt,
  });

  factory LoyaltyReward.fromJson(Map<String, dynamic> json) {
    return LoyaltyReward(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      coinCost: json['coin_cost'] ?? 0,
      discountAmount: json['discount_amount']?.toDouble(),
      freeItemId: json['free_item_id'],
      freeItemName: json['free_item_name'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  String get displayValue {
    if (discountAmount != null) {
      return 'MWK ${discountAmount!.toStringAsFixed(0)} OFF';
    }
    if (freeItemName != null) {
      return 'Free $freeItemName';
    }
    return name;
  }
}

/// Leaderboard entry
/// Leaderboard entry
class LeaderboardEntry {
  final String userId;
  final String? displayName;
  final int totalCoins;
  final LoyaltyTier tier;
  final int rank;

  const LeaderboardEntry({
    required this.userId,
    this.displayName,
    required this.totalCoins,
    required this.tier,
    required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id'] ?? '',
      displayName: json['display_name'],
      totalCoins: json['total_coins'] ?? 0,
      tier: LoyaltyAccount._parseTier(json['tier']),
      rank: json['rank'] ?? 0,
    );
  }

  /// Get tier display name
  String get tierName {
    switch (tier) {
      case LoyaltyTier.bronze:
        return 'Bronze';
      case LoyaltyTier.silver:
        return 'Silver';
      case LoyaltyTier.gold:
        return 'Gold';
      case LoyaltyTier.platinum:
        return 'Platinum';
      case LoyaltyTier.diamond:
        return 'Diamond';
    }
  }

  /// Get tier color
  Color get tierColor {
    switch (tier) {
      case LoyaltyTier.bronze:
        return const Color(0xFFCD7F32);
      case LoyaltyTier.silver:
        return const Color(0xFFC0C0C0);
      case LoyaltyTier.gold:
        return const Color(0xFFFFD700);
      case LoyaltyTier.platinum:
        return const Color(0xFFE5E4E2);
      case LoyaltyTier.diamond:
        return const Color(0xFFB9F2FF);
    }
  }
}

/// Loyalty Service
class LoyaltyService {
  static final LoyaltyService _instance = LoyaltyService._internal();
  factory LoyaltyService() => _instance;
  LoyaltyService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get current user ID
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Stream of loyalty account for current user
  Stream<LoyaltyAccount?> get accountStream {
    final userId = _currentUserId;
    if (userId == null) return Stream.value(null);

    return _supabase
        .from('loyalty_accounts')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((data) => data.isNotEmpty ? LoyaltyAccount.fromJson(data.first) : null);
  }

  /// Get loyalty account
  Future<LoyaltyAccount?> getAccount() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return null;

      final response = await _supabase
          .from('loyalty_accounts')
          .select()
          .eq('user_id', userId)
          .single();

      return LoyaltyAccount.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching loyalty account: $e');
      return null;
    }
  }

  /// Get transaction history
  Future<List<LoyaltyTransaction>> getTransactions({int limit = 50}) async {
    try {
      final account = await getAccount();
      if (account == null) return [];

      final response = await _supabase
          .from('loyalty_transactions')
          .select()
          .eq('account_id', account.id)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List<dynamic>)
          .map((json) => LoyaltyTransaction.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      return [];
    }
  }

  /// Stream of transactions
  Stream<List<LoyaltyTransaction>> get transactionsStream {
    return accountStream.asyncExpand((account) {
      if (account == null) return Stream.value([]);
      return _supabase
          .from('loyalty_transactions')
          .stream(primaryKey: ['id'])
          .eq('account_id', account.id)
          .order('created_at', ascending: false)
          .map((data) => data.map((json) => LoyaltyTransaction.fromJson(json)).toList());
    });
  }

  /// Get available rewards
  Future<List<LoyaltyReward>> getAvailableRewards() async {
    try {
      final response = await _supabase
          .from('loyalty_rewards')
          .select()
          .eq('is_active', true)
          .order('coin_cost', ascending: true);

      return (response as List<dynamic>)
          .map((json) => LoyaltyReward.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching rewards: $e');
      return [];
    }
  }

  /// Redeem a reward
  Future<bool> redeemReward({
    required String rewardId,
    String? orderId,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;

      final account = await getAccount();
      if (account == null) return false;

      final reward = await _supabase
          .from('loyalty_rewards')
          .select()
          .eq('id', rewardId)
          .single();

      final coinCost = reward['coin_cost'] as int;

      if (account.availableCoins < coinCost) {
        debugPrint('Insufficient coins');
        return false;
      }

      // Deduct coins
      await _supabase.from('loyalty_accounts').update({
        'total_coins': account.totalCoins - coinCost,
        'available_coins': account.availableCoins - coinCost,
        'lifetime_redeemed': account.lifetimeRedeemed + coinCost,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      // Record transaction
      await _supabase.from('loyalty_transactions').insert({
        'account_id': account.id,
        'type': 'redeem',
        'amount': -coinCost,
        'description': 'Redeemed: ${reward['name']}',
        'order_id': orderId,
      });

      // Create notification
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': 'Reward Redeemed!',
        'body': 'You redeemed ${reward['name']} for $coinCost DineCoins.',
        'type': 'promotion',
        'priority': 'normal',
        'data': {
          'reward_id': rewardId,
          'coins_spent': coinCost,
          'order_id': orderId,
        },
      });

      return true;
    } catch (e) {
      debugPrint('Error redeeming reward: $e');
      return false;
    }
  }

  /// Get leaderboard (top customers)
  Future<List<LeaderboardEntry>> getLeaderboard({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('loyalty_accounts')
          .select('user_id, total_coins, tier, users(display_name)')
          .order('total_coins', ascending: false)
          .limit(limit);

      return (response as List<dynamic>).asMap().entries.map((entry) {
        final json = entry.value as Map<String, dynamic>;
        json['rank'] = entry.key + 1;
        json['display_name'] = json['users']?['display_name'];
        return LeaderboardEntry.fromJson(json);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
      return [];
    }
  }

  /// Check and apply birthday bonus
  Future<bool> checkBirthdayBonus() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;

      final user = await _supabase
          .from('users')
          .select('date_of_birth, last_birthday_bonus')
          .eq('id', userId)
          .single();

      final dob = user['date_of_birth'] != null
          ? DateTime.parse(user['date_of_birth'])
          : null;
      if (dob == null) return false;

      final now = DateTime.now();
      final isBirthday = dob.month == now.month && dob.day == now.day;

      final lastBonus = user['last_birthday_bonus'] != null
          ? DateTime.parse(user['last_birthday_bonus'])
          : null;

      if (isBirthday && (lastBonus == null || lastBonus.year < now.year)) {
        final account = await getAccount();
        if (account == null) return false;

        final bonusCoins = account.tier == LoyaltyTier.diamond
            ? 1000
            : account.tier == LoyaltyTier.platinum
            ? 500
            : account.tier == LoyaltyTier.gold
            ? 250
            : account.tier == LoyaltyTier.silver
            ? 100
            : 50;

        // Credit bonus
        await _supabase.from('loyalty_accounts').update({
          'total_coins': account.totalCoins + bonusCoins,
          'available_coins': account.availableCoins + bonusCoins,
          'lifetime_earned': account.lifetimeEarned + bonusCoins,
          'updated_at': now.toIso8601String(),
        }).eq('user_id', userId);

        await _supabase.from('loyalty_transactions').insert({
          'account_id': account.id,
          'type': 'bonus',
          'amount': bonusCoins,
          'description': '🎂 Birthday Bonus! $bonusCoins DineCoins',
        });

        await _supabase.from('users').update({
          'last_birthday_bonus': now.toIso8601String(),
        }).eq('id', userId);

        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking birthday bonus: $e');
      return false;
    }
  }

  /// Refer a friend (credit referral bonus)
  Future<bool> processReferral(String referredUserId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;

      final account = await getAccount();
      if (account == null) return false;

      const referralBonus = 200;

      await _supabase.from('loyalty_accounts').update({
        'total_coins': account.totalCoins + referralBonus,
        'available_coins': account.availableCoins + referralBonus,
        'lifetime_earned': account.lifetimeEarned + referralBonus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      await _supabase.from('loyalty_transactions').insert({
        'account_id': account.id,
        'type': 'referral',
        'amount': referralBonus,
        'description': 'Referral bonus: Friend joined!',
      });

      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': 'Referral Bonus!',
        'body': 'You earned $referralBonus DineCoins for referring a friend!',
        'type': 'promotion',
        'priority': 'normal',
      });

      return true;
    } catch (e) {
      debugPrint('Error processing referral: $e');
      return false;
    }
  }

  /// Get expiring coins warning
  Future<List<LoyaltyTransaction>> getExpiringCoins({int daysThreshold = 30}) async {
    try {
      final account = await getAccount();
      if (account == null) return [];

      final threshold = DateTime.now().add(Duration(days: daysThreshold));

      final response = await _supabase
          .from('loyalty_transactions')
          .select()
          .eq('account_id', account.id)
          .gt('amount', 0)
          .not('expiry_date', 'is', null)
          .lte('expiry_date', threshold.toIso8601String())
          .order('expiry_date', ascending: true);

      return (response as List<dynamic>)
          .map((json) => LoyaltyTransaction.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching expiring coins: $e');
      return [];
    }
  }
}
