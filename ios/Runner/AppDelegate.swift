import AutomaticAssessmentConfiguration
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KioskPlugin") {
      KioskPlugin.register(with: registrar)
    }
  }
}

/// Kiosk control on iOS, tried in this order:
/// 1. Assessment mode (`AEAssessmentSession`). Needs the
///    `com.apple.developer.automatic-assessment-configuration` entitlement from Apple,
///    but no MDM or supervision.
/// 2. Autonomous Single App Mode (`requestGuidedAccessSession`). Only on supervised
///    devices whose MDM profile allows this app.
/// 3. Guided Access turned on by hand (triple-click the side button). Dart polls
///    `getStatus` and waits for it.
final class KioskPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel
  private var session: AnyObject?  // AEAssessmentSession, iOS 13.4+
  private var assessmentActive = false
  private var singleAppModeActive = false
  private var pendingStart: FlutterResult?
  private var observers: [NSObjectProtocol] = []

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "exam_browser/kiosk", binaryMessenger: registrar.messenger())
    let instance = KioskPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
    instance.observeSystemEvents()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getStatus": result(status())
    case "startKiosk": startKiosk(result)
    case "stopKiosk":
      stopKiosk()
      result(status())
    case "releaseDeviceOwner": result(false)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func status(message: String? = nil) -> [String: Any] {
    let guided = UIAccessibility.isGuidedAccessEnabled
    let mode: String
    if assessmentActive {
      mode = "assessment"
    } else if guided {
      mode = singleAppModeActive ? "single_app_mode" : "guided_access"
    } else {
      mode = "none"
    }
    var s: [String: Any] = [
      "platform": "ios",
      "active": assessmentActive || guided,
      "fullLock": assessmentActive || guided,
      "mode": mode,
      "deviceOwner": false,
    ]
    if let message = message { s["message"] = message }
    return s
  }

  private func startKiosk(_ result: @escaping FlutterResult) {
    UIApplication.shared.isIdleTimerDisabled = true
    if assessmentActive || UIAccessibility.isGuidedAccessEnabled || pendingStart != nil {
      result(status())
      return
    }
    if #available(iOS 13.4, *) {
      let s = AEAssessmentSession(configuration: AEAssessmentConfiguration())
      s.delegate = self
      session = s
      pendingStart = result
      s.begin()  // -> assessmentSessionDidBegin / failedToBeginWithError
    } else {
      requestSingleAppMode(result, reason: nil)
    }
  }

  private func requestSingleAppMode(_ result: @escaping FlutterResult, reason: String?) {
    UIAccessibility.requestGuidedAccessSession(enabled: true) { [weak self] success in
      DispatchQueue.main.async {
        guard let self = self else { return }
        self.singleAppModeActive = success
        if success {
          result(self.status())
        } else {
          var msg = "Aktifkan Akses Terpandu: Setelan > Aksesibilitas > Akses Terpandu, "
            + "lalu klik tiga kali tombol samping di aplikasi ini."
          if let reason = reason { msg += " (Mode asesmen tidak tersedia: \(reason))" }
          result(self.status(message: msg))
        }
      }
    }
  }

  private func stopKiosk() {
    UIApplication.shared.isIdleTimerDisabled = false
    if #available(iOS 13.4, *), let s = session as? AEAssessmentSession, s.isActive {
      s.end()
    }
    if singleAppModeActive {
      UIAccessibility.requestGuidedAccessSession(enabled: false) { [weak self] _ in
        DispatchQueue.main.async { self?.singleAppModeActive = false }
      }
    }
    // Guided Access turned on by hand can only be ended by the proctor (triple-click + passcode).
  }

  private func observeSystemEvents() {
    let center = NotificationCenter.default
    observers.append(
      center.addObserver(
        forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main
      ) { [weak self] _ in self?.report("screenshot") })
    observers.append(
      center.addObserver(
        forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main
      ) { [weak self] note in
        if let screen = note.object as? UIScreen, screen.isCaptured {
          self?.report("screen_recording")
        }
      })
  }

  fileprivate func report(_ type: String) {
    channel.invokeMethod("onViolation", arguments: type)
  }

  fileprivate func finishPendingStart(failure: String?) {
    guard let result = pendingStart else { return }
    pendingStart = nil
    if let failure = failure {
      requestSingleAppMode(result, reason: failure)
    } else {
      result(status())
    }
  }
}

@available(iOS 13.4, *)
extension KioskPlugin: AEAssessmentSessionDelegate {
  func assessmentSessionDidBegin(_ session: AEAssessmentSession) {
    assessmentActive = true
    finishPendingStart(failure: nil)
  }

  func assessmentSession(
    _ session: AEAssessmentSession, failedToBeginWithError error: Error
  ) {
    assessmentActive = false
    self.session = nil
    finishPendingStart(failure: error.localizedDescription)
  }

  func assessmentSession(_ session: AEAssessmentSession, wasInterruptedWithError error: Error) {
    // Apple requires the app to end the session; Dart sees kiosk inactive and locks the exam.
    report("assessment_interrupted")
    session.end()
  }

  func assessmentSessionDidEnd(_ session: AEAssessmentSession) {
    assessmentActive = false
    self.session = nil
  }
}
