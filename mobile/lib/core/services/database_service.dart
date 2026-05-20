import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../model/device.dart';
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
    final path = join(dbPath, 'lockly.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE events (
            id TEXT PRIMARY KEY,
            message TEXT,
            timestamp TEXT,
            source TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE devices (
            id TEXT PRIMARY KEY,
            name TEXT,
            isBlocked INTEGER,
            isConnected INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE devices (
              id TEXT PRIMARY KEY,
              name TEXT,
              isBlocked INTEGER,
              isConnected INTEGER
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE devices ADD COLUMN name TEXT');
          await db.execute('ALTER TABLE devices ADD COLUMN isBlocked INTEGER');
          await db.execute('ALTER TABLE devices ADD COLUMN isConnected INTEGER');
        }
      },
    );
  }

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

  Future<void> insertDevice(Device device) async {
    final db = await database;
    await db.insert(
      'devices',
      {
        'id': device.id,
        'name': device.name,
        'isBlocked': device.isBlocked ? 1 : 0,
        'isConnected': 0, // Assume not connected when inserting
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteDevice(String deviceId) async {
    final db = await database;
    await db.delete(
      'devices',
      where: 'id = ?',
      whereArgs: [deviceId],
    );
  }

  Future<List<Device>> getSavedDevices() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('devices');
    return maps.map((map) {
      return Device(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        isBlocked: (map['isBlocked'] as int? ?? 0) == 1,
      );
    }).toList();
  }

  Future<void> updateDeviceConnectionState(String deviceId, bool isConnected) async {
    final db = await database;
    await db.update(
      'devices',
      {'isConnected': isConnected ? 1 : 0},
      where: 'id = ?',
      whereArgs: [deviceId],
    );
  }
}