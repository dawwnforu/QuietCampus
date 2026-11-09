import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'model.dart';
import 'sync_engine.dart';

class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage(this.storage);
  final FlutterSecureStorage storage;
  static const key = 'quiet-campus.auth';
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() => storage.containsKey(key: key);
  @override
  Future<String?> accessToken() => storage.read(key: key);
  @override
  Future<void> persistSession(String persistSessionString) =>
      storage.write(key: key, value: persistSessionString);
  @override
  Future<void> removePersistedSession() => storage.delete(key: key);
}

class Cloud implements SyncRemote {
  Cloud(this.client, this.owner);
  final SupabaseClient client;
  final String owner;
  static const bucket = 'vault-attachments';

  Future<Map<String, dynamic>?> vault() async =>
      await client.from('vaults').select().eq('owner_id', owner).maybeSingle();
  Future<Map<String, dynamic>> putVault(
    Map<String, dynamic> envelope,
    int revision,
  ) async => Map<String, dynamic>.from(
    await client.rpc(
      'put_vault',
      params: {'p_envelope': envelope, 'p_base_revision': revision},
    ) as Map,
  );

  @override
  Future<void> upload(String id, Uint8List ciphertext) async {
    await client.storage
        .from(bucket)
        .uploadBinary(
          '$owner/$id.bin',
          ciphertext,
          fileOptions: const FileOptions(
            contentType: 'application/octet-stream',
            upsert: true,
          ),
        )
        .timeout(const Duration(seconds: 30));
  }

  Future<Uint8List> download(String id) =>
      client.storage.from(bucket).download('$owner/$id.bin');

  @override
  Future<Map<String, dynamic>> write(SealedRecord record) async =>
      Map<String, dynamic>.from(
        await client.rpc(
          'write_record',
          params: {
            'p_id': record.id,
            'p_base_revision': record.revision,
            'p_mutation_id': record.mutationId,
            'p_ciphertext': record.ciphertext,
            'p_deleted': record.deleted,
          },
        ) as Map,
      );

  @override
  Future<List<SealedRecord>> readAll() async {
    if (await client.rpc('account_active') != true) throw StateError('账号删除处理中');
    final result = <SealedRecord>[];
    for (var offset = 0; ; offset += 500) {
      final page = await client
          .from('records')
          .select()
          .eq('owner_id', owner)
          .order('id')
          .range(offset, offset + 499);
      result.addAll(page.map(SealedRecord.fromRemote));
      if (page.length < 500) return result;
    }
  }

  RealtimeChannel subscribe(void Function() onChange) => client
      .channel('records:$owner')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'records',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'owner_id',
          value: owner,
        ),
        callback: (_) => onChange(),
      )
      .subscribe();
}
