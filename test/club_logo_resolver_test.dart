import 'package:clubline/core/club_logo_resolver.dart';
import 'package:clubline/ui/widgets/club_logo_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'buildClubLogoPublicUrl derives a stable public URL from the storage path',
    () {
      final url = buildClubLogoPublicUrl(
        'https://clubline.supabase.co',
        'clubs/12/my crest logo.png',
      );

      expect(
        url,
        'https://clubline.supabase.co/storage/v1/object/public/club-assets/clubs/12/my%20crest%20logo.png',
      );
    },
  );

  testWidgets(
    'ClubLogoAvatar keeps raster logos contained inside the avatar frame',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ClubLogoAvatar(
                logoUrl: 'https://cdn.example.com/crest.png',
                size: 96,
                fallbackIcon: Icons.shield_outlined,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image).first);
      expect(image.fit, BoxFit.contain);
    },
  );
}
