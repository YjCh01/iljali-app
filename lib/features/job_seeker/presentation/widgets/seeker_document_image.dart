import 'dart:convert';

import 'package:flutter/material.dart';

import 'seeker_document_image_stub.dart'
    if (dart.library.io) 'seeker_document_image_io.dart';

Widget seekerDocumentImage(String? imageRef, {double height = 140}) {
  final ref = imageRef?.trim();
  if (ref == null || ref.isEmpty) return const SizedBox.shrink();

  if (ref.startsWith('data:image/')) {
    final comma = ref.indexOf(',');
    if (comma == -1) return const SizedBox.shrink();
    final bytes = base64Decode(ref.substring(comma + 1));
    return Image.memory(
      bytes,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }

  if (ref.startsWith('http://') || ref.startsWith('https://')) {
    return Image.network(
      ref,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  return buildSeekerDocumentImage(ref, height: height);
}

bool seekerDocumentHasImage(String? imageRef) {
  final ref = imageRef?.trim();
  return ref != null && ref.isNotEmpty;
}
