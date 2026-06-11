/// Push Notification Service — placeholder for FCM integration.
///
/// ## How to enable Firebase Cloud Messaging (FCM)
///
/// 1. Add Firebase to your Flutter app:
///    ```
///    flutter pub add firebase_core firebase_messaging
///    flutterfire configure   # generates google-services.json + GoogleService-Info.plist
///    ```
///
/// 2. In `main()`, initialise Firebase before `runApp()`:
///    ```dart
///    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
///    ```
///
/// 3. Replace the stub methods below with real `FirebaseMessaging` calls.
///
/// 4. Register the token with the backend:
///    ```dart
///    final token = await getToken();
///    if (token != null) {
///      await apiClient.registerPushToken(token, platform: Platform.isIOS ? 'IOS' : 'ANDROID');
///    }
///    ```
///    Backend endpoint: `POST /api/v1/notifications/push/register`
///
/// 5. Handle foreground messages with `onMessage` — e.g. show a SnackBar or
///    in-app notification widget.
///
/// 6. Background / terminated messages are handled by FCM automatically via
///    the OS notification tray; no additional Flutter code is needed.

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  /// Initialise the FCM plugin and request permissions.
  ///
  /// Call once from [main()] after [Firebase.initializeApp()].
  Future<void> initialize() async {
    // TODO: uncomment after adding firebase_messaging dependency
    //
    // final messaging = FirebaseMessaging.instance;
    // await requestPermission();
    // FirebaseMessaging.onMessage.listen(onMessage);
    // FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  }

  /// Ask the OS (iOS / macOS / Web) for notification permission.
  ///
  /// Android 13+ also requires a runtime permission — FCM handles this
  /// automatically when you call [requestPermission] on Android.
  Future<void> requestPermission() async {
    // TODO: uncomment after adding firebase_messaging dependency
    //
    // final settings = await FirebaseMessaging.instance.requestPermission(
    //   alert: true,
    //   badge: true,
    //   sound: true,
    // );
    // debugPrint('Push permission: ${settings.authorizationStatus}');
  }

  /// Returns the FCM registration token for this device, or null if FCM is
  /// not available (e.g. iOS simulator without APNS).
  Future<String?> getToken() async {
    // TODO: uncomment after adding firebase_messaging dependency
    //
    // return FirebaseMessaging.instance.getToken();
    return null;
  }

  /// Handle a foreground push message.
  ///
  /// By default FCM does NOT show a heads-up notification on Android when the
  /// app is in the foreground — you must display it yourself here.
  void onMessage(dynamic message) {
    // TODO: uncomment after adding firebase_messaging dependency
    //
    // final notification = message.notification;
    // if (notification != null) {
    //   // Show an in-app SnackBar, dialog, or local notification.
    //   debugPrint('Foreground push: ${notification.title} — ${notification.body}');
    // }
  }
}

// TODO: background message handler must be a top-level function (not a method):
//
// @pragma('vm:entry-point')
// Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   debugPrint('Background push: ${message.messageId}');
// }
