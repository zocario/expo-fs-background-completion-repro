# [iOS] expo-file-system: the system completion handler of `handleEventsForBackgroundURLSession` is never called

## Summary

When iOS wakes an Expo app for background `URLSession` events, the app never calls the completion handler that iOS passes to `application(_:handleEventsForBackgroundURLSession:completionHandler:)`. This happens for `expo-file-system`'s own background downloads and for the background sessions of any other module. `expo` depends on `expo-file-system`, so every Expo app on iOS has this problem.

Two `expo-file-system` app delegate subscribers keep the handler and never call it. `ExpoAppDelegateSubscriberManager` calls the system handler only after every subscriber calls its own handler.

## Environment

- expo 58.0.25, expo-file-system 58.0.13 (also 58.0.12), expo-modules-core 58.1.0, react-native 0.88.1
- Xcode 27.1, iOS 27.0 simulator (iPhone 18 Pro), Release build
- The code is the same on `main` at 95b6828fbbbbeacab306b830ec5aa0f47d93c498.
- `npx expo-doctor@latest`: 20/20 checks passed. No issues detected!

<details><summary><code>npx expo-env-info</code></summary>

```
  expo-env-info 2.2.1 environment info:
    System:
      OS: macOS 27.0.1
      Shell: 5.9 - /bin/zsh
    Binaries:
      Node: 22.16.0 - ~/.nvm/versions/node/v22.16.0/bin/node
      Yarn: 1.22.22 - ~/.nvm/versions/node/v22.16.0/bin/yarn
      npm: 11.7.0 - ~/.nvm/versions/node/v22.16.0/bin/npm
      Watchman: 2025.03.10.00 - /opt/homebrew/bin/watchman
    Managers:
      CocoaPods: 1.17.0 - /opt/homebrew/bin/pod
    SDKs:
      iOS SDK:
        Platforms: DriverKit 27.0, iOS 27.1, macOS 27.0, tvOS 27.0, visionOS 27.0, watchOS 27.0
    IDEs:
      Android Studio: 2026.2 AI-262.9437.185.2621.16467767
      Xcode: 27.1/27A9275 - /usr/bin/xcodebuild
    npmPackages:
      expo: ~58.0.25 => 58.0.25 
      react: 19.3.0 => 19.3.0 
      react-native: 0.88.1 => 0.88.1 
    npmGlobalPackages:
      eas-cli: 27.9.0
    Expo Workflow: bare
```

</details>

## Minimal reproduction

Repository: <LINK TO THE PUBLISHED REPRO>

The app is `create-expo-app --template blank-typescript@sdk-58` plus:

- A local Expo module (`modules/background-session-probe`) with a background `URLSession` (`repro.probe.background-session`, `sessionSendsLaunchEvents = true`). Its `ExpoAppDelegateSubscriber` keeps the handler for its own session and calls it in `urlSessionDidFinishEvents(forBackgroundURLSession:)`.
- A config plugin that overrides `AppDelegate.application(_:handleEventsForBackgroundURLSession:completionHandler:)` only to log two things: when iOS delivers the event, and when Expo calls the system handler. It also logs whether the system handler was called 28 s after the event (the `expo-file-system` fallback timer is 25 s).
- A Node server that answers each request after 20 s.

Steps:

1. `npm install && npx expo prebuild -p ios`
2. `node server/slow-server.mjs`
3. `scripts/build-install.sh <simulator udid>`
4. `scripts/run-scenario.sh <simulator udid> terminate logs/stock.log`. The script launches the app, which starts a background upload to the server, then terminates the app with `xcrun simctl terminate`. iOS relaunches the app in the background when the upload finishes.
5. For `expo-file-system`'s own session: tap **Start expo-file-system background download** (it calls `File.createDownloadTask(..., { sessionType: 'background' }).downloadAsync()`), then put the app in the background.

## Expected behavior

After the module that owns the session calls its handler, Expo calls the system completion handler: `AppDelegate: SYSTEM completion handler called for ...` is logged.

## Actual behavior

Expo never calls the system completion handler. The app is still awake 28 s after the event.

Another module's session (step 4):

```
09:57:59.170 [76429] probe: background upload task 1 started on repro.probe.background-session
09:58:21.191 [76493] AppDelegate: iOS delivered handleEventsForBackgroundURLSession(repro.probe.background-session), app state 2
09:58:21.191 [76493] probe subscriber: received handleEventsForBackgroundURLSession(repro.probe.background-session)
09:58:21.283 [76493] probe: task 1 completed, HTTP 200, error: none
09:58:21.283 [76493] probe: urlSessionDidFinishEvents(forBackgroundURLSession: repro.probe.background-session)
09:58:21.283 [76493] probe: calling the completion handler it received from Expo's aggregator
09:58:50.592 [76493] AppDelegate: 28 s after delivery (expo-file-system fallback is 25 s), system handler called for repro.probe.background-session: NO
```

`expo-file-system`'s own background download (step 5):

```
10:11:25.667 [81125] AppDelegate: iOS delivered handleEventsForBackgroundURLSession(dev.repro.bgcompletion.expo-file-system.network-task.background), app state 2
10:11:55.068 [81125] AppDelegate: 28 s after delivery (expo-file-system fallback is 25 s), system handler called for dev.repro.bgcompletion.expo-file-system.network-task.background: NO
```

With the fix below, both scenarios log the system call within 40 ms. Then iOS suspends the app, and the 28 s log does not appear:

