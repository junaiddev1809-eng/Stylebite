class EarningsOverviewResponseModel {
  const EarningsOverviewResponseModel({
    required this.summary,
    required this.earningBreakdownPreview,
    required this.recentWithdrawals,
  });

  final EarningsSummaryModel summary;
  final List<EarningTransactionModel> earningBreakdownPreview;
  final List<EarningsWithdrawalModel> recentWithdrawals;

  factory EarningsOverviewResponseModel.fromJson(Map<String, dynamic> json) {
    return EarningsOverviewResponseModel(
      summary: EarningsSummaryModel.fromJson(
        (json['summary'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      earningBreakdownPreview:
          ((json['earning_breakdown_preview'] as List?) ?? const [])
              .whereType<Map>()
              .map(
                (item) => EarningTransactionModel.fromJson(
                  item.cast<String, dynamic>(),
                ),
              )
              .toList(growable: false),
      recentWithdrawals: ((json['recent_withdrawals'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                EarningsWithdrawalModel.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}

class EarningsSummaryModel {
  const EarningsSummaryModel({
    required this.currencyCode,
    required this.availableBalance,
    required this.pendingBalance,
    required this.contestWins,
    required this.lastMonthIncomeChangePercent,
    required this.lastMonthIncomeChangeDisplay,
    required this.lastMonthIncomeAmount,
    required this.adEarnings,
  });

  final String currencyCode;
  final double availableBalance;
  final double pendingBalance;
  final int contestWins;
  final double lastMonthIncomeChangePercent;
  final String lastMonthIncomeChangeDisplay;
  final int lastMonthIncomeAmount;
  final double adEarnings;

  factory EarningsSummaryModel.fromJson(Map<String, dynamic> json) {
    return EarningsSummaryModel(
      currencyCode: (json['currency_code'] ?? 'PKR').toString(),
      availableBalance: _asDouble(json['available_balance']),
      pendingBalance: _asDouble(json['pending_balance']),
      contestWins: _asInt(json['contest_wins']),
      lastMonthIncomeChangePercent: _asDouble(
        json['last_month_income_change_percent'],
      ),
      lastMonthIncomeChangeDisplay:
          (json['last_month_income_change_display'] ?? '').toString(),
      lastMonthIncomeAmount: _asInt(json['last_month_income_amount']),
      adEarnings: _asDouble(json['lifetime_earned']),
    );
  }

  EarningsSummaryModel copyWith({
    String? currencyCode,
    double? availableBalance,
    double? pendingBalance,
    int? contestWins,
    double? lastMonthIncomeChangePercent,
    String? lastMonthIncomeChangeDisplay,
    int? lastMonthIncomeAmount,
    double? adEarnings,
  }) {
    return EarningsSummaryModel(
      currencyCode: currencyCode ?? this.currencyCode,
      availableBalance: availableBalance ?? this.availableBalance,
      pendingBalance: pendingBalance ?? this.pendingBalance,
      contestWins: contestWins ?? this.contestWins,
      lastMonthIncomeChangePercent:
          lastMonthIncomeChangePercent ?? this.lastMonthIncomeChangePercent,
      lastMonthIncomeChangeDisplay:
          lastMonthIncomeChangeDisplay ?? this.lastMonthIncomeChangeDisplay,
      lastMonthIncomeAmount:
          lastMonthIncomeAmount ?? this.lastMonthIncomeAmount,
      adEarnings: adEarnings ?? this.adEarnings,
    );
  }
}

class EarningTransactionModel {
  const EarningTransactionModel({
    required this.id,
    required this.transactionType,
    required this.sourceType,
    required this.sourceId,
    required this.status,
    required this.title,
    required this.reason,
    required this.note,
    required this.currencyCode,
    required this.amount,
    required this.amountDisplay,
    required this.amountDirection,
    required this.processedAt,
    required this.createdAt,
  });

  final int id;
  final String transactionType;
  final String sourceType;
  final int? sourceId;
  final String status;
  final String title;
  final String reason;
  final String? note;
  final String currencyCode;
  final double amount;
  final String amountDisplay;
  final String amountDirection;
  final String? processedAt;
  final String? createdAt;

  factory EarningTransactionModel.fromJson(Map<String, dynamic> json) {
    return EarningTransactionModel(
      id: _asInt(json['id']),
      transactionType: (json['transaction_type'] ?? '').toString(),
      sourceType: (json['source_type'] ?? '').toString(),
      sourceId: _asNullableInt(json['source_id']),
      status: (json['status'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      note: _asNullableString(json['note']),
      currencyCode: (json['currency_code'] ?? 'PKR').toString(),
      amount: _asDouble(json['amount']),
      amountDisplay: (json['amount_display'] ?? '').toString(),
      amountDirection: (json['amount_direction'] ?? '').toString(),
      processedAt: _asNullableString(json['processed_at']),
      createdAt: _asNullableString(json['created_at']),
    );
  }
}

class EarningsWithdrawalModel {
  const EarningsWithdrawalModel({
    required this.id,
    required this.amount,
    required this.currencyCode,
    required this.amountDisplay,
    required this.method,
    required this.title,
    required this.accountRef,
    required this.status,
    required this.requestedAt,
    required this.processedAt,
    required this.failureReason,
  });

  final int id;
  final double amount;
  final String currencyCode;
  final String amountDisplay;
  final String method;
  final String title;
  final String accountRef;
  final String status;
  final String? requestedAt;
  final String? processedAt;
  final String? failureReason;

  factory EarningsWithdrawalModel.fromJson(Map<String, dynamic> json) {
    return EarningsWithdrawalModel(
      id: _asInt(json['id']),
      amount: _asDouble(json['amount']),
      currencyCode: (json['currency_code'] ?? 'PKR').toString(),
      amountDisplay: (json['amount_display'] ?? '').toString(),
      method: (json['method'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      accountRef: (json['account_ref'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      requestedAt: _asNullableString(json['requested_at']),
      processedAt: _asNullableString(json['processed_at']),
      failureReason: _asNullableString(json['failure_reason']),
    );
  }
}

class EarningsPaginationModel {
  const EarningsPaginationModel({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
    required this.hasMorePages,
  });

  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;
  final bool hasMorePages;

  factory EarningsPaginationModel.fromJson(Map<String, dynamic> json) {
    return EarningsPaginationModel(
      currentPage: _asInt(json['current_page'], fallback: 1),
      perPage: _asInt(json['per_page'], fallback: 10),
      total: _asInt(json['total']),
      lastPage: _asInt(json['last_page'], fallback: 1),
      hasMorePages: _asBool(json['has_more_pages']),
    );
  }
}

class EarningsBreakdownsResponseModel {
  const EarningsBreakdownsResponseModel({
    required this.breakdowns,
    required this.pagination,
  });

  final List<EarningTransactionModel> breakdowns;
  final EarningsPaginationModel pagination;

  factory EarningsBreakdownsResponseModel.fromJson(Map<String, dynamic> json) {
    return EarningsBreakdownsResponseModel(
      breakdowns: ((json['breakdowns'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                EarningTransactionModel.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false),
      pagination: EarningsPaginationModel.fromJson(
        (json['pagination'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
    );
  }
}

class EarningsWithdrawalsResponseModel {
  const EarningsWithdrawalsResponseModel({
    required this.withdrawals,
    required this.pagination,
  });

  final List<EarningsWithdrawalModel> withdrawals;
  final EarningsPaginationModel pagination;

  factory EarningsWithdrawalsResponseModel.fromJson(Map<String, dynamic> json) {
    return EarningsWithdrawalsResponseModel(
      withdrawals: ((json['withdrawals'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                EarningsWithdrawalModel.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false),
      pagination: EarningsPaginationModel.fromJson(
        (json['pagination'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
    );
  }
}

class EarningsWalletModel {
  const EarningsWalletModel({
    required this.currencyCode,
    required this.availableBalance,
    required this.pendingBalance,
  });

  final String currencyCode;
  final double availableBalance;
  final double pendingBalance;

  factory EarningsWalletModel.fromJson(Map<String, dynamic> json) {
    return EarningsWalletModel(
      currencyCode: (json['currency_code'] ?? 'PKR').toString(),
      availableBalance: _asDouble(json['available_balance']),
      pendingBalance: _asDouble(json['pending_balance']),
    );
  }
}

class WithdrawalRequestResponseModel {
  const WithdrawalRequestResponseModel({
    required this.wallet,
    required this.withdrawal,
    required this.transaction,
  });

  final EarningsWalletModel wallet;
  final EarningsWithdrawalModel withdrawal;
  final EarningTransactionModel transaction;

  factory WithdrawalRequestResponseModel.fromJson(Map<String, dynamic> json) {
    return WithdrawalRequestResponseModel(
      wallet: EarningsWalletModel.fromJson(
        (json['wallet'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      withdrawal: EarningsWithdrawalModel.fromJson(
        (json['withdrawal'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      transaction: EarningTransactionModel.fromJson(
        (json['transaction'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
    );
  }
}

class AdEligibilityModel {
  const AdEligibilityModel({
    required this.isEligible,
    required this.adsEnabled,
    required this.requirements,
    this.config,
  });

  final bool isEligible;
  final bool adsEnabled;
  final List<AdRequirementModel> requirements;
  final AdConfigModel? config;

  factory AdEligibilityModel.fromJson(Map<String, dynamic> json) {
    final List<AdRequirementModel> requirements = [];

    // Case 1: Requirements is a list of objects
    if (json['requirements'] is List) {
      requirements.addAll(
        (json['requirements'] as List).whereType<Map>().map(
              (item) =>
                  AdRequirementModel.fromJson(item.cast<String, dynamic>()),
            ),
      );
    } 
    
    // Case 2: Requirements is a Map
    else if (json['requirements'] is Map) {
      final reqMap = json['requirements'] as Map;
      reqMap.forEach((key, value) {
        if (value is Map) {
          requirements.add(
            AdRequirementModel.fromJson(
              value.cast<String, dynamic>(),
              typeFromKey: key.toString(),
            ),
          );
        }
      });
    }

    // Case 3: Flat keys from the specific log provided
    if (requirements.isEmpty) {
      if (json.containsKey('followers')) {
        requirements.add(AdRequirementModel(
          type: 'followers',
          label: 'Followers',
          current: _asDouble(json['followers']),
          threshold: _asDouble(json['min_followers'] ?? json['followers_threshold'] ?? 0),
          isPassed: _asBool(json['meets_followers'] ?? json['followers_passed'] ?? false),
        ));
      }
      if (json.containsKey('watch_hours')) {
        requirements.add(AdRequirementModel(
          type: 'watch_hours',
          label: 'Watch Hours',
          current: _asDouble(json['watch_hours']),
          threshold: _asDouble(json['min_watch_hours'] ?? json['watch_hours_threshold'] ?? 0),
          isPassed: _asBool(json['meets_watch_hours'] ?? json['watch_hours_passed'] ?? false),
        ));
      }
    }

    return AdEligibilityModel(
      isEligible: _asBool(json['eligible'] ?? json['is_eligible'] ?? json['status']),
      adsEnabled: _asBool(json['ads_enabled']),
      requirements: requirements,
      config: json['config'] != null ? AdConfigModel.fromJson(json['config']) : null,
    );
  }
}

class AdConfigModel {
  const AdConfigModel({
    required this.reelOwnerSharePercent,
    required this.midReelTriggerPercent,
  });

  final double reelOwnerSharePercent;
  final double midReelTriggerPercent;

  factory AdConfigModel.fromJson(Map<String, dynamic> json) {
    return AdConfigModel(
      reelOwnerSharePercent: _asDouble(json['reel_owner_share_percent']),
      midReelTriggerPercent: _asDouble(json['mid_reel_trigger_percent']),
    );
  }
}

class AdRequirementModel {
  const AdRequirementModel({
    required this.type,
    required this.label,
    required this.current,
    required this.threshold,
    required this.isPassed,
  });

  final String type;
  final String label;
  final double current;
  final double threshold;
  final bool isPassed;

  factory AdRequirementModel.fromJson(
    Map<String, dynamic> json, {
    String? typeFromKey,
  }) {
    final label = (json['label'] ?? json['title'] ?? '').toString();
    final type = (json['type'] ?? typeFromKey ?? '').toString();

    return AdRequirementModel(
      type: type,
      label: label.isNotEmpty ? label : _formatLabel(type),
      current: _asDouble(json['current'] ?? json['value'] ?? json['count']),
      threshold: _asDouble(json['threshold'] ?? json['goal'] ?? json['target'] ?? json['limit'] ?? json['min']),
      isPassed: _asBool(
        json['is_passed'] ??
            json['passed'] ??
            json['is_success'] ??
            json['success'] ??
            json['meets'] ??
            (json['status']?.toString().toLowerCase() == 'pass'),
      ),
    );
  }

  static String _formatLabel(String type) {
    if (type.isEmpty) return 'Requirement';
    final words = type.split('_');
    return words.map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  double get progress =>
      threshold > 0 ? (current / threshold).clamp(0.0, 1.0) : 0.0;

  String get remainingText {
    if (isPassed) return 'Requirement met';
    final remaining = (threshold - current).clamp(0.0, double.infinity);
    
    String count;
    if (type.toLowerCase().contains('watch')) {
      if (remaining >= 10) {
        count = remaining.toStringAsFixed(0);
      } else if (remaining >= 1) {
        count = remaining.toStringAsFixed(1);
      } else {
        count = remaining.toStringAsFixed(2);
      }
    } else {
      count = remaining.toInt().toString();
    }
    
    return 'Need $count more ${label.toLowerCase()}';
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? fallback;
  }
  return fallback;
}

int? _asNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }
  return _asInt(value);
}

String? _asNullableString(dynamic value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty || normalized == 'null') {
    return null;
  }
  return normalized;
}

bool _asBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'pass' ||
      normalized == 'passed' ||
      normalized == 'success' ||
      normalized == 'yes';
}
