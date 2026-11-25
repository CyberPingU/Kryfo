// SPDX-License-Identifier: GPL-3.0-or-later
// the developer's pinned identity: the keys of Marios's own invite, built
// into the app. the chat with him trusts these keys, never his three words:
// three words are 33 bits, and anyone can grind a key that has them

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../dlog.dart';
import '../main.dart' show parseHaloUri;
import 'dev_lane.dart' show devCardChecks;

enum DevKeyStatus {
  // new chats start with it
  current,
  // chats already on it keep going after a rotation
  previous,
  // nothing more is sent or taken in with it
  retired,
}

class DevKey {
  const DevKey({
    required this.keyId,
    required this.threeWords,
    required this.xPub,
    required this.bundle,
    required this.fc,
    this.onion = '',
    this.status = DevKeyStatus.current,
  });

  // never reused, so a chat id always names one key
  final String keyId;
  // shown in the about sheet, never trusted
  final String threeWords;
  // 64 hex: the relay lanes and the signal identity
  final String xPub;
  // the invite's base64 bundle, as it was shared
  final String bundle;
  // 64 hex: the dev phone's first-contact address
  final String fc;
  // empty: relay only
  final String onion;
  final DevKeyStatus status;

  // the chat's peer id everywhere on this phone. never three words, so no
  // row made from the wire can land on it
  String get chatId => chatIdOf(keyId);

  static String chatIdOf(String keyId) => 'dev:$keyId';

  // a key from a v3 invite link, read by the app's own parser. its onion is
  // left out. the signature is not checked here: the self-check test does
  // that for every pinned key, and a first send checks it again
  static DevKey? fromLink(
    String link, {
    required String keyId,
    DevKeyStatus status = DevKeyStatus.current,
  }) {
    final p = parseHaloUri(link);
    if (p == null || p['v'] != '3') return null;
    final fc = p['fc']?.toLowerCase();
    if (fc == null || !_hex64.hasMatch(fc)) return null;
    final bundle = p['bundle']!;
    final id = _identityOf(bundle);
    if (id == null) return null;
    return DevKey(
      keyId: keyId,
      threeWords: p['id']!,
      xPub: _hex(id.sublist(1)),
      bundle: bundle,
      fc: fc,
      status: status,
    );
  }
}

