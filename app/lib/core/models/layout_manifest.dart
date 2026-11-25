// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:collection/collection.dart';

/// Metadata model for a layout document, tracking identification, authorship,
/// versioning, and categorisation.
class LayoutManifest {
  final String id;
  final String name;
  final String author;
  final String version;
  final String description;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  LayoutManifest({
    required this.id,
    required this.name,
    this.author = 'Anonymous',
    this.version = '1.0.0',
    this.description = '',
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a copy with optional field replacements.
  LayoutManifest copyWith({
    String? id,
    String? name,
    String? author,
    String? version,
    String? description,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LayoutManifest(
      id: id ?? this.id,
      name: name ?? this.name,
      author: author ?? this.author,
      version: version ?? this.version,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Serializes the manifest to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'author': author,
      'version': version,
      'description': description,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Deserializes a manifest from a JSON map.
  factory LayoutManifest.fromJson(Map<String, dynamic> json) {
    return LayoutManifest(
      id: json['id'] as String,
      name: json['name'] as String,
      author: json['author'] as String? ?? 'Anonymous',
      version: json['version'] as String? ?? '1.0.0',
      description: json['description'] as String? ?? '',
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  @override
  String toString() =>
      'LayoutManifest(id: $id, name: $name, author: $author, version: $version, tags: $tags)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LayoutManifest &&
        other.id == id &&
        other.name == name &&
        other.author == author &&
        other.version == version &&
        other.description == description &&
        const ListEquality<String>().equals(other.tags, tags) &&
        other.createdAt.isAtSameMomentAs(createdAt) &&
        other.updatedAt.isAtSameMomentAs(updatedAt);
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    author,
    version,
    description,
    const ListEquality<String>().hash(tags),
    createdAt.millisecondsSinceEpoch,
    updatedAt.millisecondsSinceEpoch,
  );
}
