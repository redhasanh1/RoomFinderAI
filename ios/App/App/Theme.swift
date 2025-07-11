import UIKit

struct Theme {
    
    // MARK: - Colors (Website-matched Design)
    struct Colors {
        // Primary Purple Gradient - matches website #667eea to #764ba2
        static let primary = UIColor(red: 0.40, green: 0.50, blue: 0.92, alpha: 1.0) // #667eea
        static let primaryDark = UIColor(red: 0.46, green: 0.29, blue: 0.64, alpha: 1.0) // #764ba2
        
        // Secondary Pink Gradient - matches website #f093fb to #f5576c
        static let secondary = UIColor(red: 0.94, green: 0.58, blue: 0.98, alpha: 1.0) // #f093fb
        static let secondaryDark = UIColor(red: 0.96, green: 0.34, blue: 0.42, alpha: 1.0) // #f5576c
        
        // Accent Blue Gradient - matches website #4facfe to #00f2fe
        static let accent = UIColor(red: 0.31, green: 0.69, blue: 0.99, alpha: 1.0) // #4facfe
        static let accentDark = UIColor(red: 0.00, green: 0.95, blue: 0.99, alpha: 1.0) // #00f2fe
        
        // Success Gradient - matches website #11998e to #38ef7d
        static let success = UIColor(red: 0.07, green: 0.60, blue: 0.56, alpha: 1.0) // #11998e
        static let successLight = UIColor(red: 0.22, green: 0.94, blue: 0.49, alpha: 1.0) // #38ef7d
        
        // Warning Gradient - matches website #fc4a1a to #f7b733
        static let warning = UIColor(red: 0.99, green: 0.29, blue: 0.10, alpha: 1.0) // #fc4a1a
        static let warningLight = UIColor(red: 0.97, green: 0.72, blue: 0.20, alpha: 1.0) // #f7b733
        
        static let error = UIColor.systemRed
        
        // Background system matching website #f8fafc to #e2e8f0
        static let background = UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1.0) // #f8fafc
        static let backgroundSecondary = UIColor(red: 0.89, green: 0.91, blue: 0.94, alpha: 1.0) // #e2e8f0
        
