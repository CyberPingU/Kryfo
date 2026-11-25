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

// the pinned keys, from CyberPingU's permanent v3 developer card. relay only: no onion
const kDevKeys = <DevKey>[
  DevKey(
    keyId: 'c1',
    threeWords: 'certain-before-scatter',
    xPub: 'a75fd55ab24f2c4dc8c447330b173b1a6b5bb56506fc1c39675aff75b4771a1c',
    bundle:
        'eyJyZWdpc3RyYXRpb25JZCI6NTkxOSwiZGV2aWNlSWQiOjEsInByZUtleUlkIjo5OTk5OTksInByZUtleVB1YmxpYyI6IkJmZGFqcWM2cmFKcVRNK3hHTlp4NUowdGxLNFVNRXdEZEVHT0FCdlJuVjlJIiwic2lnbmVkUHJlS2V5SWQiOjEsInNpZ25lZFByZUtleVB1YmxpYyI6IkJlWE9uNVNsZW1CSGFFbmxLRlJBRzNDRi9HbUVsTFFvUVo3UndUZnhRSUE0Iiwic2lnbmVkUHJlS2V5U2lnbmF0dXJlIjoiYVhTTEFLN1FieWNyWGRJb3c2U2xBVXlwZWQ4cmgzdFVVcHhwdnhLbXhBdnlYOGVvOVhWT2FKZmlmTUxkRFRBTXE3Y1NsOTZ4SG1CVmNiRXNCUDM4RGc9PSIsImt5YmVyUHJlS2V5SWQiOjEsImt5YmVyUHJlS2V5UHVibGljIjoiQ0dGVUFjeXJ5bnQ3Vk5Xbk4wV1JOdGFvYnMxcVdCcXFra2pvWDBtaUx3U3BnaXBHWmZ0MmdVempQR1JKY0swU0hwcUxJaENrYXAwSXVRV3hhUlVIT0JjRERoaXdrRXdNdzVDQUtleTd1dFdnZjlmcHd4S1Nrb0FnYVFZS1M3ZUFnOWRoWjVZYm5kbVROaEhLQzBoWmxRRnp6MmhjVHpOd1ZSOGhXZWxUUmxsSFpreHpLUXM2eXFHRWlERkZZemgxbVBFb3lZVzBhYUpVWW5PcnJTdkZJNllMa3pqa0dHQTdDMTlsS2tEMVU3WEVTM0VEb2VnS2tXQUV4c2ltZHRlbFJRUTZXWkJJTEVsblpjS1hLMjBZZGJuQ1AxSHphWXNUVDcwSUVIRmNGQzY1bTJSc1MyTUJ5cGpMVEV0d1QrbmxQRXJxT25yWnUyUkRjQjhoa0RqWmNWZlJZL3RxRkZDaUFjMXp5ZEVSdWY3d0pFdGNxU0lEenBzV2ZOK2FCSEJLVTBja2tHZkdmUFZBSlk5TFVWUkJJa2doVjBLalRhQWJlNytHckkrek1tL1JXK0pXUGVWcmh6QUlwcVA1TS84RExHSDdQbzdyTUlLb1MweXFBMW8zZm5OMUZKa2x3bHJJekZBclJQZ1dwMndBcTRJemZJR0hMY1lDd2o5OFZXQXJZN3AwcjBTWmFucGFWSDNuREo2ak56L0llam5STHYrSmxodDNiUVd5ZjF6Z0ljWFFBczdNWVN4RkNqUjZOQ29hT0NaREl3cE15RmoxUDBEcFhteW9HZHBoUVh6MUFnYW9BRzkybEMxOExPQzZVcHpYUXBOMnRMMTFNd3daY3I0MFJ0ZVhIUmgyWlF5RWRYNEVkTmhsZjZBNUt0c3lobHhISHpaVVBZUmNWTHpySVRtS3NMNldVd0IzUXNrR0tCUDZSdDdHcEpqS0xNdG1yWGNvYlJhUXJsT0JjVjFDcGxjVk9SUlZGLzlpZHR4cHNKN0lnM0lKaTlPTHRkTnBkY3dnYnlsY3VSWTduUytadlBUR2lxV0Z4UUdtcUxFc0pFTnhxYkdaT2Z5RGJpSmthcmdBamV1VHhWckhMWnFMUWpWakc5STdDbXNZTFlaQXlsM0dqVVEyb25DMFM4UTZ0VFZ5YmYyUmY2bmdqRysxR1NrUmFXbHpxeE9EblZ6VmlmVXhmN1kxTHlEaGluT1NhSE9NbExWYmF1MGdJVGdobndheVkxZlFza0Q2eEtKYmRzWnhOTVk1ZVhKQVJ2RUZacGtyR1lXenprTFNDZTBjeVB2bmoxRVhNVEpxYnNVcUEzemNseTRLeXJuQ2hQdnhyRzdDWmpJR2tsMEhZK3FuZzlWOEhnTzJTeGtqaTFSMHZ0cmJjVVNYVks1TGhmWEpBbnpKVkJQYnZaNDNORlVJUk82emQxelRzUU5xVlY1MEFIa3NSN05wemJ3RXZZNUxGb0tITldPSmJkbWtJUy9ZSWdyV2tCYlNabDRFcmM5S2xzdkNISHMzbmVBYVpneVhQemZzckdGTUlITU12L2hYZEFNamJSWUNNOGxKdDVwQnJENUN5bDF3TVJjcU5EZm9yZWJJRkltZ0VNQmpiWUlYdE9iWVdDMENONnFTd2ZGbGk4RTVoS21yWXRUYkVlVFZ0Q29LeEtIaXlCUGdXMUMyZkRDbHVSalp5ZDNNZ0pIREpDRUxXQWd5ZGY4RWhkVUZMZXhEYXhNR3k0WGx3cjBoREU2aG50MGpOajZsaWpTN2JGZUtHY1lXVHFNMUExMThOZ01LWGsxTUlJZ1pBV2daYldObkY3TkJFMkxpempoYklpRm1xQmVKVkdUd2FiZHlPU3YzV0FoNklxUWtJRUw1Y3V6Y21xNWFwWEoxYnV0R29SMWpjMUVjYUdlMmdpU21JRFRtUzVESGppU29MVnFidGU5bGxCcHF4Ry9Db1lGa1YvcW1zOFVKZlB5WExKVldXOVdKY0xVMWdRSEdiS1hUdG1paml5NlduV014aWo5cEhMUUJ6K3lMZnpBYXNpTlZyaE1odnJCU3Q5bzBwVGNIck42bHphd2pVbUo4RER1bkZqK0VIQmw3aEJva0tjQ1ZMMmpzVGNqRG8zQ1ltRnk4bDIrTGdXMFJJcXRVQzhWWks0ZEx4V2xtTFdaTXkrQldoOVJWcCtETFFGaHBTVVJ4d2VheGJEUDVMUnhMQjg3cURlLzdWQk5GdExsWVFMMWFDKzB5dGxwN2laZ25OOEowSCtiRkJobkxsV0RhcjRLZ0MzZ1lqNmhrTUpMN0llNTdHYWJuWlI4VllhOUFxdDZjUklKcE4zYkFsV2FZbzZxcnRUallwT3FLc0Q5TUluazBSQXJCU1hlblpiNGF0SVdKSkZ2Q3ErRFZJazJXRm1QbnJLT2pWeUxaRVRoNU9od2lvUW84a01iUUFZT1VoNUNUT3dkUktMYUF5YW1tbEUwMUYrRDZPakhNUDdGSGo3K2pLZE1XU0pMaWN0Q2lvdnNqRlBtd1psVW1Pdyt3dnhUYmNvQVFJZHFEVGNBSGZVVWtuTTc1bEZnc0Z2N1VGWEZyYkQ2VFZjcjRBTDBtRWo1YU56aUdkZjBtQzZTZ3VtN0pNeks1Tk8wamRYbHhSWW1zdHUxMVQvbXNMOFJzVm9kOFNpek1LcWVGVlNFRVY1bHhEbG5rWWx0TXNVN0h2MnVVY1VFTHBoSTBZM1FyaExobkdRRFdrWVN4dzdrcGZrZlFqN3V0aXB0Z0gyYWdMVGI4RzdBblNwNUZsWmN5YnRlYSIsImt5YmVyUHJlS2V5U2lnbmF0dXJlIjoiNU1maEd4eXNqNE9nMkpXU3VIUFZ4ZjJFMk0zdmlJbzkrY0VSa0JlT09iV2QyblVYeU5qM0tsZGtiUFNzNVc0UllNSmZOZk41YzAzQkc2ODlIaHgyRGc9PSIsImlkZW50aXR5S2V5IjoiQmFkZjFWcXlUeXhOeU1SSE13c1hPeHByVzdWbEJ2d2NPV2RhLzNXMGR4b2MifQ==',
    fc: '9cfac19745521cd6db3c99dd0d1d33d9c747521d490b95d3a473eda9563c8181',
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