// the pinned keys, from CyberPingU's v4 invite. relay only: no onion
const kDevKeys = <DevKey>[
  DevKey(
    keyId: 'c1',
    threeWords: 'CyberPingU',
    xPub: 'a75fd55ab24f2c4dc8c447330b173b1a6b5bb56506fc1c39675aff75b4771a1c',
    bundle:
        'eyJyZWdpc3RyYXRpb25JZCI6NTkxOSwiZGV2aWNlSWQiOjEsInNpZ25lZFByZUtleUlkIjoxMjI0MTAyNzQ0LCJzaWduZWRQcmVLZXlQdWJsaWMiOiJCWXZ6Q2pCYUhpZTBldDFpd0h2eWhyM3M1QXdlT2N6dmpqN1ZCdlpqcTZrTCIsInNpZ25lZFByZUtleVNpZ25hdHVyZSI6IlJLVS9YUFhvbDdNUUtWUjNiemUyZUE0bkc4T1Mxb2NqOHZKd3BBdE1vWUhvZmtxK0ZxYWIrR2tuSFB4MUpudVBBTFI2eUxPVWhxcml0UDB3TC9LMUJBPT0iLCJreWJlclByZUtleUlkIjoxNzI4MjAzMjg2LCJreWJlclByZUtleVB1YmxpYyI6IkNJajhQNDBndnVwZ0oraUJHRFJCZ3p3TVZYeDBxMXY0Z1hSa0liT2t5Zy9Zd1U2RWRmUDFYNVMxSmJVUWkvV3FPSkdwcmxTNnFXVkJldGRadmlEclYrMGtlWWRuZnpoVGROVFVpSHJNaVdTU3ZTaFZhWG41WWlaTGt5UmpsUHUwY1pWMWN1MlZiNk1hekZDc0drdlpMMUx3clkwcUFZZWxEVUNXZ0FJWFlTRHlVdU9FVzREaXFCTmllVWxpck52YWFQU0p6ck5XdnlyOGpvWTNyRjc0djFLV3o3bnlpUTMzZ1hlY2M5SXJTRElTUnJERlQxK1JYMERXYThyUUpIeDZIcmdJVlpOQVZlMmNpKzZnSTJha0F1MklWbjhUTVRDb3NXTlFiS3pEUFNiaVFOdlpmcTVjbmluNU8wcjNqUE56QlBYSVNnMXFsZWJ3ZllBWGQ2WnNNaDNwWW0yWHRpSjJXR2RwSXRiekZIaHJyb2JvUVh4aFNha0pVa2pGSzdYY1gzcUxwcC9ZWGdVYmFqTEp0eUIyUlA2OHBrbDF0RHRXU0FrQnhrTVlydjhLaFVDOHkwWm1YSndqaG03aVBuS0VxSGFSbEZ0NGl2WFRyWkZzWHN0RFE0eUNMejdpelFxNE9tcldWak4zczhVSnJXVHFzNjRZc3l4bkhlZDJNRXVhamgwQU42cEt0TWhYaXQva2t3Q0pQNjNrcFNKVmdRckdNOTFhVWthcnlna2hEUVhsQjJUcHgxYnhnZXhMd3JZV0l3aVRNMGdtc1RsNkdleUx1SXhKRmV0am9lUmtyRDFhamZQSWh5bnl3Y2gwZDVsVnIwczZraDZ6U3lKQm5yZ2JSbmEzbkNTSk8vMmpZNTVBWHpqbk9pbFV1UzcxaDA4b29VdjNMamloQURFYlF2T3p0Z0owYXBHN2NJbTF5TVVIZGZwVVZ1L1dyL0VDSEgvSHQrUjRFOW5JS3F6SnNsNkhBQzZMS2ZNMFA2aUxTWFNnbmFBc0FYb0pIMCtpamhUcE4yeDhWamtUbkNqbGRkMGxnUTFZQXhVY0VCc1FYc2U4Z2JxMWFoQ1NwUmxSZkJnQ0lMVUtNcXlDR0l0QWZxSXJuWmh5Q0hPWkpGUHlkd1RGaHJOeExNbzVORjhYTHl5UVRqWGdMb01Yd0Z6NEdJT3p2SXZpeDVKcUlobjdpbmZjRzZicXkrbjBzVUx5bmF0QkZqMEZjZFhiUmN6c0tFU2NYeHAxQ1VFSHZhSlFqQUQyUXFjd1NrQTRGTmhaaG1VOERKZnN4UWtqVTBKbVduUGduNlRqVlpxWHpUK1FkaWt4ejBZeGc2bUtkWW03V255MVkvL0tNNS9XZnFQN2UxVjNvRENVVngyQkxhQzhTSWtFb1lmeWZGSklxVy9DbXRucHdhSlhVWWdtSDVwNkRYclN0K2M4UjNyVno5bWx0Yk1oQWptSXpVU2dscWppd0VkQUdscktoMXkyc3FiU000ZWFyemIzQjUwM2tGOGdxSnIxamlaR2M3UnN4OEhCeGtrY0JSYjBTNzdoZXEyanUyVFJwUFpxVFUzcXZocDZ6dDk0TEp0VFlUS1ZiTjFGYUR4bmNHbjJuWFVzWHpUQ29xdFNENEFSaTFWY29LSmxaNW54SHN0Y00xSEpycXJha091RlRUK1NCMTVrR1RnYnMwenFiSHJTUVpsY3JkSG5UclVBTjM3R2piU1JMMFdwU2UzcHorT0tockIweTBENkRsVmp5WjlsVFpyR0lxR0NOM1k1VHQvWmEzdHljaGZZRzVZanFQUkJvdm5JY2s2d3psd2JYc3E0TXJIaXFjaldkQ2xZUmg3amdmQ0RXOG1YWmpZbXNZQnpVOTBJaVkzaUtQTGtCbC9KeVpKTG1zcXhpb041Z2Z4elZkZDZ6TFlydFNSMEhBZEpXVTkydy9kS0x2bHNiU1h6ZFZXWHBvWWJRUnBraVdFSHJEYUFsSU5Bc0xWTGJWWGdpTWM4UUE2RVZNNTVyQjFZQWJJREZ4ZUtCU3I1bm40MFJhYlRJRUJKUHhEQmRXeDNXanlTQWtjcGlkaERuNXRsTUpZNFlSeEtjZjM4YkloN2w0SGNBN0tIQmd5eEUzc0l2ZVhiUzJUcHgzT3pvSGxJemxGMEtBN0xQdmVsZCsvMGlxWklhY0VKVGYrQk5RQmFpT2VYdVBDQUk0OTZUTnhYS1R6RGRWajNQN3JrYTRMNlZOOFJHZ2ZVUlBNS3VidUtheFdEYWdTcXFoZHdhbC83RXpIVnh6cFVicWlWdCtQTUtrZnlxejNoeElRUXZYemxVcjFYc2tYaGxRMENOWHNNUzhUVkNXL3pGSVVVRVp1eUwyWjVuUEM2ckt0NVcxcnNlWUFHTGpWQWVqVEVYSnNqc28zb1FlUFRCR2JwaDRDQkU1a2JpVFpUbndlbnFJdFZsTDNrUzMvR2ZERkFiUit5THBIRlA2UDRVWEl6djNBQ3BaYlJmWXUxUXFVRVhyUXFwL2ZMSWNNc2FNUnJZZWx6b1lWUmlwRTBZbytNdnYxbnhIcEFlbWN4Uk1hb0xLbTdMVEo0bFdtYVgxcG9ubnoySTVOV1IxZ3p1WkpYVTVXenJCcEVQS2xnSzZpWU1KRWtqRGphaGpUWGdFaFVVMVVoRUpIb25zM29vZUhWTGtrNlZrWkFRR1V5dHZhQWZSZGFUSW5tYS9GckQza0JHSXpCbU5GQ2tWZDVDVXJseG9vbGRTRnVUbzBwK0ZnZUFXejhYeG5GUU5uU25OZEFyL0FrQVFlUFhBZHEiLCJreWJlclByZUtleVNpZ25hdHVyZSI6IjZoSm5uQlp0VS91ZnRpL0pWQXNmc3VWclQxZXVISWNMNkFEOUFLNUx6WnFUUGlIWDR0SVpuRkVZM0g3cWlZSXBQQU1vNXJGYmhVdUpQNnNldURMZkNBPT0iLCJpZGVudGl0eUtleSI6IkJhZGYxVnF5VHl4TnlNUkhNd3NYT3hwclc3VmxCdndjT1dkYS8zVzBkeG9jIn0=',
    fc: '34866f1df0078b003fadee6f3fa3125aa9c58eeefcaafa8e13810decb7f9e2e7',
  ),
];

