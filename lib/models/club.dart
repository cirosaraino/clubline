class Club {
  const Club({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.primaryColor,
    this.accentColor,
    this.surfaceColor,
  });

  final dynamic id;
  final String name;
  final String slug;
  final String? logoUrl;
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
    String? primaryColor,
    String? accentColor,
    String? surfaceColor,
  }) {
    return Club(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
    );
  }
}
