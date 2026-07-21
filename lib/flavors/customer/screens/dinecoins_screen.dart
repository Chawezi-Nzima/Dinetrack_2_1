import 'package:dinetrack_2_1/core/services/loyalty_service.dart';
import 'package:dinetrack_2_1/core/services/notification_service.dart';
import 'package:dinetrack_2_1/shared/widgets/notification_overlay.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Customer DineCoins / Loyalty Screen
class DineCoinsScreen extends StatefulWidget {
  const DineCoinsScreen({super.key});

  @override
  State<DineCoinsScreen> createState() => _DineCoinsScreenState();
}

class _DineCoinsScreenState extends State<DineCoinsScreen>
    with SingleTickerProviderStateMixin {
  final LoyaltyService _loyaltyService = LoyaltyService();
  late TabController _tabController;
  LoyaltyAccount? _account;
  List<LoyaltyTransaction> _transactions = [];
  List<LoyaltyReward> _rewards = [];
  List<LeaderboardEntry> _leaderboard = [];
  bool _isLoading = true;
  bool _isRedeeming = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _loyaltyService.getAccount(),
      _loyaltyService.getTransactions(),
      _loyaltyService.getAvailableRewards(),
      _loyaltyService.getLeaderboard(),
    ]);

    setState(() {
      _account = results[0] as LoyaltyAccount?;
      _transactions = results[1] as List<LoyaltyTransaction>;
      _rewards = results[2] as List<LoyaltyReward>;
      _leaderboard = results[3] as List<LeaderboardEntry>;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF1a1a2e),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildCoinHeader(),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: _account?.tierColor ?? const Color(0xFFFFD700),
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
                Tab(text: 'Rewards', icon: Icon(Icons.card_giftcard)),
                Tab(text: 'History', icon: Icon(Icons.history)),
              ],
            ),
          ),
        ],
        body: _isLoading
            ? const _LoadingSkeleton()
            : TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildRewardsTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1a1a2e),
            const Color(0xFF16213e),
            _account?.tierColor.withOpacity(0.3) ?? const Color(0xFF0f3460),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Tier badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: (_account?.tierColor ?? const Color(0xFFFFD700)).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (_account?.tierColor ?? const Color(0xFFFFD700)).withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _account?.tierIcon ?? Icons.emoji_events,
                    color: _account?.tierColor ?? const Color(0xFFFFD700),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _account?.tierName ?? 'Bronze',
                    style: TextStyle(
                      color: _account?.tierColor ?? const Color(0xFFFFD700),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Coin count
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: Color(0xFFFFD700),
                  size: 40,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_account?.availableCoins ?? 0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
            const Text(
              'DineCoins Available',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 20),
            // Progress to next tier
            if (_account != null && _account!.tier != LoyaltyTier.diamond)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_account!.tierProgress} coins',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        Text(
                          '${_account!.nextTierThreshold} coins',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _account!.tierProgressPercent,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _account!.tierColor,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_account!.coinsToNextTier} more coins to ${_getNextTierName()}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            if (_account != null && _account!.tier == LoyaltyTier.diamond)
              const Text(
                "🎉 You've reached the highest tier!",
                style: TextStyle(color: Color(0xFFFFD700), fontSize: 14),
              ),
          ],
        ),
      ),
    );
  }

  String _getNextTierName() {
    if (_account == null) return 'Silver';
    switch (_account!.tier) {
      case LoyaltyTier.bronze:
        return 'Silver';
      case LoyaltyTier.silver:
        return 'Gold';
      case LoyaltyTier.gold:
        return 'Platinum';
      case LoyaltyTier.platinum:
        return 'Diamond';
      case LoyaltyTier.diamond:
        return 'Max';
    }
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats cards
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Lifetime Earned',
                '${_account?.lifetimeEarned ?? 0}',
                Icons.trending_up,
                const Color(0xFF11998e),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Redeemed',
                '${_account?.lifetimeRedeemed ?? 0}',
                Icons.redeem,
                const Color(0xFFf093fb),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Current Discount',
                '${_account?.tierDiscountPercent ?? 0}%',
                Icons.discount,
                const Color(0xFF4facfe),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Orders',
                '${_transactions.where((t) => t.type == 'earn').length}',
                Icons.receipt,
                const Color(0xFFfa709a),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Tier benefits
        _buildSectionTitle('Your ${(_account?.tierName ?? 'Bronze')} Benefits'),
        const SizedBox(height: 12),
        ...(_account?.tierBenefits ?? []).map((benefit) => _buildBenefitItem(benefit)),
        const SizedBox(height: 24),
        // Leaderboard preview
        if (_leaderboard.isNotEmpty) ...[
          _buildSectionTitle('🏆 Top DineCoin Earners'),
          const SizedBox(height: 12),
          ..._leaderboard.take(5).map((entry) => _buildLeaderboardItem(entry)),
        ],
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1a1a2e),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String benefit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF11998e).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Color(0xFF11998e), size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              benefit,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(LeaderboardEntry entry) {
    final isCurrentUser = entry.rank <= 3;
    final medalColors = [const Color(0xFFFFD700), const Color(0xFFC0C0C0), const Color(0xFFCD7F32)];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrentUser ? const Color(0xFFFFF9E6) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(color: const Color(0xFFFFD700).withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: entry.rank <= 3
                  ? medalColors[entry.rank - 1].withOpacity(0.15)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#${entry.rank}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: entry.rank <= 3 ? medalColors[entry.rank - 1] : Colors.grey.shade500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName ?? 'Anonymous',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  entry.tierName,  // ← FIXED: was entry.tierName (model now has it)
                  style: TextStyle(
                    fontSize: 12,
                    color: entry.tierColor,  // ← FIXED: was entry.tierColor (model now has it)
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 16),
              const SizedBox(width: 4),
              Text(
                '${entry.totalCoins}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF1a1a2e),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsTab() {
    if (_rewards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.card_giftcard_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No rewards available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Redeem Your DineCoins'),
        const SizedBox(height: 8),
        Text(
          'You have ${_account?.availableCoins ?? 0} coins available',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
        const SizedBox(height: 20),
        ..._rewards.map((reward) => _buildRewardCard(reward)),
      ],
    );
  }

  Widget _buildRewardCard(LoyaltyReward reward) {
    final canAfford = (_account?.availableCoins ?? 0) >= reward.coinCost;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: canAfford
                    ? [const Color(0xFF667eea), const Color(0xFF764ba2)]
                    : [Colors.grey.shade300, Colors.grey.shade400],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.card_giftcard, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (reward.description != null)
                  Text(
                    reward.description!,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reward.displayValue,
                    style: const TextStyle(
                      color: Color(0xFFf59e0b),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.monetization_on,
                    color: canAfford ? const Color(0xFFFFD700) : Colors.grey.shade300,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${reward.coinCost}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: canAfford ? const Color(0xFF1a1a2e) : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: canAfford && !_isRedeeming ? () => _redeemReward(reward) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isRedeeming
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Redeem', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _redeemReward(LoyaltyReward reward) async {
    setState(() => _isRedeeming = true);
    final success = await _loyaltyService.redeemReward(rewardId: reward.id);
    setState(() => _isRedeeming = false);

    if (success && mounted) {
      await _loadData();
      _showSnackBar(
        '🎉 Reward Redeemed! You redeemed ${reward.name} for ${reward.coinCost} DineCoins!',
      );
    } else if (mounted) {
      _showSnackBar(
        "Cannot Redeem: You don't have enough DineCoins or an error occurred.",
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start ordering to earn DineCoins!',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        return _buildTransactionItem(tx);
      },
    );
  }

  Widget _buildTransactionItem(LoyaltyTransaction tx) {
    final color = tx.isCredit ? const Color(0xFF11998e) : const Color(0xFFff6b6b);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tx.typeIcon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  tx.typeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (tx.expiryDate != null)
                  Text(
                    'Expires: ${DateFormat('MMM d, yyyy').format(tx.expiryDate!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade400,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${tx.isCredit ? '+' : ''}${tx.amount}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM d').format(tx.createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1a1a2e),
      ),
    );
  }
}

// ─── Loading Skeleton ───────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _skeletonBox(height: 100)),
            const SizedBox(width: 12),
            Expanded(child: _skeletonBox(height: 100)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _skeletonBox(height: 100)),
            const SizedBox(width: 12),
            Expanded(child: _skeletonBox(height: 100)),
          ],
        ),
        const SizedBox(height: 24),
        _skeletonBox(height: 24, width: 150),
        const SizedBox(height: 12),
        ...List.generate(4, (_) => _skeletonBox(height: 56, margin: const EdgeInsets.only(bottom: 8))),
      ],
    );
  }

  Widget _skeletonBox({
    required double height,
    double? width,
    EdgeInsets? margin,
  }) {
    return Container(
      height: height,
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}