// the keys this build trusts. a debug or profile build made with
// --dart-define=KRYFO_DEV_CARD=<a v3 link> trusts that card instead, so a
// test phone can play the developer. a release reads neither override
List<DevKey> get devKeys {
  if (kReleaseMode) return kDevKeys;
  final t = _forTest;
  if (t != null) return t;
  const card = String.fromEnvironment('KRYFO_DEV_CARD');
  if (card.isEmpty) return kDevKeys;
  return _cardKeys ??= devKeysOfCard(card);
}

List<DevKey>? _cardKeys;
List<DevKey>? _forTest;

// a card that does not read, or that its own key did not sign, trusts
// nobody: a test build never falls back to the real keys, and never shows
// a chat whose every send would stop at the key check
@visibleForTesting
List<DevKey> devKeysOfCard(String card) {
  final k = DevKey.fromLink(card, keyId: 't1');
  if (k == null) {
    dlog('dev key: the test card does not read');
    return const [];
  }
  if (!devCardChecks(k)) {
    dlog('dev key: the test card does not check out');
    return const [];
  }
  return [k];
}

@visibleForTesting
void useDevKeysForTest(List<DevKey>? keys) => _forTest = keys;

DevKey? get currentDevKey {
  for (final k in devKeys) {
    if (k.status == DevKeyStatus.current) return k;
  }
  return null;
}

DevKey? devKeyById(String keyId) {
  for (final k in devKeys) {
    if (k.keyId == keyId) return k;
  }
  return null;
}

DevKey? devKeyByXPub(String xPub) {
  final x = xPub.toLowerCase();
  for (final k in devKeys) {
    if (k.xPub == x) return k;
  }
  return null;
}

DevKey? devKeyByFc(String fc) {
  final f = fc.toLowerCase();
  for (final k in devKeys) {
    if (k.fc == f) return k;
  }
  return null;
}

bool isDevChat(String id) => id.startsWith('dev:');

// the 33 bytes libsignal compares: the type byte, then the x25519 key
Uint8List pinnedIdentity(DevKey k) =>
    Uint8List.fromList([0x05, ..._bytes(k.xPub)]);

final _hex64 = RegExp(r'^[0-9a-f]{64}$');

// the bundle's identity key, when it is the 33 bytes of an x25519 key
Uint8List? _identityOf(String bundle) {
  try {
    final j = jsonDecode(utf8.decode(base64Decode(bundle)));
    if (j is! Map) return null;
    final ik = j['identityKey'];
    if (ik is! String) return null;
    final b = base64Decode(ik);
    return b.length == 33 && b[0] == 0x05 ? b : null;
  } catch (_) {
    return null;
  }
}

String _hex(List<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();

List<int> _bytes(String hex) => [
  for (var i = 0; i + 1 < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
];
