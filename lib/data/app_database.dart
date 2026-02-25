import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }
    _db = await _open();
    return _db!;
  }

  Future<String> get dbPath async {
    if (kIsWeb) {
      return 'tracker_mobile_web.db';
    }
    final dir = await getDatabasesPath();
    return '$dir/tracker_mobile.db';
  }

  Future<Database> _open() async {
    final path = await dbPath;
    return openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedDefaults(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db);
        await _ensureColumns(db);
        await _seedDefaults(db);
      },
      onOpen: (db) async {
        await _createTables(db);
        await _ensureColumns(db);
        await _seedDefaults(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS subcategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        UNIQUE(name, category_id),
        FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        subcategory_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        amount REAL NOT NULL,
        travel INTEGER DEFAULT 0,
        trip_name TEXT,
        trip_start TEXT,
        trip_end TEXT,
        FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE RESTRICT,
        FOREIGN KEY(subcategory_id) REFERENCES subcategories(id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS income_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS income_subcategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        UNIQUE(name, category_id),
        FOREIGN KEY(category_id) REFERENCES income_categories(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS income (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        subcategory_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        amount REAL NOT NULL,
        FOREIGN KEY(category_id) REFERENCES income_categories(id) ON DELETE RESTRICT,
        FOREIGN KEY(subcategory_id) REFERENCES income_subcategories(id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS appliances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        purchase_date TEXT NOT NULL,
        warranty_expiry TEXT,
        depreciation_years INTEGER
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS asset_prices (
        key TEXT PRIMARY KEY,
        value REAL NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS metal_assets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        metal_type TEXT NOT NULL,
        weight_grams REAL NOT NULL,
        entry_date TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS land_assets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        location TEXT NOT NULL,
        area_size REAL NOT NULL,
        price_per_unit REAL NOT NULL,
        entry_date TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fixed_deposits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        principal REAL NOT NULL,
        rate REAL NOT NULL,
        tenure_days INTEGER NOT NULL,
        deposit_date TEXT NOT NULL,
        maturity_date TEXT NOT NULL,
        status TEXT DEFAULT 'active'
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS lic_policies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        policy_name TEXT NOT NULL,
        premium_amount REAL NOT NULL,
        premium_frequency TEXT NOT NULL,
        last_premium_date TEXT,
        maturity_date TEXT NOT NULL,
        maturity_amount REAL NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_income_date ON income(date);',
    );
  }

  Future<void> _ensureColumns(Database db) async {
    Future<List<Map<String, Object?>>> tableInfo(String table) async {
      return db.rawQuery('PRAGMA table_info(' + table + ');');
    }

    Future<bool> hasColumn(String table, String column) async {
      final info = await tableInfo(table);
      return info.any((r) => (r['name'] as String?) == column);
    }

    Future<void> ensure(String table, String column, String definition) async {
      final exists = await hasColumn(table, column);
      if (!exists) {
        await db.execute(
          'ALTER TABLE ' +
              table +
              ' ADD COLUMN ' +
              column +
              ' ' +
              definition +
              ';',
        );
      }
    }

    await ensure('expenses', 'travel', 'INTEGER DEFAULT 0');
    await ensure('expenses', 'trip_name', 'TEXT');
    await ensure('expenses', 'trip_start', 'TEXT');
    await ensure('expenses', 'trip_end', 'TEXT');
    await ensure('expenses', 'category_id', 'INTEGER');
    await ensure('expenses', 'subcategory_id', 'INTEGER');

    await ensure('income', 'category_id', 'INTEGER');
    await ensure('income', 'subcategory_id', 'INTEGER');

    await ensure('fixed_deposits', 'tenure_days', 'INTEGER DEFAULT 365');
    await ensure('fixed_deposits', 'status', "TEXT DEFAULT 'active'");

    await ensure('land_assets', 'entry_date', 'TEXT');

    // Compatibility migration for legacy DBs that stored text category columns.
    Future<int> resolveCategoryId(String name, {required bool income}) async {
      final categoryTable = income ? 'income_categories' : 'categories';
      final rows = await db.query(
        categoryTable,
        columns: ['id'],
        where: 'LOWER(name)=LOWER(?)',
        whereArgs: [name.trim()],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first['id'] as int;
      }
      return db.insert(categoryTable, {'name': name.trim()});
    }

    Future<int> resolveSubcategoryId(
      int categoryId,
      String name, {
      required bool income,
    }) async {
      final table = income ? 'income_subcategories' : 'subcategories';
      final rows = await db.query(
        table,
        columns: ['id'],
        where: 'category_id=? AND LOWER(name)=LOWER(?)',
        whereArgs: [categoryId, name.trim()],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first['id'] as int;
      }
      return db.insert(table, {'name': name.trim(), 'category_id': categoryId});
    }

    final hasExpenseTextCategory = await hasColumn('expenses', 'category');
    final hasExpenseTextSubcategory = await hasColumn(
      'expenses',
      'subcategory',
    );
    if (hasExpenseTextCategory && hasExpenseTextSubcategory) {
      final rows = await db.query(
        'expenses',
        columns: [
          'id',
          'category',
          'subcategory',
          'category_id',
          'subcategory_id',
        ],
        where:
            '(category_id IS NULL OR category_id=0 OR subcategory_id IS NULL OR subcategory_id=0) AND category IS NOT NULL AND subcategory IS NOT NULL',
      );
      for (final row in rows) {
        final category = (row['category'] as String?)?.trim() ?? '';
        final subcategory = (row['subcategory'] as String?)?.trim() ?? '';
        if (category.isEmpty || subcategory.isEmpty) continue;
        final categoryId = await resolveCategoryId(category, income: false);
        final subcategoryId = await resolveSubcategoryId(
          categoryId,
          subcategory,
          income: false,
        );
        await db.update(
          'expenses',
          {'category_id': categoryId, 'subcategory_id': subcategoryId},
          where: 'id=?',
          whereArgs: [row['id']],
        );
      }
    }

    final hasIncomeTextCategory = await hasColumn('income', 'category');
    final hasIncomeTextSubcategory = await hasColumn('income', 'subcategory');
    if (hasIncomeTextCategory && hasIncomeTextSubcategory) {
      final rows = await db.query(
        'income',
        columns: [
          'id',
          'category',
          'subcategory',
          'category_id',
          'subcategory_id',
        ],
        where:
            '(category_id IS NULL OR category_id=0 OR subcategory_id IS NULL OR subcategory_id=0) AND category IS NOT NULL AND subcategory IS NOT NULL',
      );
      for (final row in rows) {
        final category = (row['category'] as String?)?.trim() ?? '';
        final subcategory = (row['subcategory'] as String?)?.trim() ?? '';
        if (category.isEmpty || subcategory.isEmpty) continue;
        final categoryId = await resolveCategoryId(category, income: true);
        final subcategoryId = await resolveSubcategoryId(
          categoryId,
          subcategory,
          income: true,
        );
        await db.update(
          'income',
          {'category_id': categoryId, 'subcategory_id': subcategoryId},
          where: 'id=?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  Future<void> _seedDefaults(Database db) async {
    try {
      final rows = await db.query(
        'app_settings',
        columns: ['value'],
        where: 'key=?',
        whereArgs: ['disable_default_seed'],
        limit: 1,
      );
      if (rows.isNotEmpty && rows.first['value'] == '1') {
        return;
      }
    } catch (_) {
      // If settings table is unavailable, continue with defaults.
    }
    const expenseDefaults = <String, List<String>>{
      'Essentials': [
        'Vegetables',
        'Fruits',
        'Milk/Curd/Dairy',
        'Rice',
        'Oil',
        'Spices',
        'Flour',
        'Sugar',
        'Dhal',
        'Nuts',
        'Water',
        'Egg',
      ],
      'Transport': ['Cab', 'Bus', 'Bike services/etc', 'Petrol'],
      'Eating out': ['Snacks', 'Meals', 'Tea/Coffee'],
      'Apparel': ['Shirts/Pants', 'Inner wear', 'Footwear'],
      'Bathroom': ['Shampoo', 'Soap', 'Tooth paste', 'Detergents'],
      'Recharge': ['Mobile Recharge', 'Internet'],
      'Home appliances/Electronics/ Services': [
        'Labor',
        'Materials',
        'Utensils',
      ],
      'Miscellaneous': ['Stationary', 'Phenoyl', 'License sticks'],
      'Health': ['Medicine', 'Doctor'],
      'Electricity': ['Current Bill'],
      'Tax': ['Tax'],
    };

    const incomeDefaults = <String, List<String>>{
      'Salary': ['Salary'],
      'Rent': ['Thalavai', 'Bharath', 'Coimbatore', 'Chandra'],
      'Other sources': ['Miscellaneous', 'Welfare', 'Insurance'],
    };

    for (final entry in expenseDefaults.entries) {
      final catId = await db.insert('categories', {
        'name': entry.key,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final id = catId == 0
          ? (await db.query(
                  'categories',
                  columns: ['id'],
                  where: 'name=?',
                  whereArgs: [entry.key],
                  limit: 1,
                )).first['id']
                as int
          : catId;
      for (final sub in entry.value) {
        await db.insert('subcategories', {
          'name': sub,
          'category_id': id,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }

    for (final entry in incomeDefaults.entries) {
      final catId = await db.insert('income_categories', {
        'name': entry.key,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final id = catId == 0
          ? (await db.query(
                  'income_categories',
                  columns: ['id'],
                  where: 'name=?',
                  whereArgs: [entry.key],
                  limit: 1,
                )).first['id']
                as int
          : catId;
      for (final sub in entry.value) {
        await db.insert('income_subcategories', {
          'name': sub,
          'category_id': id,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }

    await db.insert('asset_prices', {
      'key': 'gold_price',
      'value': 14400.0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('asset_prices', {
      'key': 'silver_price',
      'value': 345.0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> databaseSizeBytes() async {
    final db = await database;
    final pageCount =
        Sqflite.firstIntValue(await db.rawQuery('PRAGMA page_count;')) ?? 0;
    final pageSize =
        Sqflite.firstIntValue(await db.rawQuery('PRAGMA page_size;')) ?? 0;
    return pageCount * pageSize;
  }
}
