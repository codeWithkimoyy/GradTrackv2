import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

ImageProvider<Object> avatarProvider(String? photoUrl, {Uint8List? localBytes}) {
  if (localBytes != null) return MemoryImage(localBytes);
  if (photoUrl == null) return const AssetImage('');
  if (photoUrl.startsWith('data:')) {
    final data = base64Decode(photoUrl.split(',').last);
    return MemoryImage(data);
  }
  return NetworkImage(photoUrl);
}
