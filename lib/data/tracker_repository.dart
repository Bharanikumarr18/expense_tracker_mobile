import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../utils/formatters.dart';
import 'app_database.dart';

class TrackerRepository {
  TrackerRepository({AppDatabase? db})
    : _dbProvider = db ?? AppDatabase.instance;

  final AppDatabase _dbProvider;

  Future<Database> get _db async => _dbProvider.database;

  DateTime _asDate(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }
    if (value is DateTime) {
      return value;
    }
    final raw = value.toString();
    try {
      return DateTime.parse(raw);
    } catch (_) {
      try {
        return parseDateFlexible(raw);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  double _asDouble(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }

  Future<List<Category>> _loadCategoryTree({
    required String categoryTable,
    required String subcategoryTable,
  }) async {
    final db = await _db;
    final cats = await db.query(categoryTable, orderBy: 'name COLLATE NOCASE');
    final subs = await db.query(
      subcategoryTable,
      orderBy: 'name COLLATE NOCASE',
    );

    final subsByCategory = <int, List<Subcategory>>{};
    for (final row in subs) {
      final catId = row['category_id'] as int;
      subsByCategory
          .putIfAbsent(catId, () => <Subcategory>[])
          .add(
            Subcategory(
              id: row['id'] as int,
              name: row['name'] as String,
              categoryId: catId,
            ),
          );
    }

    return cats
        .map(
          (row) => Category(
            id: row['id'] as int,
            name: row['name'] as String,
            subcategories:
                subsByCategory[row['id'] as int] ?? const <Subcategory>[],
          ),
        )
        .toList();
  }

  Future<List<Category>> getExpenseCategories() {
    return _loadCategoryTree(
      categoryTable: 'categories',
      subcategoryTable: 'subcategories',
    );
  }

  Future<List<Category>> getIncomeCategories() {
    return _loadCategoryTree(
      categoryTable: 'income_categories',
      subcategoryTable: 'income_subcategories',
    );
  }

  Future<int> addExpenseCategory(String name) async {
    final db = await _db;
    return db.insert('categories', {
      'name': name.trim(),
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> addExpenseSubcategory(int categoryId, String name) async {
    final db = await _db;
    return db.insert('subcategories', {
      'name': name.trim(),
      'category_id': categoryId,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> addIncomeCategory(String name) async {
    final db = await _db;
    return db.insert('income_categories', {
      'name': name.trim(),
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> addIncomeSubcategory(int categoryId, String name) async {
    final db = await _db;
    return db.insert('income_subcategories', {
      'name': name.trim(),
      'category_id': categoryId,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<String?> getAppSetting(String key) async {
    final db = await _db;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key=?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setAppSetting(String key, String value) async {
    final db = await _db;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteAppSetting(String key) async {
    final db = await _db;
    await db.delete('app_settings', where: 'key=?', whereArgs: [key]);
  }

  Future<int> _resolveCategoryIdByName(
    String name, {
    required bool income,
    bool autoCreate = false,
  }) async {
    final db = await _db;
    final categoryTable = income ? 'income_categories' : 'categories';
    final rows = await db.query(
      categoryTable,
      columns: ['id', 'name'],
      where: 'LOWER(name)=LOWER(?)',
      whereArgs: [name.trim()],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return rows.first['id'] as int;
    }
    if (!autoCreate) {
      throw Exception('Category not found: $name');
    }
    return db.insert(categoryTable, {
      'name': name.trim(),
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> _resolveSubcategoryIdByName(
    int categoryId,
    String subName, {
    required bool income,
    bool autoCreate = false,
  }) async {
    final db = await _db;
    final subcategoryTable = income ? 'income_subcategories' : 'subcategories';

    final rows = await db.query(
      subcategoryTable,
      columns: ['id'],
      where: 'category_id=? AND LOWER(name)=LOWER(?)',
      whereArgs: [categoryId, subName.trim()],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return rows.first['id'] as int;
    }

    if (!autoCreate) {
      throw Exception('Subcategory not found: $subName');
    }

    return db.insert(subcategoryTable, {
      'category_id': categoryId,
      'name': subName.trim(),
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<void> addExpense({
    required DateTime date,
    required int categoryId,
    required int subcategoryId,
    required double amount,
    bool isEvent = false,
    String? eventName,
    DateTime? eventStart,
    DateTime? eventEnd,
    bool mergeSameDay = true,
  }) async {
    final db = await _db;

    final isoDate = formatIsoDate(date);

    String mergeWhere = 'date=? AND category_id=? AND subcategory_id=?';
    final mergeArgs = <Object?>[isoDate, categoryId, subcategoryId];

    if (isEvent) {
      mergeWhere +=
          ' AND travel=1 AND trip_name=? AND trip_start=? AND trip_end=?';
      mergeArgs.addAll([
        eventName?.trim() ?? '',
        formatIsoDate(eventStart ?? date),
        formatIsoDate(eventEnd ?? date),
      ]);
    } else {
      mergeWhere += ' AND (travel=0 OR travel IS NULL)';
    }

    if (mergeSameDay) {
      final existing = await db.query(
        'expenses',
        columns: ['id', 'amount'],
        where: mergeWhere,
        whereArgs: mergeArgs,
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final row = existing.first;
        await db.update(
          'expenses',
          {'amount': _asDouble(row['amount']) + amount},
          where: 'id=?',
          whereArgs: [row['id']],
        );
        return;
      }
    }

    await db.insert('expenses', {
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'date': isoDate,
      'amount': amount,
      'travel': isEvent ? 1 : 0,
      'trip_name': isEvent ? (eventName ?? '').trim() : null,
      'trip_start': isEvent ? formatIsoDate(eventStart ?? date) : null,
      'trip_end': isEvent ? formatIsoDate(eventEnd ?? date) : null,
    });
  }

  Future<void> addExpenseByNames({
    required DateTime date,
    required String category,
    required String subcategory,
    required double amount,
    bool autoCreateMissing = true,
    bool isEvent = false,
    String? eventName,
    DateTime? eventStart,
    DateTime? eventEnd,
  }) async {
    final catId = await _resolveCategoryIdByName(
      category,
      income: false,
      autoCreate: autoCreateMissing,
    );
    final subId = await _resolveSubcategoryIdByName(
      catId,
      subcategory,
      income: false,
      autoCreate: autoCreateMissing,
    );
    await addExpense(
      date: date,
      categoryId: catId,
      subcategoryId: subId,
      amount: amount,
      isEvent: isEvent,
      eventName: eventName,
      eventStart: eventStart,
      eventEnd: eventEnd,
    );
  }

  Future<List<ExpenseEntry>> getExpenses({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];

    if (from != null) {
      where.add('date>=?');
      args.add(formatIsoDate(from));
    }
    if (to != null) {
      where.add('date<=?');
      args.add(formatIsoDate(to));
    }

    final rows = await db.rawQuery('''
      SELECT
        e.id,
        e.date,
        e.amount,
        e.travel,
        e.trip_name,
        e.trip_start,
        e.trip_end,
        c.name AS category,
        s.name AS subcategory
      FROM expenses e
      JOIN categories c ON c.id=e.category_id
      JOIN subcategories s ON s.id=e.subcategory_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY e.date DESC, e.id DESC
      ${limit == null ? '' : 'LIMIT $limit'};
    ''', args);

    return rows
        .map(
          (r) => ExpenseEntry(
            id: r['id'] as int,
            date: _asDate(r['date']),
            category: r['category'] as String,
            subcategory: r['subcategory'] as String,
            amount: _asDouble(r['amount']),
            isEvent: (r['travel'] as int? ?? 0) == 1,
            eventName: r['trip_name'] as String?,
            eventStart: r['trip_start'] == null
                ? null
                : _asDate(r['trip_start']),
            eventEnd: r['trip_end'] == null ? null : _asDate(r['trip_end']),
          ),
        )
        .toList();
  }

  Future<void> updateExpense(
    int id, {
    required DateTime date,
    required double amount,
  }) async {
    final db = await _db;
    await db.update(
      'expenses',
      {'date': formatIsoDate(date), 'amount': amount},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> deleteExpense(int id) async {
    final db = await _db;
    await db.delete('expenses', where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteExpenses(List<int> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final db = await _db;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete('expenses', where: 'id IN ($placeholders)', whereArgs: ids);
  }

  Future<DashboardSummary> getDashboardSummary(DateTime now) async {
    final db = await _db;
    final monthFrom = monthStart(now);
    final monthTo = monthEnd(now);
    final ytdFrom = yearStart(now);
    final ytdTo = now;
    final last7From = now.subtract(const Duration(days: 6));

    final monthExpense =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT CAST(COALESCE(SUM(amount),0) AS INT) FROM expenses WHERE date BETWEEN ? AND ?;',
            [formatIsoDate(monthFrom), formatIsoDate(monthTo)],
          ),
        )?.toDouble() ??
        0;

    final monthIncome =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT CAST(COALESCE(SUM(amount),0) AS INT) FROM income WHERE date BETWEEN ? AND ?;',
            [formatIsoDate(monthFrom), formatIsoDate(monthTo)],
          ),
        )?.toDouble() ??
        0;

    final last7 =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT CAST(COALESCE(SUM(amount),0) AS INT) FROM expenses WHERE date BETWEEN ? AND ?;',
            [formatIsoDate(last7From), formatIsoDate(now)],
          ),
        )?.toDouble() ??
        0;

    final ytd =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT CAST(COALESCE(SUM(amount),0) AS INT) FROM expenses WHERE date BETWEEN ? AND ?;',
            [formatIsoDate(ytdFrom), formatIsoDate(ytdTo)],
          ),
        )?.toDouble() ??
        0;

    return DashboardSummary(
      monthIncome: monthIncome,
      monthExpense: monthExpense,
      net: monthIncome - monthExpense,
      last7: last7,
      yearToDate: ytd,
    );
  }

  Future<List<TotalsRow>> expenseTotalsByCategory({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT c.name AS label, SUM(e.amount) AS total
      FROM expenses e
      JOIN categories c ON c.id=e.category_id
      WHERE e.date BETWEEN ? AND ?
      GROUP BY c.name
      ORDER BY total DESC, c.name;
      ''',
      [formatIsoDate(from), formatIsoDate(to)],
    );

    return rows
        .map(
          (r) => TotalsRow(
            label: r['label'] as String,
            amount: _asDouble(r['total']),
          ),
        )
        .toList();
  }

  Future<List<TotalsRow>> expenseTotalsBySubcategory({
    required DateTime from,
    required DateTime to,
    String? category,
  }) async {
    final db = await _db;
    final args = <Object?>[formatIsoDate(from), formatIsoDate(to)];
    var categoryClause = '';
    if (category != null && category.trim().isNotEmpty && category != 'All') {
      categoryClause = ' AND c.name=?';
      args.add(category.trim());
    }

    final rows = await db.rawQuery('''
      SELECT s.name AS label, SUM(e.amount) AS total
      FROM expenses e
      JOIN categories c ON c.id=e.category_id
      JOIN subcategories s ON s.id=e.subcategory_id
      WHERE e.date BETWEEN ? AND ? $categoryClause
      GROUP BY s.name
      ORDER BY total DESC, s.name;
      ''', args);

    return rows
        .map(
          (r) => TotalsRow(
            label: r['label'] as String,
            amount: _asDouble(r['total']),
          ),
        )
        .toList();
  }

  Future<double> expenseTotal({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) AS total FROM expenses WHERE date BETWEEN ? AND ?;',
      [formatIsoDate(from), formatIsoDate(to)],
    );
    return _asDouble(rows.first['total']);
  }

  Future<List<ExpenseEntry>> dailyBuy(DateTime day) async {
    return getExpenses(from: day, to: day);
  }

  Future<void> addIncome({
    required DateTime date,
    required int categoryId,
    required int subcategoryId,
    required double amount,
    bool mergeSameDay = true,
  }) async {
    final db = await _db;

    if (mergeSameDay) {
      final existing = await db.query(
        'income',
        columns: ['id', 'amount'],
        where: 'date=? AND category_id=? AND subcategory_id=?',
        whereArgs: [formatIsoDate(date), categoryId, subcategoryId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        await db.update(
          'income',
          {'amount': _asDouble(existing.first['amount']) + amount},
          where: 'id=?',
          whereArgs: [existing.first['id']],
        );
        return;
      }
    }

    await db.insert('income', {
      'date': formatIsoDate(date),
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'amount': amount,
    });
  }

  Future<void> addIncomeByNames({
    required DateTime date,
    required String category,
    required String subcategory,
    required double amount,
    bool autoCreateMissing = true,
  }) async {
    final catId = await _resolveCategoryIdByName(
      category,
      income: true,
      autoCreate: autoCreateMissing,
    );
    final subId = await _resolveSubcategoryIdByName(
      catId,
      subcategory,
      income: true,
      autoCreate: autoCreateMissing,
    );
    await addIncome(
      date: date,
      categoryId: catId,
      subcategoryId: subId,
      amount: amount,
    );
  }

  Future<List<IncomeEntry>> getIncomes({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('i.date>=?');
      args.add(formatIsoDate(from));
    }
    if (to != null) {
      where.add('i.date<=?');
      args.add(formatIsoDate(to));
    }

    final rows = await db.rawQuery('''
      SELECT i.id,i.date,i.amount,c.name AS category,s.name AS subcategory
      FROM income i
      JOIN income_categories c ON c.id=i.category_id
      JOIN income_subcategories s ON s.id=i.subcategory_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY i.date DESC, i.id DESC
      ${limit == null ? '' : 'LIMIT $limit'};
      ''', args);

    return rows
        .map(
          (r) => IncomeEntry(
            id: r['id'] as int,
            date: _asDate(r['date']),
            category: r['category'] as String,
            subcategory: r['subcategory'] as String,
            amount: _asDouble(r['amount']),
          ),
        )
        .toList();
  }

  Future<void> updateIncome(
    int id, {
    required DateTime date,
    required double amount,
  }) async {
    final db = await _db;
    await db.update(
      'income',
      {'date': formatIsoDate(date), 'amount': amount},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> deleteIncome(int id) async {
    final db = await _db;
    await db.delete('income', where: 'id=?', whereArgs: [id]);
  }

  Future<List<TotalsRow>> incomeTotalsByCategory({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT c.name AS label, SUM(i.amount) AS total
      FROM income i
      JOIN income_categories c ON c.id=i.category_id
      WHERE i.date BETWEEN ? AND ?
      GROUP BY c.name
      ORDER BY total DESC;
      ''',
      [formatIsoDate(from), formatIsoDate(to)],
    );

    return rows
        .map(
          (r) => TotalsRow(
            label: r['label'] as String,
            amount: _asDouble(r['total']),
          ),
        )
        .toList();
  }

  Future<List<TotalsRow>> incomeTotalsBySubcategory({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT s.name AS label, SUM(i.amount) AS total
      FROM income i
      JOIN income_subcategories s ON s.id=i.subcategory_id
      WHERE i.date BETWEEN ? AND ?
      GROUP BY s.name
      ORDER BY total DESC;
      ''',
      [formatIsoDate(from), formatIsoDate(to)],
    );

    return rows
        .map(
          (r) => TotalsRow(
            label: r['label'] as String,
            amount: _asDouble(r['total']),
          ),
        )
        .toList();
  }

  Future<double> incomeTotal({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) AS total FROM income WHERE date BETWEEN ? AND ?;',
      [formatIsoDate(from), formatIsoDate(to)],
    );
    return _asDouble(rows.first['total']);
  }

  Future<List<EventSummary>> getEvents() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        trip_name,
        trip_start,
        trip_end,
        COUNT(*) AS cnt,
        COALESCE(SUM(amount),0) AS total
      FROM expenses
      WHERE travel=1 AND trip_name IS NOT NULL AND trip_name <> ''
      GROUP BY trip_name, trip_start, trip_end
      ORDER BY COALESCE(trip_start, date) DESC, trip_name;
    ''');

    return rows
        .map(
          (r) => EventSummary(
            name: (r['trip_name'] as String?) ?? '',
            start: _asDate(r['trip_start']),
            end: _asDate(r['trip_end']),
            total: _asDouble(r['total']),
            count: (r['cnt'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  Future<List<ExpenseEntry>> getEventEntries(EventSummary event) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT e.id,e.date,e.amount,e.travel,e.trip_name,e.trip_start,e.trip_end,
             c.name AS category, s.name AS subcategory
      FROM expenses e
      JOIN categories c ON c.id=e.category_id
      JOIN subcategories s ON s.id=e.subcategory_id
      WHERE e.travel=1
        AND e.trip_name=?
        AND e.trip_start=?
        AND e.trip_end=?
      ORDER BY e.date DESC, e.id DESC;
      ''',
      [event.name, formatIsoDate(event.start), formatIsoDate(event.end)],
    );

    return rows
        .map(
          (r) => ExpenseEntry(
            id: r['id'] as int,
            date: _asDate(r['date']),
            category: r['category'] as String,
            subcategory: r['subcategory'] as String,
            amount: _asDouble(r['amount']),
            isEvent: true,
            eventName: r['trip_name'] as String?,
            eventStart: _asDate(r['trip_start']),
            eventEnd: _asDate(r['trip_end']),
          ),
        )
        .toList();
  }

  Future<void> updateEventMetadata({
    required EventSummary oldEvent,
    required String newName,
    required DateTime newStart,
    required DateTime newEnd,
  }) async {
    final db = await _db;
    await db.update(
      'expenses',
      {
        'trip_name': newName.trim(),
        'trip_start': formatIsoDate(newStart),
        'trip_end': formatIsoDate(newEnd),
      },
      where: 'travel=1 AND trip_name=? AND trip_start=? AND trip_end=?',
      whereArgs: [
        oldEvent.name,
        formatIsoDate(oldEvent.start),
        formatIsoDate(oldEvent.end),
      ],
    );
  }

  Future<void> unlinkEvent(EventSummary event) async {
    final db = await _db;
    await db.update(
      'expenses',
      {'travel': 0, 'trip_name': null, 'trip_start': null, 'trip_end': null},
      where: 'travel=1 AND trip_name=? AND trip_start=? AND trip_end=?',
      whereArgs: [
        event.name,
        formatIsoDate(event.start),
        formatIsoDate(event.end),
      ],
    );
  }

  Future<void> deleteEventWithEntries(EventSummary event) async {
    final db = await _db;
    await db.delete(
      'expenses',
      where: 'travel=1 AND trip_name=? AND trip_start=? AND trip_end=?',
      whereArgs: [
        event.name,
        formatIsoDate(event.start),
        formatIsoDate(event.end),
      ],
    );
  }

  Future<void> addAppliance({
    required String name,
    required double price,
    required DateTime purchaseDate,
    DateTime? warrantyExpiry,
    int? depreciationYears,
  }) async {
    final db = await _db;
    await db.insert('appliances', {
      'name': name.trim(),
      'price': price,
      'purchase_date': formatIsoDate(purchaseDate),
      'warranty_expiry': warrantyExpiry == null
          ? null
          : formatIsoDate(warrantyExpiry),
      'depreciation_years': depreciationYears,
    });
  }

  Future<List<ApplianceEntry>> getAppliances() async {
    final db = await _db;
    final rows = await db.query(
      'appliances',
      orderBy: 'purchase_date DESC, id DESC',
    );
    return rows
        .map(
          (r) => ApplianceEntry(
            id: r['id'] as int,
            name: r['name'] as String,
            price: _asDouble(r['price']),
            purchaseDate: _asDate(r['purchase_date']),
            warrantyExpiry: r['warranty_expiry'] == null
                ? null
                : _asDate(r['warranty_expiry']),
            depreciationYears: r['depreciation_years'] as int?,
          ),
        )
        .toList();
  }

  Future<void> deleteAppliance(int id) async {
    final db = await _db;
    await db.delete('appliances', where: 'id=?', whereArgs: [id]);
  }

  Future<Map<String, double>> getAssetPrices() async {
    final db = await _db;
    final rows = await db.query('asset_prices');
    final out = <String, double>{'gold_price': 14400, 'silver_price': 345};
    for (final r in rows) {
      out[r['key'] as String] = _asDouble(r['value']);
    }
    return out;
  }

  Future<void> saveAssetPrice(String key, double value) async {
    final db = await _db;
    await db.insert('asset_prices', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> addMetalAsset(
    String metalType,
    double weight,
    DateTime entryDate,
  ) async {
    final db = await _db;
    await db.insert('metal_assets', {
      'metal_type': metalType,
      'weight_grams': weight,
      'entry_date': formatIsoDate(entryDate),
    });
  }

  Future<List<MetalAssetEntry>> getMetalAssets() async {
    final db = await _db;
    final rows = await db.query(
      'metal_assets',
      orderBy: 'entry_date DESC, id DESC',
    );
    return rows
        .map(
          (r) => MetalAssetEntry(
            id: r['id'] as int,
            metalType: r['metal_type'] as String,
            weightGrams: _asDouble(r['weight_grams']),
            entryDate: _asDate(r['entry_date']),
          ),
        )
        .toList();
  }

  Future<void> deleteMetalAsset(int id) async {
    final db = await _db;
    await db.delete('metal_assets', where: 'id=?', whereArgs: [id]);
  }

  Future<void> addLandAsset(
    String location,
    double areaSize,
    double pricePerUnit,
    DateTime entryDate,
  ) async {
    final db = await _db;
    await db.insert('land_assets', {
      'location': location.trim(),
      'area_size': areaSize,
      'price_per_unit': pricePerUnit,
      'entry_date': formatIsoDate(entryDate),
    });
  }

  Future<List<LandAssetEntry>> getLandAssets() async {
    final db = await _db;
    final rows = await db.query(
      'land_assets',
      orderBy: 'entry_date DESC, id DESC',
    );
    return rows
        .map(
          (r) => LandAssetEntry(
            id: r['id'] as int,
            location: r['location'] as String,
            areaSize: _asDouble(r['area_size']),
            pricePerUnit: _asDouble(r['price_per_unit']),
            entryDate: _asDate(r['entry_date']),
          ),
        )
        .toList();
  }

  Future<void> deleteLandAsset(int id) async {
    final db = await _db;
    await db.delete('land_assets', where: 'id=?', whereArgs: [id]);
  }

  Future<void> addFixedDeposit({
    required String name,
    required double principal,
    required double rate,
    required int tenureDays,
    required DateTime depositDate,
  }) async {
    final db = await _db;
    final maturityDate = depositDate.add(Duration(days: max(1, tenureDays)));
    await db.insert('fixed_deposits', {
      'name': name.trim(),
      'principal': principal,
      'rate': rate,
      'tenure_days': tenureDays,
      'deposit_date': formatIsoDate(depositDate),
      'maturity_date': formatIsoDate(maturityDate),
      'status': 'active',
    });
  }

  Future<List<FixedDepositEntry>> getFixedDeposits() async {
    final db = await _db;
    final rows = await db.query(
      'fixed_deposits',
      orderBy: 'deposit_date DESC, id DESC',
    );
    return rows
        .map(
          (r) => FixedDepositEntry(
            id: r['id'] as int,
            name: r['name'] as String,
            principal: _asDouble(r['principal']),
            rate: _asDouble(r['rate']),
            tenureDays: r['tenure_days'] as int,
            depositDate: _asDate(r['deposit_date']),
            maturityDate: _asDate(r['maturity_date']),
            status: (r['status'] as String?) ?? 'active',
          ),
        )
        .toList();
  }

  Future<void> deleteFixedDeposit(int id) async {
    final db = await _db;
    await db.delete('fixed_deposits', where: 'id=?', whereArgs: [id]);
  }

  Future<void> addLicPolicy({
    required String policyName,
    required double premiumAmount,
    required String premiumFrequency,
    DateTime? lastPremiumDate,
    required DateTime maturityDate,
    required double maturityAmount,
  }) async {
    final db = await _db;
    await db.insert('lic_policies', {
      'policy_name': policyName.trim(),
      'premium_amount': premiumAmount,
      'premium_frequency': premiumFrequency,
      'last_premium_date': lastPremiumDate == null
          ? null
          : formatIsoDate(lastPremiumDate),
      'maturity_date': formatIsoDate(maturityDate),
      'maturity_amount': maturityAmount,
    });
  }

  Future<List<LicPolicyEntry>> getLicPolicies() async {
    final db = await _db;
    final rows = await db.query(
      'lic_policies',
      orderBy: 'maturity_date ASC, id DESC',
    );
    return rows
        .map(
          (r) => LicPolicyEntry(
            id: r['id'] as int,
            policyName: r['policy_name'] as String,
            premiumAmount: _asDouble(r['premium_amount']),
            premiumFrequency: r['premium_frequency'] as String,
            lastPremiumDate: r['last_premium_date'] == null
                ? null
                : _asDate(r['last_premium_date']),
            maturityDate: _asDate(r['maturity_date']),
            maturityAmount: _asDouble(r['maturity_amount']),
          ),
        )
        .toList();
  }

  Future<void> deleteLicPolicy(int id) async {
    final db = await _db;
    await db.delete('lic_policies', where: 'id=?', whereArgs: [id]);
  }

  Future<Map<String, double>> getAssetTotals() async {
    final db = await _db;
    final prices = await getAssetPrices();
    final goldPrice = prices['gold_price'] ?? 0;
    final silverPrice = prices['silver_price'] ?? 0;

    final metalRows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN lower(metal_type)='gold' THEN weight_grams ELSE 0 END),0) AS gold_w,
        COALESCE(SUM(CASE WHEN lower(metal_type)='silver' THEN weight_grams ELSE 0 END),0) AS silver_w
      FROM metal_assets;
    ''');

    final goldWeight = _asDouble(metalRows.first['gold_w']);
    final silverWeight = _asDouble(metalRows.first['silver_w']);
    final metalValue = goldWeight * goldPrice + silverWeight * silverPrice;

    final landRows = await db.rawQuery(
      'SELECT COALESCE(SUM(area_size * price_per_unit),0) AS total FROM land_assets;',
    );
    final landValue = _asDouble(landRows.first['total']);

    final fdRows = await db.rawQuery(
      'SELECT COALESCE(SUM(principal),0) AS total FROM fixed_deposits;',
    );
    final fdPrincipal = _asDouble(fdRows.first['total']);

    final licRows = await db.rawQuery(
      'SELECT COALESCE(SUM(maturity_amount),0) AS total FROM lic_policies;',
    );
    final licMaturity = _asDouble(licRows.first['total']);

    final total = metalValue + landValue + fdPrincipal + licMaturity;

    return {
      'metal': metalValue,
      'land': landValue,
      'fd': fdPrincipal,
      'lic': licMaturity,
      'total': total,
    };
  }

  Future<Map<String, dynamic>> getLongevityStatus() async {
    final db = await _db;

    final expenseCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM expenses;'),
        ) ??
        0;
    final incomeCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM income;'),
        ) ??
        0;
    final eventsCount =
        (await db.rawQuery('''
      SELECT COUNT(*) AS c FROM (
        SELECT trip_name, trip_start, trip_end
        FROM expenses
        WHERE travel=1 AND trip_name IS NOT NULL AND trip_name <> ''
        GROUP BY trip_name, trip_start, trip_end
      )
      ''')).first['c']
            as int? ??
        0;

    final sizeBytes = await _dbProvider.databaseSizeBytes();

    return {
      'expense_count': expenseCount,
      'income_count': incomeCount,
      'event_count': eventsCount,
      'db_size_bytes': sizeBytes,
    };
  }
}
