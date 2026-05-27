import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class InvoiceDatabase {
  static final InvoiceDatabase instance = InvoiceDatabase._init();
  static Database? _db;
  InvoiceDatabase._init();

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB('invoices.db');
    return _db!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 1,
      onConfigure: _configureDB,
      onCreate: _createDB,
    );
  }

  Future<void> _configureDB(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT,
        vat_number TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT UNIQUE NOT NULL,
        customer_id INTEGER,
        customer_name TEXT,
        date TEXT NOT NULL,
        due_date TEXT,
        status TEXT,
        subtotal REAL NOT NULL DEFAULT 0,
        tax REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE SET NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        description TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0,
        tax REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        FOREIGN KEY(invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        method TEXT,
        reference TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      );
    ''');
  }

  Future<int> insertInvoice(Map<String, dynamic> invoice, List<Map<String, dynamic>> items) async {
    final database = await db;
    return await database.transaction<int>((txn) async {
      final id = await txn.insert('invoices', invoice);
      for (final it in items) {
        final item = Map<String, dynamic>.from(it);
        item.remove('id');
        item['invoice_id'] = id;
        await txn.insert('invoice_items', item);
      }
      return id;
    });
  }

  Future<Map<String, dynamic>?> getInvoiceByNumber(String invoiceNumber) async {
    final database = await db;
    final rows = await database.query('invoices', where: 'invoice_number = ?', whereArgs: [invoiceNumber]);
    if (rows.isEmpty) return null;
    final invoice = Map<String, dynamic>.from(rows.first);
    final rawId = invoice['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;
    final items = await database.query('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
    invoice['items'] = items;
    return invoice;
  }

  Future<Map<String, dynamic>?> getInvoice(int id) async {
    final database = await db;
    final invoices = await database.query('invoices', where: 'id = ?', whereArgs: [id]);
    if (invoices.isEmpty) return null;
    final items = await database.query('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
    final invoice = Map<String, dynamic>.from(invoices.first);
    invoice['items'] = items;
    return invoice;
  }

  Future<List<Map<String, dynamic>>> getAllInvoices() async {
    final database = await db;
    return await database.query('invoices', orderBy: 'date DESC');
  }

  Future close() async {
    final database = await db;
    await database.close();
  }
}
