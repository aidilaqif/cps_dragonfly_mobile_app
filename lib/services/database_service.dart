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
    final connection = PostgreSQLConnection(
      dotenv.env['DB_HOST'] ?? '',
      int.parse(dotenv.env['DB_PORT'] ?? '5432'),
      dotenv.env['DB_NAME'] ?? '',
      username: dotenv.env['DB_USERNAME'],
      password: dotenv.env['DB_PASSWORD'],
      useSSL: true,
      // sslMode: PostgresSQLMode.require
    );

    try {
      await connection.open();
      print('Database connected successfully');
      return connection;
    } catch (e) {
      print('Failed to connect to database: $e');
      throw Exception('Failed to connect to database: $e');
    }
  }

  Future<void> closeConnection() async {
    if (_connection != null && !_connection!.isClosed) {
      await _connection!.close();
    }
  }
}