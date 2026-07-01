import Foundation
import SwiftUI

// MARK: - String Extensions
extension String {
    // Email validation
    var isValidEmail: Bool {
        let emailRegEx = AppConstants.Validation.emailRegex
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: self)
    }
    
    // Phone number validation
    var isValidPhoneNumber: Bool {
        let phoneRegEx = AppConstants.Validation.phoneRegex
        let phonePred = NSPredicate(format:"SELF MATCHES %@", phoneRegEx)
        return phonePred.evaluate(with: self)
    }
    
    // Remove whitespace and newlines
    var trimmed: String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Capitalize first letter
    var capitalizedFirst: String {
        return prefix(1).capitalized + dropFirst()
    }
    
    // URL encoding
    var urlEncoded: String {
        return addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
    
    // Convert to currency format
    func toCurrency(locale: Locale = Locale.current) -> String {
        guard let double = Double(self) else { return self }
        return double.toCurrency(locale: locale)
    }
    
    // Truncate string to specified length
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count <= length {
            return self
        }
        return String(self.prefix(length)) + trailing
    }
}

// MARK: - Double Extensions
extension Double {
    // Convert to currency format
    func toCurrency(locale: Locale = Locale.current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: self)) ?? "$\(self)"
    }
    
    // Round to specified decimal places
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
    
    // Format as percentage
    func toPercentage(decimalPlaces: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces
        return formatter.string(from: NSNumber(value: self / 100)) ?? "\(self)%"
    }
}

// MARK: - Date Extensions
extension Date {
    // Time ago string
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    // Format as string
    func formatted(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        return formatter.string(from: self)
    }
    
    // Format as time string
    func formattedTime(style: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = style
        return formatter.string(from: self)
    }
    
    // Check if date is today
    var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    // Check if date is yesterday
    var isYesterday: Bool {
        return Calendar.current.isDateInYesterday(self)
    }
    
    // Start of day
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    // End of day
    var endOfDay: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return calendar.date(byAdding: components, to: startOfDay) ?? self
    }
}

// MARK: - View Extensions
extension View {
    // Conditional modifier
    @ViewBuilder func `if`<T>(_ condition: Bool, transform: (Self) -> T) -> some View where T: View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    // Card style modifier
    func cardStyle() -> some View {
        self
            .background(Color.cardBackground)
            .cornerRadius(AppConstants.UI.cornerRadius)
            .shadow(color: Color.black.opacity(0.1), radius: AppConstants.UI.shadowRadius, x: 0, y: 2)
    }
    
    // Primary button style
    func primaryButtonStyle() -> some View {
        self
            .font(.buttonText)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.primaryColor)
            .cornerRadius(AppConstants.UI.cornerRadius)
    }
    
    // Secondary button style
    func secondaryButtonStyle() -> some View {
        self
            .font(.buttonText)
            .foregroundColor(.primaryColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                    .stroke(Color.primaryColor, lineWidth: 1)
            )
    }
    
    // Loading overlay
    func loadingOverlay(isLoading: Bool) -> some View {
        self.overlay(
            Group {
                if isLoading {
                    Color.black.opacity(0.3)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                        )
                        .cornerRadius(AppConstants.UI.cornerRadius)
                }
            }
        )
    }
    
    // Shake animation
    func shake(animatableData: CGFloat) -> some View {
        self.modifier(ShakeEffect(animatableData: animatableData))
    }
    
    // Hide keyboard on tap
    func hideKeyboard() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

// MARK: - Color Extensions
extension Color {
    // Initialize with hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
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
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Array Extensions
extension Array {
    // Safe subscript
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
    
    // Remove duplicates
    func removingDuplicates<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}

// MARK: - UserDefaults Extensions
extension UserDefaults {
    // Save Codable object
    func setObject<Object>(_ object: Object, forKey: String) where Object: Encodable {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(object)
            set(data, forKey: forKey)
        } catch {
            print("Failed to encode object: \(error)")
        }
    }
    
    // Retrieve Codable object
    func getObject<Object>(_ type: Object.Type, forKey: String) -> Object? where Object: Decodable {
        guard let data = data(forKey: forKey) else { return nil }
        let decoder = JSONDecoder()
        do {
            let object = try decoder.decode(type, from: data)
            return object
        } catch {
            print("Failed to decode object: \(error)")
            return nil
        }
    }
}

// MARK: - Custom View Modifiers
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 10), y: 0))
    }
}

// MARK: - Environment Keys
struct SafeAreaInsetsKey: EnvironmentKey {
    static var defaultValue: EdgeInsets = EdgeInsets()
}

extension EnvironmentValues {
    var safeAreaInsets: EdgeInsets {
        get { self[SafeAreaInsetsKey.self] }
        set { self[SafeAreaInsetsKey.self] = newValue }
    }
}

// MARK: - Custom Property Wrappers
@propertyWrapper
struct Clamped<Value: Comparable> {
    var value: Value
    let range: ClosedRange<Value>
    
    init(wrappedValue: Value, _ range: ClosedRange<Value>) {
        self.range = range
        self.value = min(max(wrappedValue, range.lowerBound), range.upperBound)
    }
    
    var wrappedValue: Value {
        get { value }
        set { value = min(max(newValue, range.lowerBound), range.upperBound) }
    }
}

// MARK: - Validation Helpers
struct Validator {
    static func isValidEmail(_ email: String) -> Bool {
        return email.isValidEmail
    }
    
    static func isValidPassword(_ password: String) -> Bool {
        return password.count >= AppConstants.Validation.minPasswordLength
    }
    
    static func isValidName(_ name: String) -> Bool {
        return !name.trimmed.isEmpty && name.count <= AppConstants.Validation.maxNameLength
    }
    
    static func isValidPhoneNumber(_ phone: String) -> Bool {
        return phone.isValidPhoneNumber
    }
    
    static func isValidPrice(_ price: Double) -> Bool {
        return price >= AppConstants.Listings.minPrice && price <= AppConstants.Listings.maxPrice
    }
}