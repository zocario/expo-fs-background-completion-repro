// Overrides AppDelegate.application(_:handleEventsForBackgroundURLSession:completionHandler:) only to
// log when iOS delivers the event and when Expo finally calls the SYSTEM completion handler.
const { withAppDelegate } = require('expo/config-plugins');

const MARKER = '// [BGREPRO] system completion log';

const OVERRIDE = `
  ${MARKER}
  public override func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    NSLog("[BGREPRO] AppDelegate: iOS delivered handleEventsForBackgroundURLSession(%@), app state %ld", identifier, application.applicationState.rawValue)
    var systemHandlerCalled = false
    DispatchQueue.main.asyncAfter(deadline: .now() + 28) {
      NSLog("[BGREPRO] AppDelegate: 28 s after delivery (expo-file-system fallback is 25 s), system handler called for %@: %@", identifier, systemHandlerCalled ? "YES" : "NO")
    }
    super.application(application, handleEventsForBackgroundURLSession: identifier) {
      systemHandlerCalled = true
      NSLog("[BGREPRO] AppDelegate: SYSTEM completion handler called for %@", identifier)
      completionHandler()
    }
  }
`;

module.exports = function withSystemCompletionLog(config) {
  return withAppDelegate(config, (config) => {
    const { contents } = config.modResults;
    if (contents.includes(MARKER)) return config;
    const anchor = /class AppDelegate: ExpoAppDelegate[^{]*\{\n/;
    if (!anchor.test(contents)) throw new Error('withSystemCompletionLog: AppDelegate anchor not found');
    config.modResults.contents = contents.replace(anchor, (match) => match + OVERRIDE);
    return config;
  });
};
