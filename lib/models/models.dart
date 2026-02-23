import 'package:flutter/foundation.dart';

@immutable
class Subcategory {
  final int id;
  final String name;
  final int categoryId;

  const Subcategory({
    required this.id,
    required this.name,
    required this.categoryId,
  });
}

@immutable
class Category {
  final int id;
  final String name;
  final List<Subcategory> subcategories;

  const Category({
    required this.id,
    required this.name,
    required this.subcategories,
  });
}

@immutable
class ExpenseEntry {
  final int id;
  final DateTime date;
  final String category;
  final String subcategory;
  final double amount;
  final bool isEvent;
  final String? eventName;
  final DateTime? eventStart;
  final DateTime? eventEnd;

  const ExpenseEntry({
    required this.id,
    required this.date,
    required this.category,
    required this.subcategory,
    required this.amount,
    required this.isEvent,
    this.eventName,
    this.eventStart,
    this.eventEnd,
  });
}

@immutable
class IncomeEntry {
  final int id;
  final DateTime date;
  final String category;
  final String subcategory;
  final double amount;

  const IncomeEntry({
    required this.id,
    required this.date,
    required this.category,
    required this.subcategory,
    required this.amount,
  });
}

@immutable
class EventSummary {
  final String name;
  final DateTime start;
  final DateTime end;
  final double total;
  final int count;

  const EventSummary({
    required this.name,
    required this.start,
    required this.end,
    required this.total,
    required this.count,
  });

  String get key =>
      '${name.trim().toLowerCase()}|${start.toIso8601String()}|${end.toIso8601String()}';
}

@immutable
class DashboardSummary {
  final double monthIncome;
  final double monthExpense;
  final double net;
  final double last7;
  final double yearToDate;

  const DashboardSummary({
    required this.monthIncome,
    required this.monthExpense,
    required this.net,
    required this.last7,
    required this.yearToDate,
  });
}

@immutable
class TotalsRow {
  final String label;
  final double amount;

  const TotalsRow({required this.label, required this.amount});
}

@immutable
class ApplianceEntry {
  final int id;
  final String name;
  final double price;
  final DateTime purchaseDate;
  final DateTime? warrantyExpiry;
  final int? depreciationYears;

  const ApplianceEntry({
    required this.id,
    required this.name,
    required this.price,
    required this.purchaseDate,
    this.warrantyExpiry,
    this.depreciationYears,
  });
}

@immutable
class MetalAssetEntry {
  final int id;
  final String metalType;
  final double weightGrams;
  final DateTime entryDate;

  const MetalAssetEntry({
    required this.id,
    required this.metalType,
    required this.weightGrams,
    required this.entryDate,
  });
}

@immutable
class LandAssetEntry {
  final int id;
  final String location;
  final double areaSize;
  final double pricePerUnit;
  final DateTime entryDate;

  const LandAssetEntry({
    required this.id,
    required this.location,
    required this.areaSize,
    required this.pricePerUnit,
    required this.entryDate,
  });
}

@immutable
class FixedDepositEntry {
  final int id;
  final String name;
  final double principal;
  final double rate;
  final int tenureDays;
  final DateTime depositDate;
  final DateTime maturityDate;
  final String status;

  const FixedDepositEntry({
    required this.id,
    required this.name,
    required this.principal,
    required this.rate,
    required this.tenureDays,
    required this.depositDate,
    required this.maturityDate,
    required this.status,
  });
}

@immutable
class LicPolicyEntry {
  final int id;
  final String policyName;
  final double premiumAmount;
  final String premiumFrequency;
  final DateTime? lastPremiumDate;
  final DateTime maturityDate;
  final double maturityAmount;

  const LicPolicyEntry({
    required this.id,
    required this.policyName,
    required this.premiumAmount,
    required this.premiumFrequency,
    required this.lastPremiumDate,
    required this.maturityDate,
    required this.maturityAmount,
  });
}