        // Glass morphism surfaces
        static let surface = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.8) // Glass effect
        static let surfaceSecondary = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.6)
        static let surfaceTertiary = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.4)
        
        // Text colors matching website
        static let textPrimary = UIColor(red: 0.11, green: 0.11, blue: 0.15, alpha: 1.0) // #1c1c26
        static let textSecondary = UIColor(red: 0.51, green: 0.55, blue: 0.63, alpha: 1.0) // #828ba1
        static let textTertiary = UIColor(red: 0.71, green: 0.75, blue: 0.83, alpha: 1.0) // #b5bfd5
        static let textOnPrimary = UIColor.white
        static let textOnDark = UIColor.white
        
        // Card colors with premium effects
        static let cardBackground = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
        static let cardShadow = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.08)
        static let cardBorder = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.2)
        
        // Gradients matching website
        static let gradientPrimary = [primary, primaryDark]
        static let gradientSecondary = [secondary, secondaryDark]
        static let gradientAccent = [accent, accentDark]
        static let gradientSuccess = [success, successLight]
        static let gradientWarning = [warning, warningLight]
        static let gradientBackground = [background, backgroundSecondary]
    }
    
    // MARK: - Fonts (Website-matched Typography)
    struct Fonts {
        // Inter font family simulation with system fonts
        static let displayLarge = UIFont.systemFont(ofSize: 48, weight: .black) // Hero titles
        static let displayMedium = UIFont.systemFont(ofSize: 36, weight: .bold) // Section headers
        static let displaySmall = UIFont.systemFont(ofSize: 28, weight: .bold) // Card titles
        
        static let largeTitle = UIFont.systemFont(ofSize: 34, weight: .bold)
        static let title1 = UIFont.systemFont(ofSize: 28, weight: .bold)
        static let title2 = UIFont.systemFont(ofSize: 22, weight: .bold)
        static let title3 = UIFont.systemFont(ofSize: 20, weight: .semibold)
        static let headline = UIFont.systemFont(ofSize: 17, weight: .semibold)
        static let body = UIFont.systemFont(ofSize: 17, weight: .regular)
        static let bodyEmphasized = UIFont.systemFont(ofSize: 17, weight: .medium)
        static let callout = UIFont.systemFont(ofSize: 16, weight: .regular)
        static let subheadline = UIFont.systemFont(ofSize: 15, weight: .regular)
        static let footnote = UIFont.systemFont(ofSize: 13, weight: .regular)
        static let caption1 = UIFont.systemFont(ofSize: 12, weight: .regular)
        static let caption2 = UIFont.systemFont(ofSize: 11, weight: .regular)
        
        // Special fonts for premium elements
        static let buttonLarge = UIFont.systemFont(ofSize: 18, weight: .semibold)
        static let buttonMedium = UIFont.systemFont(ofSize: 16, weight: .semibold)
        static let buttonSmall = UIFont.systemFont(ofSize: 14, weight: .medium)
        
        // Monospace for metrics and data
        static let monospace = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium)
    }
    
    // MARK: - Spacing (Website-matched Scale)
    struct Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
        
        // Component-specific spacing
        static let cardPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 40
        static let itemSpacing: CGFloat = 12
        static let buttonHeight: CGFloat = 48
        static let inputHeight: CGFloat = 52
    }
    
    // MARK: - Corner Radius (Premium Glass Design)
    struct CornerRadius {
        static let xs: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 24
        static let xxlarge: CGFloat = 32
        
        // Component-specific radius
        static let button: CGFloat = 12
        static let card: CGFloat = 16
        static let modal: CGFloat = 20
        static let pill: CGFloat = 25
    }
    
    // MARK: - Shadows (Premium 3D Effects)
    struct Shadow {
        static let none = ShadowStyle(color: .clear, opacity: 0.0, offset: .zero, radius: 0)
        static let xs = ShadowStyle(color: Colors.cardShadow, opacity: 0.03, offset: CGSize(width: 0, height: 1), radius: 2)
        static let small = ShadowStyle(color: Colors.cardShadow, opacity: 0.05, offset: CGSize(width: 0, height: 2), radius: 4)
        static let medium = ShadowStyle(color: Colors.cardShadow, opacity: 0.08, offset: CGSize(width: 0, height: 4), radius: 8)
        static let large = ShadowStyle(color: Colors.cardShadow, opacity: 0.12, offset: CGSize(width: 0, height: 8), radius: 16)
        static let xlarge = ShadowStyle(color: Colors.cardShadow, opacity: 0.16, offset: CGSize(width: 0, height: 12), radius: 24)
        
        // Colored shadows for premium effects
        static let primaryGlow = ShadowStyle(color: Colors.primary, opacity: 0.3, offset: CGSize(width: 0, height: 4), radius: 12)
        static let secondaryGlow = ShadowStyle(color: Colors.secondary, opacity: 0.3, offset: CGSize(width: 0, height: 4), radius: 12)
        static let accentGlow = ShadowStyle(color: Colors.accent, opacity: 0.3, offset: CGSize(width: 0, height: 4), radius: 12)
    }
    
    struct ShadowStyle {
        let color: UIColor
        let opacity: Float
        let offset: CGSize
        let radius: CGFloat
    }
    
    // MARK: - Blur Effects (Glass Morphism)
    struct BlurEffect {
        static let light = UIBlurEffect(style: .systemUltraThinMaterial)
        static let medium = UIBlurEffect(style: .systemThinMaterial)
        static let heavy = UIBlurEffect(style: .systemMaterial)
        static let prominent = UIBlurEffect(style: .systemThickMaterial)
    }
    
    // MARK: - Animation Timing
    struct Animation {
        static let quick: TimeInterval = 0.2
        static let standard: TimeInterval = 0.3
        static let slow: TimeInterval = 0.5
        static let verySlow: TimeInterval = 0.8
        
        // Website-matched easing
        static let easeOut = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.320, 1)
        static let easeInOut = CAMediaTimingFunction(name: .easeInEaseOut)
        static let spring = CAMediaTimingFunction(controlPoints: 0.175, 0.885, 0.32, 1.275)
    }
}

// MARK: - UIView Extensions
extension UIView {
    func applyShadow(_ shadow: Theme.ShadowStyle) {
        layer.shadowColor = shadow.color.cgColor
        layer.shadowOpacity = shadow.opacity
        layer.shadowOffset = shadow.offset
        layer.shadowRadius = shadow.radius
        layer.masksToBounds = false
    }
    
    func applyGradient(colors: [UIColor], startPoint: CGPoint = CGPoint(x: 0, y: 0), endPoint: CGPoint = CGPoint(x: 1, y: 1)) {
        let gradient = CAGradientLayer()
        gradient.colors = colors.map { $0.cgColor }
        gradient.startPoint = startPoint
        gradient.endPoint = endPoint
        gradient.frame = bounds
        
        if let existingGradient = layer.sublayers?.first(where: { $0 is CAGradientLayer }) {
            existingGradient.removeFromSuperlayer()
        }
        
        layer.insertSublayer(gradient, at: 0)
    }
    
    // Glass morphism effect matching website
    func applyGlassEffect(alpha: CGFloat = 0.8, blur: UIBlurEffect.Style = .systemUltraThinMaterial) {
        backgroundColor = UIColor.white.withAlphaComponent(alpha)
        
        // Add blur effect
        let blurEffect = UIBlurEffect(style: blur)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(blurView, at: 0)
        
        // Add border for glass effect
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        layer.cornerRadius = Theme.CornerRadius.card
        
        // Subtle shadow
        applyShadow(Theme.Shadow.medium)
    }
    
