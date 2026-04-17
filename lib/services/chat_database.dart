import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/chat_message.dart';

/// 本地聊天记录 SQLite 存储（单例，按用户隔离数据库文件）
class ChatDatabase {
  static final ChatDatabase instance = ChatDatabase._();
  ChatDatabase._();

  Database? _db;
  int? _currentUserId;

  bool get isOpen => _db != null;

  // ===== 初始化 & 关闭 =====

  /// 登录后调用，打开当前用户的数据库
  Future<void> init(int userId) async {
    if (_db != null && _currentUserId == userId) return;
    await close();
    _currentUserId = userId;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'chat_$userId.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
    debugPrint('[ChatDB] Opened chat_$userId.db');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id            INTEGER PRIMARY KEY,
        client_msg_id TEXT,
        chat_type     TEXT NOT NULL,
        chat_id       INTEGER NOT NULL,
        user_id       INTEGER NOT NULL,
        user_code     TEXT NOT NULL DEFAULT '',
        nickname      TEXT NOT NULL DEFAULT '',
        avatar        TEXT NOT NULL DEFAULT '',
        msg_type      TEXT NOT NULL DEFAULT 'text',
        content       TEXT NOT NULL DEFAULT '',
        media_url     TEXT NOT NULL DEFAULT '',
        thumb_url     TEXT NOT NULL DEFAULT '',
        media_info    TEXT,
        mentions      TEXT NOT NULL DEFAULT '[]',
        user_type     INTEGER NOT NULL DEFAULT 0,
        send_status   INTEGER NOT NULL DEFAULT 0,
        error_code    TEXT,
        created_at    TEXT NOT NULL DEFAULT '',
        cached_at     INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_msg_chat ON messages(chat_type, chat_id, id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_msg_content ON messages(content)');
  }

  /// 登出时关闭
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _currentUserId = null;
  }

  // ===== 写操作 =====

