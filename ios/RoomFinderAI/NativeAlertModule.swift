import Foundation
import UIKit

@objc(NativeAlertModule)
class NativeAlertModule: NSObject {
  
  @objc
  static func requiresMainQueueSetup() -> Bool {
    return true
  }
  
  @objc
  func showNativeAlert(_ title: String, message: String, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
    
    DispatchQueue.main.async {
      guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
        rejecter("NO_ROOT_VC", "No root view controller found", nil)
        return
      }
      
      let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
      
      alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
        resolver("OK_PRESSED")
      })
      
      alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
        resolver("CANCEL_PRESSED")
      })
      
      rootViewController.present(alert, animated: true, completion: nil)
    }
  }
  
  @objc
  func showActionSheet(_ title: String, message: String, options: [String], resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
    
    DispatchQueue.main.async {
      guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
        rejecter("NO_ROOT_VC", "No root view controller found", nil)
        return
      }
      
      let actionSheet = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
      
      for (index, option) in options.enumerated() {
        actionSheet.addAction(UIAlertAction(title: option, style: .default) { _ in
          resolver(index)
        })
      }
      
      actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
        resolver(-1)
      })
      
      // For iPad support
      if let popover = actionSheet.popoverPresentationController {
        popover.sourceView = rootViewController.view
        popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
        popover.permittedArrowDirections = []
      }
      
      rootViewController.present(actionSheet, animated: true, completion: nil)
    }
  }
  
  @objc
  func showConfirmDialog(_ title: String, message: String, confirmText: String, cancelText: String, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
    
    DispatchQueue.main.async {
      guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
        rejecter("NO_ROOT_VC", "No root view controller found", nil)
        return
      }
      
      let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
      
      alert.addAction(UIAlertAction(title: confirmText, style: .default) { _ in
        resolver(true)
      })
      
      alert.addAction(UIAlertAction(title: cancelText, style: .cancel) { _ in
        resolver(false)
      })
      
      rootViewController.present(alert, animated: true, completion: nil)
    }
  }
  
  @objc
  func getDeviceInfo(_ resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
    
    let deviceInfo: [String: Any] = [
      "model": UIDevice.current.model,
      "name": UIDevice.current.name,
      "systemName": UIDevice.current.systemName,
      "systemVersion": UIDevice.current.systemVersion,
      "identifierForVendor": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
      "isPhysicalDevice": true, // Always true for real devices
      "screenWidth": UIScreen.main.bounds.width,
      "screenHeight": UIScreen.main.bounds.height,
      "screenScale": UIScreen.main.scale
    ]
    
    resolver(deviceInfo)
  }
  
  @objc
  func hapticFeedback(_ type: String, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
    
    DispatchQueue.main.async {
      switch type.lowercased() {
      case "light":
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
      case "medium":
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
      case "heavy":
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
      case "success":
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
      case "warning":
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
      case "error":
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
      default:
        rejecter("INVALID_TYPE", "Invalid haptic feedback type", nil)
        return
      }
      
      resolver("HAPTIC_TRIGGERED")
    }
  }
}