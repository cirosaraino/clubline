import 'club_logo_picker_types.dart';
import 'club_logo_picker_bridge_stub.dart'
    if (dart.library.html) 'club_logo_picker_bridge_web.dart' as bridge;

Future<PickedClubLogo?> pickClubLogo() => bridge.pickClubLogo();
