import 'dart:async';
import 'dart:io';

/// Signature for the DNS resolver used to probe reachability. Defaults to
/// [InternetAddress.lookup]; injectable so tests can simulate online/offline
/// without touching the real network.
typedef HostLookup = Future<List<InternetAddress>> Function(String host);

/// Checks whether the device can actually reach the internet — not merely
/// whether a network interface is up.
///
/// A phone can show full Wi-Fi bars yet have no working uplink (captive
/// portal, dead router, mobile data switched off). A quick DNS lookup of a
/// real host is the cheapest dependency-free probe that distinguishes "online"
/// from "connected to a network that goes nowhere".
///
/// Used as a pre-flight gate before features that need the network up front —
/// today the voice / transcription flows, which otherwise let the user record
/// a whole message before failing at the upload step. See [ConnectivityGuard].
class ConnectivityService {
  ConnectivityService({
    Duration timeout = const Duration(seconds: 3),
    List<String> probeHosts = _defaultProbeHosts,
    HostLookup? lookup,
  })  : _timeout = timeout,
        _probeHosts = probeHosts,
        _lookup = lookup ?? InternetAddress.lookup;

  /// Default shared instance. Mirrors the `.instance` singleton convention
  /// used by [AiGateway] and friends so call sites stay terse.
  static final ConnectivityService instance = ConnectivityService();

  /// Canonical user-facing copy for the offline state. Single source of truth
  /// so the pre-flight gate and the post-hoc AI error mapper read identically.
  static const String offlineMessage =
      'No internet connection. Please check your network and try again.';

  /// Probed in order; the first host that resolves wins. The primary host is
  /// the actual Gemini endpoint (what the voice flows ultimately call), with a
  /// well-known fallback in case that one host is being blocked or rerouted.
  static const List<String> _defaultProbeHosts = [
    'generativelanguage.googleapis.com',
    'google.com',
  ];

  final Duration _timeout;
  final List<String> _probeHosts;
  final HostLookup _lookup;

  /// True if any probe host resolves within [_timeout]. Never throws — any
  /// failure (no route, timeout, lookup error) is treated as "offline".
  Future<bool> hasInternet() async {
    for (final host in _probeHosts) {
      if (await _canResolve(host)) return true;
    }
    return false;
  }

  Future<bool> _canResolve(String host) async {
    try {
      final addresses = await _lookup(host).timeout(_timeout);
      return addresses.isNotEmpty && addresses.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
