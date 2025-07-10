import UIKit

struct Theme {
    
    // MARK: - Colors
    struct Colors {
        static let primary = UIColor(red: 0.53, green: 0.32, blue: 0.93, alpha: 1.0) // Purple #8651ED
        static let secondary = UIColor(red: 0.67, green: 0.44, blue: 0.96, alpha: 1.0) // Light Purple #AB70F5
        static let accent = UIColor(red: 0.29, green: 0.17, blue: 0.68, alpha: 1.0) // Dark Purple #4A2BAD
        static let background = UIColor.systemBackground
        static let surface = UIColor.secondarySystemBackground
        static let error = UIColor.systemRed
        static let success = UIColor.systemGreen
        static let warning = UIColor.systemOrange
        
        // Text colors
        static let textPrimary = UIColor.label
        static let textSecondary = UIColor.secondaryLabel
        static let textTertiary = UIColor.tertiaryLabel
        static let textOnPrimary = UIColor.white
        
        // Card colors
        static let cardBackground = UIColor.systemBackground
        static let cardShadow = UIColor.black.withAlphaComponent(0.08)
        
        // Gradients
        static let gradientStart = UIColor(red: 0.53, green: 0.32, blue: 0.93, alpha: 1.0)
        static let gradientEnd = UIColor(red: 0.67, green: 0.44, blue: 0.96, alpha: 1.0)
    }
    
    // MARK: - Fonts
    struct Fonts {
        static let largeTitle = UIFont.systemFont(ofSize: 34, weight: .bold)
        static let title1 = UIFont.systemFont(ofSize: 28, weight: .bold)
        static let title2 = UIFont.systemFont(ofSize: 22, weight: .bold)
        static let title3 = UIFont.systemFont(ofSize: 20, weight: .semibold)
        static let headline = UIFont.systemFont(ofSize: 17, weight: .semibold)
        static let body = UIFont.systemFont(ofSize: 17, weight: .regular)
        static let callout = UIFont.systemFont(ofSize: 16, weight: .regular)
        static let subheadline = UIFont.systemFont(ofSize: 15, weight: .regular)
        static let footnote = UIFont.systemFont(ofSize: 13, weight: .regular)
        static let caption1 = UIFont.systemFont(ofSize: 12, weight: .regular)
        static let caption2 = UIFont.systemFont(ofSize: 11, weight: .regular)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 24
    }
    
    // MARK: - Shadows
    struct Shadow {
        static let light = ShadowStyle(color: Colors.cardShadow, opacity: 0.05, offset: CGSize(width: 0, height: 2), radius: 4)
        static let medium = ShadowStyle(color: Colors.cardShadow, opacity: 0.08, offset: CGSize(width: 0, height: 4), radius: 8)
        static let heavy = ShadowStyle(color: Colors.cardShadow, opacity: 0.12, offset: CGSize(width: 0, height: 8), radius: 16)
    }
    
    struct ShadowStyle {
        let color: UIColor
        let opacity: Float
        let offset: CGSize
        let radius: CGFloat
    }
}

// MARK: - UIView Extensions
extension UIView {
    func applyShadow(_ shadow: Theme.ShadowStyle) {
        layer.shadowColor = shadow.color.cgColor
        layer.shadowOpacity = shadow.opacity
        layer.shadowOffset = shadow.offset
        layer.shadowRadius = shadow.radius
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
}

// MARK: - UIButton Extensions
extension UIButton {
    func applyPrimaryStyle() {
        backgroundColor = Theme.Colors.primary
        setTitleColor(Theme.Colors.textOnPrimary, for: .normal)
        titleLabel?.font = Theme.Fonts.headline
        layer.cornerRadius = Theme.CornerRadius.medium
        applyShadow(Theme.Shadow.medium)
    }
    
    func applySecondaryStyle() {
        backgroundColor = .clear
        setTitleColor(Theme.Colors.primary, for: .normal)
        titleLabel?.font = Theme.Fonts.headline
        layer.cornerRadius = Theme.CornerRadius.medium
        layer.borderWidth = 1
        layer.borderColor = Theme.Colors.primary.cgColor
    }
    
    func applyTertiaryStyle() {
        backgroundColor = Theme.Colors.surface
        setTitleColor(Theme.Colors.primary, for: .normal)
        titleLabel?.font = Theme.Fonts.headline
        layer.cornerRadius = Theme.CornerRadius.medium
        applyShadow(Theme.Shadow.light)
    }
}