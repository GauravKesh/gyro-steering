//
//  AppDelegate.swift
//  GyroSteer - iOS Transmitter
//
//  Enforces landscape orientation locking for the racing cockpit.
//

#if os(iOS)
import UIKit

public final class AppDelegate: NSObject, UIApplicationDelegate {
    public static var orientationLock = UIInterfaceOrientationMask.landscape

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        return true
    }

    public func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}
#endif
