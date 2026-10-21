enum CreateContestType { oneVsOne, city }

class ContestTypeOption {
  const ContestTypeOption({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
  });

  final CreateContestType type;
  final String title;
  final String description;
  final String icon;
}

class ContestRuleCardModel {
  const ContestRuleCardModel({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final String icon;
}
