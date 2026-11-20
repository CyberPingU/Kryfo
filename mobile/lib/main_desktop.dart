// SPDX-License-Identifier: GPL-3.0-or-later
// the linux and windows app: flutter build linux -t lib/main_desktop.dart.
// the phone's build starts at main.dart and never reaches lib/desktop
import 'dart:io';

import 'desktop/desktop_mode.dart' show deskLaunchLink, launchLinkOf;
import 'desktop/desktop_paths.dart' show activeProfile;
import 'desktop/desktop_start.dart';
import 'main.dart' as app;

void main(List<String> args) {
  // windows' app_links reads its own command line
  if (Platform.isLinux) deskLaunchLink = launchLinkOf(args);
  String? profile;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if ((a == '--profile' || a == '-p') && i + 1 < args.length) {
      profile = args[i + 1];
      break;
    } else if (a.startsWith('--profile=')) {
      profile = a.substring('--profile='.length);
      break;
    }
  }
  final envProfile = Platform.environment['KRYFO_PROFILE'];
  if (profile == null && envProfile != null && envProfile.isNotEmpty) {
    profile = envProfile;
  }
  if (profile != null && profile.isNotEmpty) activeProfile = profile;
  startDesktop(() async => app.main(), profile: profile);
}
