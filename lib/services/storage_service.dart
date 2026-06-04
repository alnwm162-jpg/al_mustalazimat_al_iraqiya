import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

final SupabaseClient _supabaseClient = Supabase.instance.client;

Future<String?> uploadImageToSupabase({
  required Uint8List bytes,
  required String bucket,
  required String folder,
  required String fileName,
}) async {
  try {
    final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    final storagePath = '$folder/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
    await _supabaseClient.storage.from(bucket).uploadBinary(storagePath, bytes);
    final publicUrl = _supabaseClient.storage.from(bucket).getPublicUrl(storagePath);
    if (publicUrl.isEmpty) return null;
    return publicUrl;
  } catch (error, stackTrace) {
    print('uploadImageToSupabase error: $error');
    print(stackTrace);
    return null;
  }
}
