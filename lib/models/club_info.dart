import '../core/club_info_formatters.dart';

class ClubCustomLink {
  const ClubCustomLink({required this.label, required this.url});

  final String label;
  final String url;

  factory ClubCustomLink.fromMap(Map<String, dynamic> map) {
    return ClubCustomLink(
      label: normalizeClubLinkLabel(map['label']?.toString() ?? ''),
      url: normalizeOptionalClubUrl(map['url']?.toString()) ?? '',
    );
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'label': normalizeClubLinkLabel(label),
      'url': normalizeOptionalClubUrl(url),
    };
  }

  bool get isValid {
    return label.isNotEmpty && (normalizeOptionalClubUrl(url) ?? '').isNotEmpty;
  }
}

class ClubInfoLinkItem {
  const ClubInfoLinkItem({
    required this.key,
    required this.label,
    required this.url,
    this.isCustom = false,
  });

  final String key;
  final String label;
  final String url;
  final bool isCustom;
}

class ClubInfo {
  const ClubInfo({
    this.id = 1,
    this.clubName = kDefaultClubName,
    this.crestUrl,
    this.slug,
    this.websiteUrl,
    this.youtubeUrl,
    this.discordUrl,
    this.facebookUrl,
    this.instagramUrl,
    this.twitchUrl,
    this.tiktokUrl,
    this.primaryColor,
    this.accentColor,
    this.surfaceColor,
    this.customLinks = const [],
  });

  static const defaults = ClubInfo();

  final int id;
  final String clubName;
  final String? crestUrl;
  final String? slug;
  final String? websiteUrl;
  final String? youtubeUrl;
  final String? discordUrl;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? twitchUrl;
  final String? tiktokUrl;
  final String? primaryColor;
  final String? accentColor;
  final String? surfaceColor;
  final List<ClubCustomLink> customLinks;

  factory ClubInfo.fromMap(Map<String, dynamic> map) {
    final rawCustomLinks = map['additional_links'];
    final rawClubName =
        map['club_name']?.toString() ??
        map['team_name']?.toString() ??
        kDefaultClubName;

    return ClubInfo(
      id: map['id'] is num ? (map['id'] as num).toInt() : 1,
      clubName: normalizeClubName(rawClubName),
      crestUrl: normalizeOptionalClubUrl(map['crest_url']?.toString()),
      slug: map['slug']?.toString(),
      websiteUrl: normalizeOptionalClubUrl(map['website_url']?.toString()),
      youtubeUrl: normalizeOptionalClubUrl(map['youtube_url']?.toString()),
      discordUrl: normalizeOptionalClubUrl(map['discord_url']?.toString()),
      facebookUrl: normalizeOptionalClubUrl(map['facebook_url']?.toString()),
      instagramUrl: normalizeOptionalClubUrl(map['instagram_url']?.toString()),
      twitchUrl: normalizeOptionalClubUrl(map['twitch_url']?.toString()),
      tiktokUrl: normalizeOptionalClubUrl(map['tiktok_url']?.toString()),
      primaryColor: map['primary_color']?.toString(),
      accentColor: map['accent_color']?.toString(),
      surfaceColor: map['surface_color']?.toString(),
      customLinks: [
        if (rawCustomLinks is Iterable)
          for (final item in rawCustomLinks)
            if (item is Map)
              ClubCustomLink.fromMap(Map<String, dynamic>.from(item)),
      ].where((link) => link.isValid).toList(),
    );
  }

  ClubInfo copyWith({
    int? id,
    String? clubName,
    String? crestUrl,
    String? slug,
    String? websiteUrl,
    String? youtubeUrl,
    String? discordUrl,
    String? facebookUrl,
    String? instagramUrl,
    String? twitchUrl,
    String? tiktokUrl,
    String? primaryColor,
    String? accentColor,
    String? surfaceColor,
    List<ClubCustomLink>? customLinks,
  }) {
    return ClubInfo(
      id: id ?? this.id,
      clubName: clubName ?? this.clubName,
      crestUrl: crestUrl ?? this.crestUrl,
      slug: slug ?? this.slug,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      discordUrl: discordUrl ?? this.discordUrl,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      twitchUrl: twitchUrl ?? this.twitchUrl,
      tiktokUrl: tiktokUrl ?? this.tiktokUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      customLinks: customLinks ?? this.customLinks,
    );
  }

  Map<String, dynamic> toDatabaseMap() {
    final normalizedCustomLinks = customLinks
        .map(
          (link) => ClubCustomLink(
            label: normalizeClubLinkLabel(link.label),
            url: normalizeOptionalClubUrl(link.url) ?? '',
          ),
        )
        .where((link) => link.isValid)
        .map((link) => link.toDatabaseMap())
        .toList();

    return {
      'id': id,
      'club_name': normalizeClubName(clubName),
      'team_name': normalizeClubName(clubName),
      'crest_url': normalizeOptionalClubUrl(crestUrl),
      'slug': slug,
      'website_url': normalizeOptionalClubUrl(websiteUrl),
      'youtube_url': normalizeOptionalClubUrl(youtubeUrl),
      'discord_url': normalizeOptionalClubUrl(discordUrl),
      'facebook_url': normalizeOptionalClubUrl(facebookUrl),
      'instagram_url': normalizeOptionalClubUrl(instagramUrl),
      'twitch_url': normalizeOptionalClubUrl(twitchUrl),
      'tiktok_url': normalizeOptionalClubUrl(tiktokUrl),
      'primary_color': primaryColor,
      'accent_color': accentColor,
      'surface_color': surfaceColor,
      'additional_links': normalizedCustomLinks,
    };
  }

  String get displayClubName => normalizeClubName(clubName);

  bool get hasCustomCrest => (crestUrl ?? '').trim().isNotEmpty;

  bool get hasAnyLinks => allLinks.isNotEmpty;

  List<ClubInfoLinkItem> get allLinks {
    return [
      if (websiteUrl != null)
        ClubInfoLinkItem(key: 'website', label: 'Sito', url: websiteUrl!),
      if (youtubeUrl != null)
        ClubInfoLinkItem(key: 'youtube', label: 'YouTube', url: youtubeUrl!),
      if (discordUrl != null)
        ClubInfoLinkItem(key: 'discord', label: 'Discord', url: discordUrl!),
      if (facebookUrl != null)
        ClubInfoLinkItem(key: 'facebook', label: 'Facebook', url: facebookUrl!),
      if (instagramUrl != null)
        ClubInfoLinkItem(
          key: 'instagram',
          label: 'Instagram',
          url: instagramUrl!,
        ),
      if (twitchUrl != null)
        ClubInfoLinkItem(key: 'twitch', label: 'Twitch', url: twitchUrl!),
      if (tiktokUrl != null)
        ClubInfoLinkItem(key: 'tiktok', label: 'TikTok', url: tiktokUrl!),
      for (final link in customLinks)
        ClubInfoLinkItem(
          key: 'custom_${link.label}',
          label: link.label,
          url: link.url,
          isCustom: true,
        ),
    ];
  }
}

@Deprecated('Use ClubCustomLink instead.')
typedef TeamCustomLink = ClubCustomLink;

@Deprecated('Use ClubInfoLinkItem instead.')
typedef TeamInfoLinkItem = ClubInfoLinkItem;

@Deprecated('Use ClubInfo instead.')
typedef TeamInfo = ClubInfo;