    // Premium card style matching website
    func applyPremiumCardStyle() {
        backgroundColor = Theme.Colors.cardBackground
        layer.cornerRadius = Theme.CornerRadius.card
        applyShadow(Theme.Shadow.large)
        
        // Add subtle border
        layer.borderWidth = 1
        layer.borderColor = Theme.Colors.cardBorder.cgColor
    }
    
    // Floating animation for premium feel
    func addFloatingAnimation() {
        let animation = CABasicAnimation(keyPath: "transform.translation.y")
        animation.duration = 3.0
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.fromValue = -8
        animation.toValue = 8
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "floating")
    }
    
    // Hover effect simulation (for interactive elements)
    func addHoverEffect() {
        let originalTransform = transform
        
        UIView.animate(withDuration: Theme.Animation.quick, animations: {
            self.transform = originalTransform.scaledBy(x: 1.02, y: 1.02)
            self.applyShadow(Theme.Shadow.xlarge)
        }) { _ in
            UIView.animate(withDuration: Theme.Animation.quick) {
                self.transform = originalTransform
                self.applyShadow(Theme.Shadow.medium)
            }
        }
    }
}

// MARK: - UIButton Extensions
extension UIButton {
    func applyPrimaryStyle() {
        applyGradient(colors: Theme.Colors.gradientPrimary)
        setTitleColor(Theme.Colors.textOnPrimary, for: .normal)
        titleLabel?.font = Theme.Fonts.buttonLarge
        layer.cornerRadius = Theme.CornerRadius.button
        applyShadow(Theme.Shadow.primaryGlow)
        
        // Add subtle border
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
    }
    
    func applySecondaryStyle() {
        backgroundColor = .clear
        setTitleColor(Theme.Colors.primary, for: .normal)
        titleLabel?.font = Theme.Fonts.buttonMedium
        layer.cornerRadius = Theme.CornerRadius.button
        layer.borderWidth = 2
        layer.borderColor = Theme.Colors.primary.cgColor
        applyShadow(Theme.Shadow.small)
    }
    
    func applyTertiaryStyle() {
        backgroundColor = Theme.Colors.surface
        setTitleColor(Theme.Colors.textPrimary, for: .normal)
        titleLabel?.font = Theme.Fonts.buttonMedium
        layer.cornerRadius = Theme.CornerRadius.button
        applyShadow(Theme.Shadow.medium)
        
        // Glass effect
        layer.borderWidth = 1
        layer.borderColor = Theme.Colors.cardBorder.cgColor
    }
    
    // Website-style magnetic button with gradient
    func applyMagneticStyle() {
        applyGradient(colors: Theme.Colors.gradientAccent)
        setTitleColor(Theme.Colors.textOnPrimary, for: .normal)
        titleLabel?.font = Theme.Fonts.buttonLarge
        layer.cornerRadius = Theme.CornerRadius.button
        applyShadow(Theme.Shadow.accentGlow)
        
        // Add interactive animation
        addTarget(self, action: #selector(magneticPressed), for: .touchDown)
        addTarget(self, action: #selector(magneticReleased), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    // Glass morphism button
    func applyGlassStyle() {
        backgroundColor = UIColor.white.withAlphaComponent(0.2)
        setTitleColor(Theme.Colors.textPrimary, for: .normal)
        titleLabel?.font = Theme.Fonts.buttonMedium
        layer.cornerRadius = Theme.CornerRadius.button
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        applyShadow(Theme.Shadow.medium)
        
        // Add backdrop blur effect
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.layer.cornerRadius = Theme.CornerRadius.button
        blurView.clipsToBounds = true
        insertSubview(blurView, at: 0)
    }
    
    // Floating action button style
    func applyFloatingStyle() {
        backgroundColor = Theme.Colors.primary
        setTitleColor(Theme.Colors.textOnPrimary, for: .normal)
        titleLabel?.font = Theme.Fonts.buttonMedium
        layer.cornerRadius = frame.height / 2
        applyShadow(Theme.Shadow.large)
        
        // Add floating animation
        addFloatingAnimation()
    }
    
    @objc private func magneticPressed() {
        UIView.animate(withDuration: Theme.Animation.quick, animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.applyShadow(Theme.Shadow.small)
        })
    }
    
    @objc private func magneticReleased() {
        UIView.animate(withDuration: Theme.Animation.standard, 
                       delay: 0, 
                       usingSpringWithDamping: 0.8, 
                       initialSpringVelocity: 0.5, 
                       options: .curveEaseOut, 
                       animations: {
            self.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            self.applyShadow(Theme.Shadow.accentGlow)
        })
    }
}