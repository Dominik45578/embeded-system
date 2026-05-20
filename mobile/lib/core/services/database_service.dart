import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../model/device_event.dart';

class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'lockly_events.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE events (
            id TEXT PRIMARY KEY,
            message TEXT,
            timestamp TEXT,
            source TEXT
          )
        ''');
      },
    );
  }

  /// Zapisuje pojedyncze zdarzenie do bazy SQLite
  Future<void> insertEvent(DeviceEvent event) async {
    final db = await database;
    await db.insert(
      'events',
      {
        'id': event.id,
        'message': event.message,
        'timestamp': event.timestamp.toIso8601String(),
        'source': event.source.name,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Pobiera spagowaną listę zdarzeń z bazy przy użyciu LIMIT i OFFSET
  Future<List<DeviceEvent>> getPagedEvents(int limit, int offset) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) {
      return DeviceEvent(
        id: map['id'] as String,
        message: map['message'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        source: EventSource.values.firstWhere(
              (e) => e.name == map['source'],
          orElse: () => EventSource.bluetooth,
        ),
      );
    }).toList();
  }
}