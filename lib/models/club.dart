class Club {
  const Club({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.logoStoragePath,
    this.primaryColor,
    this.accentColor,
    this.surfaceColor,
  });

  final dynamic id;
  final String name;
  final String slug;
  final String? logoUrl;
  final String? logoStoragePath;
  final String? primaryColor;
  final String? accentColor;
  final String? surfaceColor;

  factory Club.fromMap(Map<String, dynamic> map) {
    return Club(
      id: map['id'],
      name: map['name']?.toString().trim() ?? '',
      slug: map['slug']?.toString().trim() ?? '',
      logoUrl: map['logo_url']?.toString().trim().isEmpty == true
          ? null
          : map['logo_url']?.toString().trim(),
      logoStoragePath: map['logo_storage_path']?.toString().trim().isEmpty ==
              true
          ? null
          : map['logo_storage_path']?.toString().trim(),
      primaryColor: map['primary_color']?.toString(),
      accentColor: map['accent_color']?.toString(),
      surfaceColor: map['surface_color']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'logo_url': logoUrl,
      'logo_storage_path': logoStoragePath,
      'primary_color': primaryColor,
      'accent_color': accentColor,
      'surface_color': surfaceColor,
    };
  }

  Club copyWith({
    dynamic id,
    String? name,
    String? slug,
    String? logoUrl,
    String? logoStoragePath,
    String? primaryColor,
    String? accentColor,
    String? surfaceColor,
  }) {
    return Club(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      logoUrl: logoUrl ?? this.logoUrl,
      logoStoragePath: logoStoragePath ?? this.logoStoragePath,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
    );
  }
}
