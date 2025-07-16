import Foundation
import Capacitor
import UIKit

/**
 * iOS Native Plugin for enhanced native functionality
 * Provides native iOS components and behaviors to Capacitor web app
 */
@objc(IOSNativePlugin)
public class IOSNativePlugin: CAPPlugin {
    
    override public func load() {
        // Configure status bar for native appearance
        configureStatusBar()
        
        // Setup navigation bar styling
        configureNavigationBar()
        
        // Setup safe area handling
        configureSafeArea()
    }
    
    // MARK: - Status Bar Configuration
    
    @objc func setStatusBarStyle(_ call: CAPPluginCall) {
        let style = call.getString("style") ?? "default"
        
        DispatchQueue.main.async {
            if style == "light" {
                self.bridge?.statusBarStyle = .lightContent
            } else {
                self.bridge?.statusBarStyle = .default
            }
            self.bridge?.setStatusBarStyle()
        }
        
        call.resolve()
    }
    
    @objc func hideStatusBar(_ call: CAPPluginCall) {
        let hidden = call.getBool("hidden") ?? false
        
        DispatchQueue.main.async {
            self.bridge?.statusBarVisible = !hidden
            self.bridge?.setStatusBarVisible()
        }
        
        call.resolve()
    }
    
    // MARK: - Navigation Bar
    
