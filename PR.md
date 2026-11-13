Title: [expo-file-system][ios] Complete background session events that expo-file-system does not hold

## Why

Fixes #<ISSUE NUMBER>.

On iOS, Expo never calls the system completion handler of `application(_:handleEventsForBackgroundURLSession:completionHandler:)`. This happens for `expo-file-system` background downloads and for the background sessions of other modules.

`ExpoAppDelegateSubscriberManager` calls the system handler only after every subscriber calls its own handler. Two `expo-file-system` subscribers never call it:

- The legacy `EXSessionHandler` singleton, reached through `EXLegacyAppDelegateWrapper`, stores every handler. Since #23943, the session dispatchers call `FileSystemBackgroundSessionHandler`, so nothing calls the stored handlers.
- `FileSystemBackgroundSessionHandler` waits for the final `URLSession` event. It receives that event only for its own sessions.

## How

- `EXSessionHandler` calls the handler at once. I did not remove this singleton. If it is removed, `EXLegacyAppDelegateWrapper` has no singleton module for this method. Its check `delegatesCompleted && delegatingCompleted == allDelegates` then never completes. That check is in `expo` and needs a separate pull request.
- `FileSystemBackgroundSessionHandler` keeps the handler only for its own sessions. It calls the handler at once for any other session. Its own sessions are:
  - the new API's background session, which has a fixed identifier (`NetworkTaskSessionManager.backgroundSessionIdentifier` is now internal instead of private);
  - the legacy background sessions created in this process. They have random identifiers, so `FileSystemLegacyModule` registers each one when it creates it. A lock protects the set, because the module can create the session off the main thread.

I also considered letting the 25 s fallback timer complete a session that has no registered task. That still makes iOS wait 25 s for every other module's session, and it does not fix `EXSessionHandler`.

There is no performance impact: one set lookup for each background session event.

## Test Plan

Unit tests: I added `test_FileSystemBackgroundSessionHandler.swift`. I ran the `ExpoFileSystem` test spec on the iOS 27.0 simulator (Xcode 27.1). I ran it in an SDK 58 app (expo-file-system 58.0.13, built from source), not in `apps/bare-expo`, with `ExpoModulesTestCore` removed from the test spec (these tests do not use it).

- Before the change: the 2 new tests fail (`Expectation failed: calls == 1`). The 11 tests in `test_BackgroundSessionCompletion.swift` pass.
- After the change: 13 of 13 tests pass.

I did not run `et native-unit-tests` or `et check-packages` in this repository.

Runtime: iOS 27.0 simulator, Release build, with this repro: <LINK TO THE PUBLISHED REPRO>. A config plugin logs when `AppDelegate` gets the event and when Expo calls the system handler.

1. A local module starts a background upload on its own session (`repro.probe.background-session`). `xcrun simctl terminate` stops the app. iOS relaunches the app in the background when the upload finishes. The module calls its handler in `urlSessionDidFinishEvents`.
   - Before: Expo never calls the system handler. 28 s after the event, the app is still awake.
   - After: Expo calls the system handler 22 ms after the module calls its handler.
2. `File.createDownloadTask(url, directory, { sessionType: 'background' }).downloadAsync()`, then the app goes to the background.
   - Before: Expo never calls the system handler.
   - After: Expo calls the system handler 40 ms after the event.

I did not test a legacy `downloadAsync` background session at runtime.

## Screenshots

No UI change.

## Checklist

- [x] I added a changeset and followed [this short guide](https://github.com/expo/expo/blob/main/CONTRIBUTING.md#-before-submitting)
- [ ] This diff will work correctly for `npx expo prebuild` & EAS Build (eg: updated a module plugin).
- [ ] Conforms with the [Documentation Writing Style Guide](https://github.com/expo/expo/blob/main/guides/Expo%20Documentation%20Writing%20Style%20Guide.md)
