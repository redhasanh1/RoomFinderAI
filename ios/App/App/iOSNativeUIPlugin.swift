import Foundation
import Capacitor
import UIKit

/**
 * iOS Native UI Plugin for Capacitor
 * Provides native iOS UI components and interactions
 */
@objc(iOSNativeUIPlugin)
public class iOSNativeUIPlugin: CAPPlugin {
    
    override public func load() {
        // Plugin loaded
        print("🍎 iOS Native UI Plugin loaded")
    }
    
    /**
     * Show native iOS navigation bar
     */
    @objc func showNativeNavBar(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let bridge = self.bridge,
                  let viewController = bridge.viewController else {
                call.reject("Could not access view controller")
                return
            }
            
            let title = call.getString("title") ?? "App"
            let showBackButton = call.getBool("showBackButton") ?? false
            let backgroundColor = call.getString("backgroundColor") ?? "#FFFFFF"
            let textColor = call.getString("textColor") ?? "#000000"
            
            // Create and configure navigation controller if needed
            if viewController.navigationController == nil {
                let navController = UINavigationController(rootViewController: viewController)
                
                // Configure appearance
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(hexString: backgroundColor)
                appearance.titleTextAttributes = [
                    .foregroundColor: UIColor(hexString: textColor)
                ]
                
                navController.navigationBar.standardAppearance = appearance
                navController.navigationBar.scrollEdgeAppearance = appearance
                
                // Present navigation controller
                if let window = UIApplication.shared.windows.first {
                    window.rootViewController = navController
                }
            }
            
            // Set title
            viewController.title = title
            
            // Configure back button
            if showBackButton {
                let backButton = UIBarButtonItem(
                    title: "Back",
                    style: .plain,
                    target: self,
                    action: #selector(self.backButtonTapped)
                )
                viewController.navigationItem.leftBarButtonItem = backButton
            }
            
            call.resolve()
        }
    }
    
    /**
     * Show native iOS alert
     */
    @objc func showNativeAlert(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let bridge = self.bridge,
                  let viewController = bridge.viewController else {
                call.reject("Could not access view controller")
                return
            }
            
            let title = call.getString("title") ?? "Alert"
            let message = call.getString("message") ?? ""
            let buttons = call.getArray("buttons", JSObject.self) ?? []
            
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            // Add buttons
            for (index, buttonData) in buttons.enumerated() {
                let buttonTitle = buttonData["text"] as? String ?? "OK"
                let buttonStyle = self.getAlertActionStyle(buttonData["style"] as? String)
                
                let action = UIAlertAction(title: buttonTitle, style: buttonStyle) { _ in
                    call.resolve([
                        "buttonIndex": index,
                        "buttonTitle": buttonTitle
                    ])
                }
                alertController.addAction(action)
            }
            
            // Add default OK button if no buttons provided
            if buttons.isEmpty {
                let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                    call.resolve([
                        "buttonIndex": 0,
                        "buttonTitle": "OK"
                    ])
                }
                alertController.addAction(okAction)
            }
            
            viewController.present(alertController, animated: true)
        }
    }
    
    /**
     * Show native iOS action sheet
     */
    @objc func showNativeActionSheet(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let bridge = self.bridge,
                  let viewController = bridge.viewController else {
                call.reject("Could not access view controller")
                return
            }
            
            let title = call.getString("title")
            let message = call.getString("message")
            let buttons = call.getArray("buttons", JSObject.self) ?? []
            
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
            
            // Add buttons
            for (index, buttonData) in buttons.enumerated() {
                let buttonTitle = buttonData["text"] as? String ?? "Option"
                let buttonStyle = self.getAlertActionStyle(buttonData["style"] as? String)
                
                let action = UIAlertAction(title: buttonTitle, style: buttonStyle) { _ in
                    call.resolve([
                        "buttonIndex": index,
                        "buttonTitle": buttonTitle
                    ])
                }
                alertController.addAction(action)
            }
            
            // Add cancel button
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                call.resolve([
                    "buttonIndex": -1,
                    "buttonTitle": "Cancel"
                ])
            }
            alertController.addAction(cancelAction)
            
            // Configure for iPad
            if let popover = alertController.popoverPresentationController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            viewController.present(alertController, animated: true)
        }
    }
    
    /**
     * Configure native status bar
     */
    @objc func configureStatusBar(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let style = call.getString("style") ?? "default"
            let hidden = call.getBool("hidden") ?? false
            
            // Set status bar style
            var statusBarStyle: UIStatusBarStyle = .default
            switch style {
            case "light":
                statusBarStyle = .lightContent
            case "dark":
                if #available(iOS 13.0, *) {
                    statusBarStyle = .darkContent
                } else {
                    statusBarStyle = .default
                }
            default:
                statusBarStyle = .default
            }
            
            // Apply status bar configuration
            if let bridge = self.bridge,
               let viewController = bridge.viewController {
                
                // Hide/show status bar
                UIApplication.shared.isStatusBarHidden = hidden
                
                // Set preferred status bar style
                viewController.setNeedsStatusBarAppearanceUpdate()
            }
            
            call.resolve()
        }
    }
    
    /**
     * Show native loading indicator
     */
    @objc func showNativeLoading(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let bridge = self.bridge,
                  let viewController = bridge.viewController else {
                call.reject("Could not access view controller")
                return
            }
            
            let message = call.getString("message") ?? "Loading..."
            
            // Create loading view
            let loadingView = UIView(frame: viewController.view.bounds)
            loadingView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            loadingView.tag = 999 // Tag for identification
            
            // Create container
            let containerView = UIView()
            containerView.backgroundColor = UIColor.systemBackground
            containerView.layer.cornerRadius = 16
            containerView.translatesAutoresizingMaskIntoConstraints = false
            
            // Create activity indicator
            let activityIndicator = UIActivityIndicatorView(style: .large)
            activityIndicator.startAnimating()
            activityIndicator.translatesAutoresizingMaskIntoConstraints = false
            
            // Create label
            let label = UILabel()
            label.text = message
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 16)
            label.textColor = UIColor.label
            label.translatesAutoresizingMaskIntoConstraints = false
            
            // Add subviews
            containerView.addSubview(activityIndicator)
            containerView.addSubview(label)
            loadingView.addSubview(containerView)
            viewController.view.addSubview(loadingView)
            
            // Setup constraints
            NSLayoutConstraint.activate([
                containerView.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
                containerView.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor),
                containerView.widthAnchor.constraint(equalToConstant: 120),
                containerView.heightAnchor.constraint(equalToConstant: 100),
                
                activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                activityIndicator.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
                
                label.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                label.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 10),
                label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
                label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10)
            ])
            
            call.resolve()
        }
    }
    
    /**
     * Hide native loading indicator
     */
    @objc func hideNativeLoading(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let bridge = self.bridge,
                  let viewController = bridge.viewController else {
                call.reject("Could not access view controller")
                return
            }
            
            // Remove loading view
            if let loadingView = viewController.view.viewWithTag(999) {
                UIView.animate(withDuration: 0.3, animations: {
                    loadingView.alpha = 0
                }) { _ in
                    loadingView.removeFromSuperview()
                }
            }
            
            call.resolve()
        }
    }
    
    /**
     * Show native toast message
     */
    @objc func showNativeToast(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let bridge = self.bridge,
                  let viewController = bridge.viewController else {
                call.reject("Could not access view controller")
                return
            }
            
            let message = call.getString("message") ?? ""
            let duration = call.getDouble("duration") ?? 3.0
            
            // Create toast view
            let toastView = UIView()
            toastView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
            toastView.layer.cornerRadius = 25
            toastView.translatesAutoresizingMaskIntoConstraints = false
            
            // Create label
            let label = UILabel()
            label.text = message
            label.textColor = UIColor.white
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 16)
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            
            toastView.addSubview(label)
            viewController.view.addSubview(toastView)
            
            // Setup constraints
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: toastView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: toastView.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: toastView.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(equalTo: toastView.trailingAnchor, constant: -20),
                
                toastView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
                toastView.bottomAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
                toastView.heightAnchor.constraint(equalToConstant: 50)
            ])
            
            // Animate in
            toastView.alpha = 0
            toastView.transform = CGAffineTransform(translationX: 0, y: 50)
            
            UIView.animate(withDuration: 0.3, animations: {
                toastView.alpha = 1
                toastView.transform = .identity
            }) { _ in
                // Animate out after duration
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    UIView.animate(withDuration: 0.3, animations: {
                        toastView.alpha = 0
                        toastView.transform = CGAffineTransform(translationX: 0, y: 50)
                    }) { _ in
                        toastView.removeFromSuperview()
                    }
                }
            }
            
            call.resolve()
        }
    }
    
    /**
     * Configure navigation bar appearance
     */
    @objc func configureNavigationBar(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let bridge = self.bridge,
                  let viewController = bridge.viewController,
                  let navigationController = viewController.navigationController else {
                call.reject("Navigation controller not available")
                return
            }
            
            let backgroundColor = call.getString("backgroundColor") ?? "#FFFFFF"
            let textColor = call.getString("textColor") ?? "#000000"
            let translucent = call.getBool("translucent") ?? true
            let hidden = call.getBool("hidden") ?? false
            
            // Configure appearance
            let appearance = UINavigationBarAppearance()
            
            if translucent {
                appearance.configureWithDefaultBackground()
            } else {
                appearance.configureWithOpaqueBackground()
            }
            
            appearance.backgroundColor = UIColor(hexString: backgroundColor)
            appearance.titleTextAttributes = [.foregroundColor: UIColor(hexString: textColor)]
            
            navigationController.navigationBar.standardAppearance = appearance
            navigationController.navigationBar.scrollEdgeAppearance = appearance
            navigationController.navigationBar.isHidden = hidden
            
            call.resolve()
        }
    }
    
    // MARK: - Helper Methods
    
    @objc private func backButtonTapped() {
        if let bridge = self.bridge {
            bridge.triggerJSEvent(eventName: "nativeBackButton", target: "window")
        }
    }
    
    private func getAlertActionStyle(_ style: String?) -> UIAlertAction.Style {
        switch style {
        case "destructive":
            return .destructive
        case "cancel":
            return .cancel
        default:
            return .default
        }
    }
}

// MARK: - UIColor Extension

extension UIColor {
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}