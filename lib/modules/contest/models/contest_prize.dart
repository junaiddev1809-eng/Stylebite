class ContestPrize {
  const ContestPrize({
    required this.place,
    required this.title,
    required this.amount,
    required this.winner,
    required this.winnerUserId,
  });

  final int place;
  final String title;
  final double amount;
  final String winner;
  final int winnerUserId;

  String get placeLabel {
    final mod100 = place % 100;
    if (mod100 >= 11 && mod100 <= 13) {
      return '${place}th';
    }
    return switch (place % 10) {
      1 => '${place}st',
      2 => '${place}nd',
      3 => '${place}rd',
      _ => '${place}th',
    };
  }

  String get amountLabel {
    final whole = amount % 1 == 0;
    return 'PKR ${whole ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2)}';
  }

  factory ContestPrize.fromJson(Map<String, dynamic> json) {
    return ContestPrize(
      place: _readInt(json['place']),
      title: _readString(json['title']),
      amount: _readDouble(json['amount']),
      winner: _readString(json['winner']),
      winnerUserId: _readInt(json['winner_user_id']),
    );
  }
}

List<ContestPrize> readContestPrizes(dynamic value) {
  if (value is! List<dynamic>) {
    return const <ContestPrize>[];
  }
  return value
      .whereType<Map<String, dynamic>>()
      .map(ContestPrize.fromJson)
      .where((prize) => prize.place > 0)
      .toList(growable: false);
}

String contestPlaceStanding(int place) {
  if (place <= 0) {
    return '';
  }
  final mod100 = place % 100;
  final suffix = mod100 >= 11 && mod100 <= 13
      ? 'th'
      : switch (place % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$place$suffix place';
}

String contestWinnerTitle(int place) {
  return switch (place) {
    1 => 'Winner',
    2 => 'Runner-up',
    3 => 'Third place',
    _ => contestPlaceStanding(place),
  };
}

String contestPrizeSubtitle({
  required List<ContestPrize> prizes,
  required bool hasReward,
  required double rewardAmount,
}) {
  if (prizes.isEmpty) {
    if (!hasReward) {
      return 'Community contest';
    }
    final whole = rewardAmount % 1 == 0;
    return 'Winner gets ${whole ? rewardAmount.toStringAsFixed(0) : rewardAmount.toStringAsFixed(2)}';
  }

  final total = prizes.fold<double>(0, (sum, prize) => sum + prize.amount);
  final whole = total % 1 == 0;
  final money = whole ? total.toStringAsFixed(0) : total.toStringAsFixed(2);
  if (prizes.length == 1) {
    return total > 0 ? '1 winner · PKR $money' : '1 winner';
  }
  return total > 0
      ? '${prizes.length} winners · PKR $money prize pool'
      : '${prizes.length} winners';
}

int _readInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse('${value ?? ''}') ?? 0;
}

double _readDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

String _readString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return '';
  return text;
}
