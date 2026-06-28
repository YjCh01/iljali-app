import 'dart:io';

import 'package:flutter/material.dart';

Widget buildSeekerDocumentImage(String imageRef, {double height = 140}) {
  return Image.file(
    File(imageRef),
    height: height,
    width: double.infinity,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
  );
}
