import UIKit

struct AppColors {
    // Primary brand colors from website
    static let primaryPurple = UIColor(red: 0.4, green: 0.498, blue: 0.918, alpha: 1.0) // #667eea
    static let secondaryPurple = UIColor(red: 0.463, green: 0.294, blue: 0.635, alpha: 1.0) // #764ba2
    static let accentBlue = UIColor(red: 0.31, green: 0.675, blue: 0.996, alpha: 1.0) // #4facfe
    static let lightBlue = UIColor(red: 0.0, green: 0.949, blue: 0.996, alpha: 1.0) // #00f2fe
    
    // Gradient colors
    static let primaryGradient = [primaryPurple.cgColor, secondaryPurple.cgColor]
    static let accentGradient = [accentBlue.cgColor, lightBlue.cgColor]
    
    // UI Colors
    static let backgroundColor = UIColor.systemBackground
    static let cardBackground = UIColor.secondarySystemBackground
    static let separatorColor = UIColor.separator
    static let textPrimary = UIColor.label
    static let textSecondary = UIColor.secondaryLabel
    
    // Glass effect colors
    static let glassBackground = UIColor.white.withAlphaComponent(0.25)
    static let glassBorder = UIColor.white.withAlphaComponent(0.18)
    
    // Success/Error colors
    static let successGreen = UIColor.systemGreen
    static let errorRed = UIColor.systemRed
    static let warningOrange = UIColor.systemOrange
}

extension UIView {
    func addGradient(colors: [CGColor], startPoint: CGPoint = CGPoint(x: 0, y: 0), endPoint: CGPoint = CGPoint(x: 1, y: 1)) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = colors
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
        gradientLayer.frame = bounds
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    func addGlassEffect() {
        backgroundColor = AppColors.glassBackground
        layer.borderWidth = 1
        layer.borderColor = AppColors.glassBorder.cgColor
        layer.cornerRadius = 16
        
        // Add backdrop blur effect
        let blurEffect = UIBlurEffect(style: .light)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(blurView, at: 0)
    }
}