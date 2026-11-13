import ExpoModulesCore
import UIKit

func probeLog(_ message: String) {
  NSLog("[BGREPRO] %@", message)
}

/// A background URLSession that is NOT owned by expo-file-system, like any third-party
/// upload/download module would create.
final class ProbeSession: NSObject, URLSessionDataDelegate {
  static let identifier = "repro.probe.background-session"
  static let shared = ProbeSession()

  /// The handler this module received from Expo's aggregator for its own session.
  var pendingCompletion: (() -> Void)?

  lazy var session: URLSession = {
    let configuration = URLSessionConfiguration.background(withIdentifier: Self.identifier)
    configuration.sessionSendsLaunchEvents = true
    configuration.isDiscretionary = false
    return URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
  }()

  func startUpload(to url: URL) -> String {
    let body = FileManager.default.temporaryDirectory.appendingPathComponent("probe-body.bin")
    try? Data(repeating: 0x2A, count: 64 * 1024).write(to: body)
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    let task = session.uploadTask(with: request, fromFile: body)
    task.resume()
    probeLog("probe: background upload task \(task.taskIdentifier) started on \(Self.identifier) -> \(url)")
    return Self.identifier
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    let status = (task.response as? HTTPURLResponse)?.statusCode ?? -1
    probeLog("probe: task \(task.taskIdentifier) completed, HTTP \(status), error: \(error?.localizedDescription ?? "none")")
  }

  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    probeLog("probe: urlSessionDidFinishEvents(forBackgroundURLSession: \(session.configuration.identifier ?? "nil"))")
    guard let completion = pendingCompletion else {
      probeLog("probe: no handler to call (app was in the foreground)")
      return
    }
    pendingCompletion = nil
    probeLog("probe: calling the completion handler it received from Expo's aggregator")
    completion()
  }
}

public final class BackgroundSessionProbeAppDelegateSubscriber: ExpoAppDelegateSubscriber {
  public func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    guard identifier == ProbeSession.identifier else {
      // Not our session: answer at once so the aggregator does not wait for us.
      completionHandler()
      return
    }
    probeLog("probe subscriber: received handleEventsForBackgroundURLSession(\(identifier))")
    ProbeSession.shared.pendingCompletion = completionHandler
    // Recreate the session so URLSession delivers the pending events to our delegate.
    _ = ProbeSession.shared.session
  }
}

public final class BackgroundSessionProbeModule: Module {
  public func definition() -> ModuleDefinition {
    Name("BackgroundSessionProbe")

    Function("startUpload") { (url: URL) -> String in
      return ProbeSession.shared.startUpload(to: url)
    }
  }
}
