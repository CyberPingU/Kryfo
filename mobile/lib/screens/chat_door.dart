// SPDX-License-Identifier: GPL-3.0-or-later
// into a chat from a list of its messages or its people: a group, the
// developer chat or a person's own, landing on one message when asked
import 'package:flutter/material.dart';

import '../devchat/dev_key.dart' show isDevChat;
import '../main.dart' show appState, session;
import '../widgets/motion.dart' show haloRoute;
import 'chat_screen.dart';
import 'dev_about_sheet.dart' show devChatRoute;
import 'group_chat_screen.dart';
import '../wide/wide_pane.dart' show deskPusher;

// a page that stands in for the chat, which needs the engine
@visibleForTesting
Widget Function({String? groupId, String? peer, String? uid})? chatPageForTest;

// false when there is no such chat on this phone any more
Future<bool> openChatAt(
  BuildContext context, {
  String? groupId,
  String? peer,
  String? uid,
}) async {
  // from the desktop's list: into its pane, in place of what it shows
  final push = deskPusher(context);
  final group = groupId != null && groupId.isNotEmpty ? groupId : null;
  final Route<void> route;
  if (group != null) {
    if (!await session.groupExists(group)) {
      if (session.vault != null && await session.vault!.groupExists(group)) {
        session.noteVaultGroup(group);
      } else {
        return false;
      }
    }
    route = haloRoute(GroupChatScreen(groupId: group, jumpToUid: uid));
  } else if (peer == null || peer.isEmpty) {
    return false;
  } else if (isDevChat(peer)) {
    if (appState.devRow?.chatId != peer) return false;
    route = devChatRoute(peer, jumpToUid: uid);
  } else {
    Map<String, Object?>? row;
    try {
      final rows = await session.contacts();
      row = rows.where((r) => r['halo_id'] == peer).firstOrNull;
    } catch (_) {}
    row ??= await session.getContact(peer);
    if (row == null && session.vault != null) {
      try {
        row = await session.vault!.getContact(peer);
      } catch (_) {}
    }
    if (row == null) {
      try {
        row = await session.primary.getContact(peer);
      } catch (_) {}
    }
    if (session.vault != null && !session.isHidden(peer)) {
      try {
        if (await session.vault!.getContact(peer) != null) {
          session.noteVaultPeer(peer);
        }
      } catch (_) {}
    }
    route = haloRoute(
      ChatScreen(
        peerHaloId: peer,
        peerOnion: (row?['onion'] as String?) ?? '',
        peerXPub: (row?['xpub'] as String?) ?? '',
        avatarSeed: peer,
        avatarChoice: (row?['avatar'] as num?)?.toInt(),
        nickname: row?['nickname'] as String?,
        jumpToUid: uid,
      ),
    );
  }
  final stand = chatPageForTest;
  push(
    stand == null
        ? route
        : haloRoute(stand(groupId: group, peer: peer, uid: uid)),
    id: group != null ? 'group:$group' : peer,
  );
  return true;
}