```
10:07:04.311 [79814] probe: calling the completion handler it received from Expo's aggregator
10:07:04.333 [79814] AppDelegate: SYSTEM completion handler called for repro.probe.background-session

10:09:24.449 [80343] AppDelegate: iOS delivered handleEventsForBackgroundURLSession(dev.repro.bgcompletion.expo-file-system.network-task.background), app state 2
10:09:24.489 [80343] AppDelegate: SYSTEM completion handler called for dev.repro.bgcompletion.expo-file-system.network-task.background
```

## Root cause

[`ExpoAppDelegateSubscriberManager`](https://github.com/expo/expo/blob/95b6828fbbbbeacab306b830ec5aa0f47d93c498/packages/expo-modules-core/ios/AppDelegates/ExpoAppDelegateSubscriberManager.swift#L174-L188) gives each subscriber an aggregated handler. It calls the system handler only when every subscriber has called it. In this app, three subscribers respond to the selector:

1. The probe module. It calls its handler.
2. `EXLegacyAppDelegateWrapper`, which `expo` registers in [`EXAppDelegatesLoader.m#L30`](https://github.com/expo/expo/blob/95b6828fbbbbeacab306b830ec5aa0f47d93c498/packages/expo/ios/ExpoLoader/EXAppDelegatesLoader.m#L30). It [forwards the event](https://github.com/expo/expo/blob/95b6828fbbbbeacab306b830ec5aa0f47d93c498/packages/expo/ios/ExpoObjC/AppDelegates/EXLegacyAppDelegateWrapper.m#L142-L170) to the singleton modules that implement it. The only one is `expo-file-system`'s `EXSessionHandler` ([registered as a singleton](https://github.com/expo/expo/blob/95b6828fbbbbeacab306b830ec5aa0f47d93c498/packages/expo-file-system/ios/Legacy/EXSessionTasks/EXSessionHandler.m#L15)). `EXSessionHandler` [stores every handler](https://github.com/expo/expo/blob/95b6828fbbbbeacab306b830ec5aa0f47d93c498/packages/expo-file-system/ios/Legacy/EXSessionTasks/EXSessionHandler.m#L46). It calls a handler only from `invokeCompletionHandlerForSessionIdentifier:`. Nothing calls that method on this singleton since #23943 (SDK 50): the session dispatchers now call `FileSystemBackgroundSessionHandler` ([legacy](https://github.com/expo/expo/blob/95b6828fbbbbeacab306b830ec5aa0f47d93c498/packages/expo-file-system/ios/Legacy/FileSystemLegacyModule.swift#L45), [new API](https://github.com/expo/expo/blob/95b6828fbbbbeacab306b830ec5aa0f47d93c498/packages/expo-file-system/ios/FileSystemDownloadTask.swift#L152)). So this subscriber never answers, for any session.
3. `FileSystemBackgroundSessionHandler`. It [keeps every handler](https://github.com/expo/expo/blob/95b6828fbbbbeacab306b830ec5aa0f47d93c498/packages/expo-file-system/ios/Legacy/FileSystemBackgroundSessionHandler.swift#L37-L42), whatever the session identifier. [`completeIfReady`](https://github.com/expo/expo/blob/95b6828fbbbbeacab306b830ec5aa0f47d93c498/packages/expo-file-system/ios/BackgroundSessionCompletion.swift#L66-L68) requires `finishedEvents`, which [`finishEvents`](https://github.com/expo/expo/blob/95b6828fbbbbeacab306b830ec5aa0f47d93c498/packages/expo-file-system/ios/BackgroundSessionCompletion.swift#L55-L57) sets only from `expo-file-system`'s own `urlSessionDidFinishEvents`. The 25 s fallback timer does not help, because it also waits for `finishedEvents`. So this subscriber never answers for another module's session.

For `expo-file-system`'s own sessions, subscriber 3 answers, but subscriber 2 still blocks the system handler.

There is also a latent problem in `EXLegacyAppDelegateWrapper` (package `expo`). Its check is [`if (delegatesCompleted && delegatingCompleted == allDelegates)`](https://github.com/expo/expo/blob/95b6828fbbbbeacab306b830ec5aa0f47d93c498/packages/expo/ios/ExpoObjC/AppDelegates/EXLegacyAppDelegateWrapper.m#L151), which compares the `BOOL` with the count. It completes only when exactly one singleton module implements the method. With zero modules (for example, if `EXSessionHandler` is removed) or with two, the wrapper never answers. The intended check is probably `delegatingCompleted && delegatesCompleted == allDelegates`.

## Impact

iOS does not learn that the app finished processing the events. It cannot take the app switcher snapshot, and the app stays awake until iOS suspends it. Apps that use a background `URLSession` from another library (uploads, downloads) are affected, and so are `expo-file-system` background downloads.

## Proposed fix

I have a fix in `expo-file-system` only (PR: <LINK>):

- `EXSessionHandler` calls the handler at once. It is unused since #23943, but I kept it registered: if it is removed, `EXLegacyAppDelegateWrapper` has no singleton module for this method, and its check above then never completes.
- `FileSystemBackgroundSessionHandler` calls the handler at once for any session that it does not own. It owns the new API's background session (fixed identifier) and the legacy background sessions created in this process (random identifiers, now registered when the session is created).

The check in `EXLegacyAppDelegateWrapper` can be fixed separately in `expo`.