    @objc func createNativeNavigationBar(_ call: CAPPluginCall) {
        let title = call.getString("title") ?? ""
        let backgroundColor = call.getString("backgroundColor")
        let textColor = call.getString("textColor")
        let large = call.getBool("large") ?? false
        
        DispatchQueue.main.async {
            let navigationBar = self.createNavigationBar(
                title: title,
                backgroundColor: backgroundColor,
                textColor: textColor,
                large: large
            )
            
            if let webView = self.bridge?.webView {
                webView.superview?.addSubview(navigationBar)
                
                // Adjust webview frame
                navigationBar.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    navigationBar.topAnchor.constraint(equalTo: webView.superview!.safeAreaLayoutGuide.topAnchor),
                    navigationBar.leadingAnchor.constraint(equalTo: webView.superview!.leadingAnchor),
                    navigationBar.trailingAnchor.constraint(equalTo: webView.superview!.trailingAnchor),
                    navigationBar.heightAnchor.constraint(equalToConstant: large ? 96 : 44)
                ])
                
                // Adjust webview top constraint
                webView.frame.origin.y = large ? 96 : 44
                webView.frame.size.height -= large ? 96 : 44
            }
        }
        
        call.resolve([
            "success": true
        ])
    }
    
    private func createNavigationBar(title: String, backgroundColor: String?, textColor: String?, large: Bool) -> UIView {
        let navigationBar = UIView()
        navigationBar.backgroundColor = backgroundColor?.hexToUIColor() ?? UIColor.systemBackground
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = textColor?.hexToUIColor() ?? UIColor.label
        titleLabel.font = large ? UIFont.systemFont(ofSize: 34, weight: .bold) : UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        
        navigationBar.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        if large {
            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: navigationBar.leadingAnchor, constant: 16),
                titleLabel.trailingAnchor.constraint(equalTo: navigationBar.trailingAnchor, constant: -16),
                titleLabel.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -8)
            ])
        } else {
            NSLayoutConstraint.activate([
                titleLabel.centerXAnchor.constraint(equalTo: navigationBar.centerXAnchor),
                titleLabel.centerYAnchor.constraint(equalTo: navigationBar.centerYAnchor)
            ])
        }
        
        // Add separator line
        let separator = UIView()
        separator.backgroundColor = UIColor.separator
        navigationBar.addSubview(separator)
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: navigationBar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: navigationBar.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        
        return navigationBar
    }
    
    // MARK: - Native Alert
    
    @objc func showNativeAlert(_ call: CAPPluginCall) {
        let title = call.getString("title") ?? ""
        let message = call.getString("message") ?? ""
        let buttons = call.getArray("buttons", JSObject.self) ?? []
        
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            for (index, buttonData) in buttons.enumerated() {
                let buttonTitle = buttonData["text"] as? String ?? "OK"
                let buttonStyle = buttonData["style"] as? String ?? "default"
                
                let style: UIAlertAction.Style = {
                    switch buttonStyle {
                    case "destructive":
                        return .destructive
                    case "cancel":
                        return .cancel
                    default:
                        return .default
                    }
                }()
                
                let action = UIAlertAction(title: buttonTitle, style: style) { _ in
                    call.resolve([
                        "buttonIndex": index,
                        "buttonTitle": buttonTitle
                    ])
                }
                
                alert.addAction(action)
            }
            
            self.bridge?.viewController?.present(alert, animated: true)
        }
        
        if buttons.isEmpty {
            call.resolve()
        }
    }
    
    // MARK: - Native Action Sheet
    
    @objc func showNativeActionSheet(_ call: CAPPluginCall) {
        let title = call.getString("title")
        let message = call.getString("message")
        let buttons = call.getArray("buttons", JSObject.self) ?? []
        
        DispatchQueue.main.async {
            let actionSheet = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
            
            for (index, buttonData) in buttons.enumerated() {
                let buttonTitle = buttonData["text"] as? String ?? "Option"
                let buttonStyle = buttonData["style"] as? String ?? "default"
                
                let style: UIAlertAction.Style = {
                    switch buttonStyle {
                    case "destructive":
                        return .destructive
                    case "cancel":
                        return .cancel
                    default:
                        return .default
                    }
                }()
                
                let action = UIAlertAction(title: buttonTitle, style: style) { _ in
                    call.resolve([
                        "buttonIndex": index,
                        "buttonTitle": buttonTitle
                    ])
                }
                
                actionSheet.addAction(action)
            }
            
            // For iPad support
            if let popover = actionSheet.popoverPresentationController {
                popover.sourceView = self.bridge?.viewController?.view
                popover.sourceRect = CGRect(x: self.bridge?.viewController?.view.bounds.midX ?? 0,
                                         y: self.bridge?.viewController?.view.bounds.midY ?? 0,
                                         width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            self.bridge?.viewController?.present(actionSheet, animated: true)
        }
        
        if buttons.isEmpty {
            call.resolve()
        }
    }
    
    // MARK: - Haptic Feedback
    
    @objc func triggerHapticFeedback(_ call: CAPPluginCall) {
        let type = call.getString("type") ?? "impact"
        let intensity = call.getString("intensity") ?? "medium"
        
        DispatchQueue.main.async {
            switch type {
            case "impact":
                let impactStyle: UIImpactFeedbackGenerator.FeedbackStyle = {
                    switch intensity {
                    case "light":
                        return .light
                    case "heavy":
                        return .heavy
                    default:
                        return .medium
                    }
                }()
                let impactFeedback = UIImpactFeedbackGenerator(style: impactStyle)
                impactFeedback.impactOccurred()
                
            case "selection":
                let selectionFeedback = UISelectionFeedbackGenerator()
                selectionFeedback.selectionChanged()
                
            case "notification":
                let notificationType: UINotificationFeedbackGenerator.FeedbackType = {
                    switch intensity {
                    case "success":
                        return .success
                    case "warning":
                        return .warning
                    case "error":
                        return .error
                    default:
                        return .success
                    }
                }()
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(notificationType)
                
            default:
                break
            }
        }
        
        call.resolve()
    }
    
    // MARK: - Safe Area
    
    @objc func getSafeAreaInsets(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            if let window = UIApplication.shared.windows.first {
                let safeAreaInsets = window.safeAreaInsets
                call.resolve([
                    "top": safeAreaInsets.top,
                    "bottom": safeAreaInsets.bottom,
                    "left": safeAreaInsets.left,
                    "right": safeAreaInsets.right
                ])
            } else {
                call.resolve([
                    "top": 0,
                    "bottom": 0,
                    "left": 0,
                    "right": 0
                ])
            }
        }
    }
    
    // MARK: - Native Modal Presentation
    
    @objc func presentNativeModal(_ call: CAPPluginCall) {
        let url = call.getString("url") ?? ""
        let title = call.getString("title") ?? ""
        
        DispatchQueue.main.async {
            let modalViewController = NativeModalViewController()
            modalViewController.urlString = url
            modalViewController.modalTitle = title
            modalViewController.completion = { result in
                call.resolve([
                    "dismissed": true,
                    "result": result
                ])
            }
            
            let navigationController = UINavigationController(rootViewController: modalViewController)
            navigationController.modalPresentationStyle = .pageSheet
            
            self.bridge?.viewController?.present(navigationController, animated: true)
        }
    }
    
    // MARK: - Device Information
    
    @objc func getDeviceInfo(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let device = UIDevice.current
            let screen = UIScreen.main
            
            call.resolve([
                "model": device.model,
                "systemName": device.systemName,
                "systemVersion": device.systemVersion,
                "screenWidth": screen.bounds.width,
                "screenHeight": screen.bounds.height,
                "screenScale": screen.scale,
                "isIPhone": device.userInterfaceIdiom == .phone,
                "isIPad": device.userInterfaceIdiom == .pad
            ])
        }
    }
    
    // MARK: - Configuration Methods
    
    private func configureStatusBar() {
        DispatchQueue.main.async {
            if #available(iOS 13.0, *) {
                self.bridge?.statusBarStyle = .default
            } else {
                self.bridge?.statusBarStyle = .default
            }
            self.bridge?.setStatusBarStyle()
        }
    }
    
    private func configureNavigationBar() {
        DispatchQueue.main.async {
            if let navigationController = self.bridge?.viewController?.navigationController {
                navigationController.navigationBar.isTranslucent = true
                navigationController.navigationBar.shadowImage = UIImage()
                
                if #available(iOS 13.0, *) {
                    let appearance = UINavigationBarAppearance()
                    appearance.configureWithTransparentBackground()
                    appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
                    
                    navigationController.navigationBar.standardAppearance = appearance
                    navigationController.navigationBar.scrollEdgeAppearance = appearance
                    navigationController.navigationBar.compactAppearance = appearance
                }
            }
        }
    }
    
    private func configureSafeArea() {
        // Ensure webview respects safe area
        DispatchQueue.main.async {
            if let webView = self.bridge?.webView {
                webView.translatesAutoresizingMaskIntoConstraints = false
                
                if let superview = webView.superview {
                    NSLayoutConstraint.activate([
                        webView.topAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.topAnchor),
                        webView.leadingAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.leadingAnchor),
                        webView.trailingAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.trailingAnchor),
                        webView.bottomAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.bottomAnchor)
                    ])
                }
            }
        }
    }
}

// MARK: - Extensions

extension String {
    func hexToUIColor() -> UIColor {
        var hex = self
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        
        guard hex.count == 6 else {
            return UIColor.clear
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)
        
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}

// MARK: - Native Modal View Controller

class NativeModalViewController: UIViewController {
    var urlString: String = ""
    var modalTitle: String = ""
    var completion: ((String) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.systemBackground
        title = modalTitle
        
        // Add close button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissModal)
        )
        
        // Add your modal content here
        setupModalContent()
    }
    
    private func setupModalContent() {
        let label = UILabel()
        label.text = "Native Modal Content"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 17)
        
        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    @objc private func dismissModal() {
        completion?("dismissed")
        dismiss(animated: true)
    }
}