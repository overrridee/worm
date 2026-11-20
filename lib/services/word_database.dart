import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/word_item.dart';

/// Paket içindeki hazır `assets/worm.db` SQLite veritabanını cihazın yerel
/// veritabanı dizinine kopyalayıp standalone şekilde okuyan hafif servis.
class WordDatabase {
  static const String _dbFileName = 'worm.db';
  static const String _assetPath = 'assets/worm.db';

  Future<List<WordItem>> loadAllWords() async {
    final dbPath = p.join(await getDatabasesPath(), _dbFileName);
    final assetBytes = await rootBundle.load(_assetPath);
    final bytes = assetBytes.buffer.asUint8List(
      assetBytes.offsetInBytes,
      assetBytes.lengthInBytes,
    );

    final file = File(dbPath);
    final needsCopy = !await file.exists() || await file.length() != bytes.length;
    if (needsCopy) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    }

    final db = await openDatabase(dbPath, readOnly: true);
    try {
      final rows = await db.query(
        'words',
        orderBy: 'order_index ASC',
      );
      return rows.map(WordItem.fromMap).toList(growable: false);
    } finally {
      await db.close();
    }
  }
}
