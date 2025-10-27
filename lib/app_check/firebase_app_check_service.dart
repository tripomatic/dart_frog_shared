import 'dart:async';
import 'dart:io';

import 'package:dart_firebase_admin/app_check.dart';
import 'package:dart_firebase_admin/dart_firebase_admin.dart';
import 'package:logging/logging.dart';

import 'package:dart_frog_shared/app_check/app_check_config.dart';

/// Service for interacting with Firebase App Check
class FirebaseAppCheckService {
  /// Creates a new Firebase App Check service
  FirebaseAppCheckService(this._config);

  final AppCheckConfig _config;
  final _logger = Logger('FirebaseAppCheckService');

  FirebaseAdminApp? _app;
  AppCheck? _appCheck;
  Completer<AppCheck>? _initCompleter;

  /// Gets or initializes the Firebase Admin app and AppCheck
  ///
  /// Thread-safe singleton initialization with automatic retry on failure.
  /// Multiple concurrent calls will wait for the first initialization to complete.
  Future<AppCheck> get _firebaseAppCheck async {
    if (_appCheck != null) return _appCheck!;

    // Atomically create completer if needed and capture it locally
    final completer = _initCompleter ??= Completer<AppCheck>();

    // If another thread is already initializing, wait for their result
    if (_initCompleter != completer) {
      return _initCompleter!.future;
    }

    try {
      // Use the service account JSON directly (no base64 decoding needed)
      final serviceAccountJson = _config.serviceAccountJson;

      // Create a temporary file for the service account
      final tempFile = File.fromUri(
        Uri.file(
          '${Directory.systemTemp.path}/dart-frog-shared-firebase-service-account-${DateTime.now().millisecondsSinceEpoch}.json',
        ),
      );

      try {
        // Write the service account JSON to the temp file
        await tempFile.writeAsString(serviceAccountJson);

        // Initialize Firebase Admin SDK
        _app = FirebaseAdminApp.initializeApp(_config.firebaseProjectId, Credential.fromServiceAccount(tempFile));

        // Create AppCheck instance
        _appCheck = AppCheck(_app!);

        _logger.info('Firebase Admin SDK initialized for project: ${_config.firebaseProjectId}');

        completer.complete(_appCheck!);
        return _appCheck!;
      } finally {
        // Always delete the temp file for security
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (e, stack) {
      _logger.severe('Failed to initialize Firebase Admin SDK', e, stack);
      completer.completeError(e, stack);
      // Allow retry on next call by resetting the completer
      _initCompleter = null;
      rethrow;
    }
  }

  /// Verifies an App Check token
  Future<bool> verifyToken(String token) async {
    if (_config.enableDevMode) {
      _logger.info('App Check bypassed in dev mode');
      return true;
    }

    try {
      final appCheck = await _firebaseAppCheck;
      await appCheck.verifyToken(token);

      _logger.fine('App Check token verified successfully');
      return true;
    } catch (e, stack) {
      _logger.warning('App Check token verification failed', e, stack);
      return false;
    }
  }

  /// Closes the Firebase connection and resets initialization state
  ///
  /// After calling this method, the next call to [verifyToken] will
  /// reinitialize the Firebase Admin SDK.
  void close() {
    _app?.close();
    _app = null;
    _appCheck = null;
    _initCompleter = null;
  }
}
