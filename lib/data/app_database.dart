import 'dart:io';

import 'package:path_provider/path_provider.dart';
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
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/tracker_mobile.db';
  }

  Future<Database> _open() async {
    final path = await dbPath;
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedDefaults(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      );
    ''');

    await db.execute('''
      CREATE TABLE subcategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        UNIQUE(name, category_id),
        FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE expenses (
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
      CREATE TABLE income_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      );
    ''');

    await db.execute('''
      CREATE TABLE income_subcategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        UNIQUE(name, category_id),
        FOREIGN KEY(category_id) REFERENCES income_categories(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE income (
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
      CREATE TABLE appliances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        purchase_date TEXT NOT NULL,
        warranty_expiry TEXT,
        depreciation_years INTEGER
      );
    ''');

    await db.execute('''
      CREATE TABLE asset_prices (
        key TEXT PRIMARY KEY,
        value REAL NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE metal_assets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        metal_type TEXT NOT NULL,
        weight_grams REAL NOT NULL,
        entry_date TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE land_assets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        location TEXT NOT NULL,
        area_size REAL NOT NULL,
        price_per_unit REAL NOT NULL,
        entry_date TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE fixed_deposits (
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
      CREATE TABLE lic_policies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        policy_name TEXT NOT NULL,
        premium_amount REAL NOT NULL,
        premium_frequency TEXT NOT NULL,
        last_premium_date TEXT,
        maturity_date TEXT NOT NULL,
        maturity_amount REAL NOT NULL
      );
    ''');

    await db.execute('CREATE INDEX idx_expenses_date ON expenses(date);');
    await db.execute('CREATE INDEX idx_income_date ON income(date);');
  }

  Future<void> _seedDefaults(Database db) async {
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
    final file = File(await dbPath);
    if (!await file.exists()) {
      return 0;
    }
    return file.length();
  }
}
