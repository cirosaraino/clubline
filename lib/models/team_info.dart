import '../core/team_info_formatters.dart';

class TeamCustomLink {
  const TeamCustomLink({
    required this.label,
    required this.url,
  });

  final String label;
  final String url;

  factory TeamCustomLink.fromMap(Map<String, dynamic> map) {
    return TeamCustomLink(
      label: normalizeTeamLinkLabel(map['label']?.toString() ?? ''),
      url: normalizeOptionalTeamUrl(map['url']?.toString()) ?? '',
    );
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'label': normalizeTeamLinkLabel(label),
      'url': normalizeOptionalTeamUrl(url),
    };
  }

  bool get isValid {
    return label.isNotEmpty && (normalizeOptionalTeamUrl(url) ?? '').isNotEmpty;
  }
}

class TeamInfoLinkItem {
  const TeamInfoLinkItem({
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

class TeamInfo {
  const TeamInfo({
    this.id = 1,
    this.teamName = kDefaultTeamName,
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

  static const defaults = TeamInfo();

  final int id;
  final String teamName;
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
  final List<TeamCustomLink> customLinks;

  factory TeamInfo.fromMap(Map<String, dynamic> map) {
    final rawCustomLinks = map['additional_links'];

    return TeamInfo(
      id: map['id'] is num ? (map['id'] as num).toInt() : 1,
      teamName: normalizeTeamName(map['team_name']?.toString() ?? kDefaultTeamName),
      crestUrl: normalizeOptionalTeamUrl(map['crest_url']?.toString()),
      slug: map['slug']?.toString(),
      websiteUrl: normalizeOptionalTeamUrl(map['website_url']?.toString()),
      youtubeUrl: normalizeOptionalTeamUrl(map['youtube_url']?.toString()),
      discordUrl: normalizeOptionalTeamUrl(map['discord_url']?.toString()),
      facebookUrl: normalizeOptionalTeamUrl(map['facebook_url']?.toString()),
      instagramUrl: normalizeOptionalTeamUrl(map['instagram_url']?.toString()),
      twitchUrl: normalizeOptionalTeamUrl(map['twitch_url']?.toString()),
      tiktokUrl: normalizeOptionalTeamUrl(map['tiktok_url']?.toString()),
      primaryColor: map['primary_color']?.toString(),
      accentColor: map['accent_color']?.toString(),
      surfaceColor: map['surface_color']?.toString(),
      customLinks: [
        if (rawCustomLinks is Iterable)
          for (final item in rawCustomLinks)
            if (item is Map)
              TeamCustomLink.fromMap(Map<String, dynamic>.from(item)),
      ].where((link) => link.isValid).toList(),
    );
  }

  TeamInfo copyWith({
    int? id,
    String? teamName,
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
    List<TeamCustomLink>? customLinks,
  }) {
    return TeamInfo(
      id: id ?? this.id,
      teamName: teamName ?? this.teamName,
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
          (link) => TeamCustomLink(
            label: normalizeTeamLinkLabel(link.label),
            url: normalizeOptionalTeamUrl(link.url) ?? '',
          ),
        )
        .where((link) => link.isValid)
        .map((link) => link.toDatabaseMap())
        .toList();

    return {
      'id': id,
      'team_name': normalizeTeamName(teamName),
      'crest_url': normalizeOptionalTeamUrl(crestUrl),
      'slug': slug,
      'website_url': normalizeOptionalTeamUrl(websiteUrl),
      'youtube_url': normalizeOptionalTeamUrl(youtubeUrl),
      'discord_url': normalizeOptionalTeamUrl(discordUrl),
      'facebook_url': normalizeOptionalTeamUrl(facebookUrl),
      'instagram_url': normalizeOptionalTeamUrl(instagramUrl),
      'twitch_url': normalizeOptionalTeamUrl(twitchUrl),
      'tiktok_url': normalizeOptionalTeamUrl(tiktokUrl),
      'primary_color': primaryColor,
      'accent_color': accentColor,
      'surface_color': surfaceColor,
      'additional_links': normalizedCustomLinks,
    };
  }

  String get displayTeamName => normalizeTeamName(teamName);

  bool get hasCustomCrest => (crestUrl ?? '').trim().isNotEmpty;

  bool get hasAnyLinks => allLinks.isNotEmpty;

  List<TeamInfoLinkItem> get allLinks {
    return [
      if (websiteUrl != null)
        TeamInfoLinkItem(
          key: 'website',
          label: 'Sito',
          url: websiteUrl!,
        ),
      if (youtubeUrl != null)
        TeamInfoLinkItem(
          key: 'youtube',
          label: 'YouTube',
          url: youtubeUrl!,
        ),
      if (discordUrl != null)
        TeamInfoLinkItem(
          key: 'discord',
          label: 'Discord',
          url: discordUrl!,
        ),
      if (facebookUrl != null)
        TeamInfoLinkItem(
          key: 'facebook',
          label: 'Facebook',
          url: facebookUrl!,
        ),
      if (instagramUrl != null)
        TeamInfoLinkItem(
          key: 'instagram',
          label: 'Instagram',
          url: instagramUrl!,
        ),
      if (twitchUrl != null)
        TeamInfoLinkItem(
          key: 'twitch',
          label: 'Twitch',
          url: twitchUrl!,
        ),
      if (tiktokUrl != null)
        TeamInfoLinkItem(
          key: 'tiktok',
          label: 'TikTok',
          url: tiktokUrl!,
        ),
      for (final link in customLinks)
        TeamInfoLinkItem(
          key: 'custom_${link.label}',
          label: link.label,
          url: link.url,
          isCustom: true,
        ),
    ];
  }
}
