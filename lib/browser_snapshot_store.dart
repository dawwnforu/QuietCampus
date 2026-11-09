import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'snapshot_store.dart';

/// A single atomic compare-and-swap snapshot; no plaintext or key is persisted.
class BrowserSnapshotStore implements SnapshotStore {
  BrowserSnapshotStore._(this._db);
  final web.IDBDatabase _db;

  static Future<BrowserSnapshotStore> open({
    String name = 'quiet-campus-browser-v1',
  }) async {
    final completed = Completer<BrowserSnapshotStore>();
    final request = web.window.indexedDB.open(name, 1);
    request.onupgradeneeded = ((web.Event _) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains('archive')) {
        db.createObjectStore('archive');
      }
    }).toJS;
    request.onblocked = ((web.Event _) {
      if (!completed.isCompleted) {
        completed.completeError(StateError('其他窗口正在使用不同存储版本，请关闭后重试；原资料未改动'));
      }
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completed.isCompleted) {
        completed.completeError(StateError('浏览器存储不可用或版本不受支持；请保留站点数据'));
      }
    }).toJS;
    request.onsuccess = ((web.Event _) {
      final db = request.result as web.IDBDatabase;
      if (completed.isCompleted) {
        db.close();
        return;
      }
      db.onversionchange = ((web.Event _) => db.close()).toJS;
      if (!db.objectStoreNames.contains('archive')) {
        db.close();
        completed.completeError(StateError('本地存储结构不完整，请勿清除站点数据'));
      } else {
        completed.complete(BrowserSnapshotStore._(db));
      }
    }).toJS;
    return completed.future;
  }

  static StoredSnapshot? _decode(JSAny? value) {
    final raw = value?.dartify();
    if (raw == null) return null;
    if (raw is! String || raw.length > maxArchiveBytes + 32) {
      throw const FormatException('本地资料格式或大小不受支持，原资料已保留');
    }
    return StoredSnapshot.decode(raw);
  }

  @override
  Future<StoredSnapshot?> read() {
    final result = Completer<StoredSnapshot?>();
    final transaction = _db.transaction('archive'.toJS);
    StoredSnapshot? snapshot;
    Object? failure;
    final request = transaction.objectStore('archive').get('current'.toJS);
    request.onsuccess = ((web.Event _) {
      try {
        snapshot = _decode(request.result);
      } catch (error) {
        failure = error;
      }
    }).toJS;
    transaction.oncomplete = ((web.Event _) {
      if (failure != null) {
        result.completeError(failure!);
      } else {
        result.complete(snapshot);
      }
    }).toJS;
    transaction.onabort = ((web.Event _) {
      if (!result.isCompleted) {
        result.completeError(StateError('读取本地资料失败，原资料未改动'));
      }
    }).toJS;
    return result.future;
  }

  @override
  Future<int> commit(Uint8List bytes, {required int baseRevision}) async {
    if (baseRevision < 0 || bytes.length > maxArchiveBytes) {
      throw const FormatException('浏览器版加密档案上限为 64 MiB，请先备份；原资料未改动');
    }
    final value = StoredSnapshot(baseRevision + 1, bytes).encode();
    final result = Completer<int>();
    final transaction = _db.transaction(
      'archive'.toJS,
      'readwrite',
      web.IDBTransactionOptions(durability: 'strict'),
    );
    final store = transaction.objectStore('archive');
    Object? failure;
    final request = store.get('current'.toJS);
    request.onsuccess = ((web.Event _) {
      try {
        final current = _decode(request.result);
        if ((current?.revision ?? 0) != baseRevision) {
          throw StateError('另一个页面已修改档案。当前输入仍保留，请先导出当前备份并重新打开，不会覆盖新版本。');
        }
        store.put(value.toJS, 'current'.toJS);
      } catch (error) {
        failure = error;
        transaction.abort();
      }
    }).toJS;
    transaction.onerror = ((web.Event _) {
      failure ??= StateError('保存失败，可能是浏览器空间不足或存储被限制；原资料未改动，请保留当前输入');
    }).toJS;
    transaction.onabort = ((web.Event _) {
      if (!result.isCompleted) {
        result.completeError(failure ?? StateError('保存未完成，原资料未改动'));
      }
    }).toJS;
    transaction.oncomplete = ((web.Event _) => result.complete(
      baseRevision + 1,
    )).toJS;
    return result.future;
  }

  void close() => _db.close();
}
