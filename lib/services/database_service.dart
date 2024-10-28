import 'dart:async';
import 'package:postgres/postgres.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static PostgreSQLConnection? _connection;
  
  factory DatabaseService() => _instance;
  
  DatabaseService._internal();
  
  Future<PostgreSQLConnection> get connection async {
    if (_connection == null || _connection!.isClosed) {
      _connection = await _createConnection();
    }
    return _connection!;
  }

  Future<PostgreSQLConnection> _createConnection() async {
    // Create a connection with appropriate settings for Neon
    final connection = PostgreSQLConnection(
      dotenv.env['DB_HOST'] ?? '',  // Neon host
      int.parse(dotenv.env['DB_PORT'] ?? '5432'),
      dotenv.env['DB_NAME'] ?? '',
      username: dotenv.env['DB_USERNAME'],
      password: dotenv.env['DB_PASSWORD'],
      useSSL: true,  // Required for Neon
      timeoutInSeconds: 30,  // Adjusted timeout
      allowClearTextPassword: true,  // Required for some Neon connections
      timeZone: 'UTC',
      queryTimeoutInSeconds: 30,  // Query timeout
      // connectionTimeoutInSeconds: 30,  // Initial connection timeout
      replicationMode: ReplicationMode.none,  // Not needed for basic connection
    );

    try {
      await connection.open();
      print('Database connected successfully');
      
      // Test the connection
      await connection.query('SELECT 1');
      
      await _ensureTablesExist(connection);
      return connection;
    } catch (e) {
      print('Failed to connect to database: $e');
      if (!connection.isClosed) {
        await connection.close();
      }
      throw Exception('Failed to connect to database: $e');
    }
  }

  Future<void> _ensureTablesExist(PostgreSQLConnection connection) async {
    try {
      final result = await connection.query(
        '''
        SELECT EXISTS (
          SELECT 1 
          FROM information_schema.tables 
          WHERE table_name = 'labels'
        );
        '''
      );

      final tablesExist = result.first[0] as bool;
      if (!tablesExist) {
        print('Tables do not exist. Creating database schema...');
        await _createDatabaseSchema(connection);
      }
    } catch (e) {
      print('Error checking/creating tables: $e');
      throw Exception('Failed to ensure tables exist: $e');
    }
  }

  Future<void> _createDatabaseSchema(PostgreSQLConnection connection) async {
    try {
      // Execute schema creation in a transaction
      await connection.transaction((ctx) async {
        await ctx.query('''
          CREATE TABLE IF NOT EXISTS labels (
            id SERIAL PRIMARY KEY,
            label_type VARCHAR(50) NOT NULL,
            label_id VARCHAR(255) NOT NULL,
            check_in TIMESTAMP WITH TIME ZONE NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
          );

          CREATE INDEX IF NOT EXISTS idx_labels_type_id ON labels(label_type, label_id);
          CREATE INDEX IF NOT EXISTS idx_labels_check_in ON labels(check_in);

          CREATE TABLE IF NOT EXISTS fg_pallet_labels (
            id SERIAL PRIMARY KEY,
            label_id INTEGER REFERENCES labels(id) ON DELETE CASCADE,
            raw_value VARCHAR(255) NOT NULL,
            plate_id VARCHAR(50) NOT NULL,
            work_order VARCHAR(50) NOT NULL,
            check_in TIMESTAMP WITH TIME ZONE NOT NULL
          );

          CREATE INDEX IF NOT EXISTS idx_fg_pallet_raw_value ON fg_pallet_labels(raw_value);
          CREATE INDEX IF NOT EXISTS idx_fg_pallet_check_in ON fg_pallet_labels(check_in);

          CREATE TABLE IF NOT EXISTS roll_labels (
            id SERIAL PRIMARY KEY,
            label_id INTEGER REFERENCES labels(id) ON DELETE CASCADE,
            roll_id VARCHAR(50) NOT NULL,
            check_in TIMESTAMP WITH TIME ZONE NOT NULL
          );

          CREATE INDEX IF NOT EXISTS idx_roll_roll_id ON roll_labels(roll_id);
          CREATE INDEX IF NOT EXISTS idx_roll_check_in ON roll_labels(check_in);

          CREATE TABLE IF NOT EXISTS fg_location_labels (
            id SERIAL PRIMARY KEY,
            label_id INTEGER REFERENCES labels(id) ON DELETE CASCADE,
            location_id VARCHAR(50) NOT NULL,
            check_in TIMESTAMP WITH TIME ZONE NOT NULL
          );

          CREATE INDEX IF NOT EXISTS idx_fg_location_location_id ON fg_location_labels(location_id);
          CREATE INDEX IF NOT EXISTS idx_fg_location_check_in ON fg_location_labels(check_in);

          CREATE TABLE IF NOT EXISTS paper_roll_location_labels (
            id SERIAL PRIMARY KEY,
            label_id INTEGER REFERENCES labels(id) ON DELETE CASCADE,
            location_id VARCHAR(50) NOT NULL,
            check_in TIMESTAMP WITH TIME ZONE NOT NULL
          );

          CREATE INDEX IF NOT EXISTS idx_paper_roll_location_id ON paper_roll_location_labels(location_id);
          CREATE INDEX IF NOT EXISTS idx_paper_roll_check_in ON paper_roll_location_labels(check_in);
        ''');
      });

      print('Database schema created successfully');
    } catch (e) {
      print('Error creating database schema: $e');
      throw Exception('Failed to create database schema: $e');
    }
  }

  Future<void> closeConnection() async {
    if (_connection != null && !_connection!.isClosed) {
      await _connection!.close();
    }
  }
}