  /// 插入或更新单条消息
  Future<void> upsertMessage(String chatType, int chatId, ChatMessageModel msg) async {
    if (_db == null || msg.id == null) return;
    await _db!.insert('messages', _toRow(chatType, chatId, msg),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 批量插入（事务）
  Future<void> batchUpsert(String chatType, int chatId, List<ChatMessageModel> messages) async {
    if (_db == null) return;
    final batch = _db!.batch();
    for (final msg in messages) {
      if (msg.id == null) continue;
      batch.insert('messages', _toRow(chatType, chatId, msg),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// 乐观消息确认：用 clientMsgId 匹配并更新服务端 id
  Future<void> confirmOptimisticMessage(String clientMsgId, int serverId) async {
    if (_db == null) return;
    await _db!.update(
      'messages',
      {'id': serverId, 'send_status': 0},
      where: 'client_msg_id = ?',
      whereArgs: [clientMsgId],
    );
  }

  // ===== 读操作 =====

  /// 加载某会话的消息（分页，按 id 降序）
  Future<List<ChatMessageModel>> getMessages({
    required String chatType,
    required int chatId,
    int? beforeId,
    int limit = 50,
    DateTime? afterTime,
  }) async {
    if (_db == null) return [];
    final where = StringBuffer('chat_type = ? AND chat_id = ?');
    final args = <dynamic>[chatType, chatId];
    if (beforeId != null) {
      where.write(' AND id < ?');
      args.add(beforeId);
    }
    if (afterTime != null) {
      where.write(' AND created_at > ?');
      args.add(afterTime.toIso8601String());
    }
    final rows = await _db!.query(
      'messages',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'id ASC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  /// 搜索消息（跨会话或指定会话）
  Future<List<MessageSearchResult>> searchMessages({
    required String keyword,
    String? chatType,
    int? chatId,
    int limit = 30,
  }) async {
    if (_db == null || keyword.isEmpty) return [];
    final where = StringBuffer("content LIKE ? AND msg_type = 'text'");
    final args = <dynamic>['%$keyword%'];
    if (chatType != null && chatId != null) {
      where.write(' AND chat_type = ? AND chat_id = ?');
      args.addAll([chatType, chatId]);
    }
    final rows = await _db!.query(
      'messages',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'id DESC',
      limit: limit,
    );
    // 按会话分组
    final grouped = <String, List<ChatMessageModel>>{};
    for (final row in rows) {
      final key = '${row['chat_type']}_${row['chat_id']}';
      grouped.putIfAbsent(key, () => []).add(_fromRow(row));
    }
    return grouped.entries.map((e) {
      final parts = e.key.split('_');
      return MessageSearchResult(
        chatType: parts[0],
        chatId: int.parse(parts[1]),
        messages: e.value,
        matchCount: e.value.length,
      );
    }).toList();
  }

  // ===== 缓存管理 =====

  /// 获取每个会话的存储统计
  Future<List<ConversationStorageInfo>> getStorageStats() async {
    if (_db == null) return [];
    final rows = await _db!.rawQuery('''
      SELECT chat_type, chat_id,
             COUNT(*) as msg_count,
             SUM(LENGTH(content) + LENGTH(media_url) + LENGTH(thumb_url)) as total_bytes
      FROM messages
      GROUP BY chat_type, chat_id
      ORDER BY total_bytes DESC
    ''');
    return rows.map((r) => ConversationStorageInfo(
      chatType: r['chat_type'] as String,
      chatId: r['chat_id'] as int,
      messageCount: r['msg_count'] as int,
      estimatedBytes: (r['total_bytes'] as int?) ?? 0,
    )).toList();
  }

  /// 删除单条消息
  Future<void> deleteMessage(String chatType, int chatId, int messageId) async {
    if (_db == null) return;
    await _db!.delete('messages',
        where: 'chat_type = ? AND chat_id = ? AND id = ?',
        whereArgs: [chatType, chatId, messageId]);
  }

  /// 清空某个会话的消息
  Future<void> clearConversation(String chatType, int chatId) async {
    if (_db == null) return;
    await _db!.delete('messages',
        where: 'chat_type = ? AND chat_id = ?',
        whereArgs: [chatType, chatId]);
  }

  /// 清空所有消息
  Future<void> clearAll() async {
    if (_db == null) return;
    await _db!.delete('messages');
  }

  /// 数据库文件大小（字节）
  Future<int> getDatabaseSize() async {
    if (_currentUserId == null) return 0;
    final dir = await getApplicationDocumentsDirectory();
    final file = p.join(dir.path, 'chat_$_currentUserId.db');
    try {
      final f = File(file);
      if (await f.exists()) return await f.length();
      return 0;
    } catch (_) {
      return 0;
    }
  }

  // ===== 内部工具 =====

  Map<String, dynamic> _toRow(String chatType, int chatId, ChatMessageModel msg) {
    return {
      'id': msg.id,
      'client_msg_id': msg.clientMsgId,
      'chat_type': chatType,
      'chat_id': chatId,
      'user_id': msg.userId,
      'user_code': msg.userCode,
      'nickname': msg.nickname,
      'avatar': msg.avatar,
      'msg_type': msg.msgTypeStr,
      'content': msg.content,
      'media_url': msg.mediaUrl,
      'thumb_url': msg.thumbUrl,
      'media_info': msg.mediaInfo != null ? jsonEncode(msg.mediaInfo) : null,
      'mentions': jsonEncode(msg.mentions),
      'user_type': msg.userType,
      'send_status': msg.sendStatus.index,
      'error_code': msg.errorCode,
      'created_at': msg.createdAt,
      'cached_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  ChatMessageModel _fromRow(Map<String, dynamic> row) {
    Map<String, dynamic>? mediaInfo;
    if (row['media_info'] != null) {
      try { mediaInfo = jsonDecode(row['media_info'] as String); } catch (_) {}
    }
    List<int> mentions = const [];
    try {
      final list = jsonDecode(row['mentions'] as String? ?? '[]') as List;
      mentions = list.map((e) => e as int).toList();
    } catch (_) {}

    return ChatMessageModel(
      id: row['id'] as int?,
      userId: row['user_id'] as int,
      userCode: row['user_code'] as String? ?? '',
      nickname: row['nickname'] as String? ?? '',
      avatar: row['avatar'] as String? ?? '',
      msgType: ChatMessageModel.parseMsgType(row['msg_type']),
      content: row['content'] as String? ?? '',
      mediaUrl: row['media_url'] as String? ?? '',
      thumbUrl: row['thumb_url'] as String? ?? '',
      mediaInfo: mediaInfo,
      mentions: mentions,
      userType: row['user_type'] as int? ?? 0,
      sendStatus: SendStatus.values[(row['send_status'] as int?) ?? 0],
      errorCode: row['error_code'] as String?,
      createdAt: row['created_at'] as String? ?? '',
      clientMsgId: row['client_msg_id'] as String?,
    );
  }
}

/// 搜索结果
class MessageSearchResult {
  final String chatType;
  final int chatId;
  final List<ChatMessageModel> messages;
  final int matchCount;

  MessageSearchResult({
    required this.chatType,
    required this.chatId,
    required this.messages,
    required this.matchCount,
  });
}

/// 会话存储信息
class ConversationStorageInfo {
  final String chatType;
  final int chatId;
  final int messageCount;
  final int estimatedBytes;

  ConversationStorageInfo({
    required this.chatType,
    required this.chatId,
    required this.messageCount,
    required this.estimatedBytes,
  });
}
