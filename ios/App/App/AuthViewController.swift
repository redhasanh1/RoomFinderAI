import UIKit

class AuthViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let segmentedControl = UISegmentedControl(items: ["Login", "Sign Up"])
    private let formStackView = UIStackView()
    
    // Form fields
    private let emailTextField = UITextField()
    private let passwordTextField = UITextField()
    private let firstNameTextField = UITextField()
    private let lastNameTextField = UITextField()
    private let confirmPasswordTextField = UITextField()
    
    private let actionButton = UIButton(type: .system)
    private let forgotPasswordButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    
    private var isLoginMode = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupKeyboardHandling()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Configure logo
        logoImageView.image = UIImage(systemName: "building.2.crop.circle.fill")
        logoImageView.tintColor = Theme.Colors.primary
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(logoImageView)
        
        // Configure title
        titleLabel.text = "RoomFinder AI"
        titleLabel.font = Theme.Fonts.title1
        titleLabel.textColor = Theme.Colors.primary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Configure subtitle
        subtitleLabel.text = "Find your perfect home"
        subtitleLabel.font = Theme.Fonts.body
        subtitleLabel.textColor = Theme.Colors.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)
        
        // Configure segmented control
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(segmentedControl)
        
        // Configure form stack view
        formStackView.axis = .vertical
        formStackView.spacing = Theme.Spacing.md
        formStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(formStackView)
        
        // Configure text fields
        setupTextField(emailTextField, placeholder: "Email", keyboardType: .emailAddress)
        setupTextField(passwordTextField, placeholder: "Password", isSecure: true)
        setupTextField(firstNameTextField, placeholder: "First Name")
        setupTextField(lastNameTextField, placeholder: "Last Name")
        setupTextField(confirmPasswordTextField, placeholder: "Confirm Password", isSecure: true)
        
        // Configure action button
        actionButton.setTitle("Login", for: .normal)
        actionButton.applyPrimaryStyle()
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure forgot password button
        forgotPasswordButton.setTitle("Forgot Password?", for: .normal)
        forgotPasswordButton.setTitleColor(Theme.Colors.primary, for: .normal)
        forgotPasswordButton.titleLabel?.font = Theme.Fonts.callout
        forgotPasswordButton.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
        forgotPasswordButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure loading indicator
        loadingIndicator.color = Theme.Colors.primary
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        // Add form elements to stack view
        formStackView.addArrangedSubview(emailTextField)
        formStackView.addArrangedSubview(passwordTextField)
        formStackView.addArrangedSubview(actionButton)
        formStackView.addArrangedSubview(forgotPasswordButton)
        formStackView.addArrangedSubview(loadingIndicator)
        
        updateFormForMode()
    }
    
    private func setupTextField(_ textField: UITextField, placeholder: String, keyboardType: UIKeyboardType = .default, isSecure: Bool = false) {
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.isSecureTextEntry = isSecure
        textField.borderStyle = .roundedRect
        textField.font = Theme.Fonts.body
        textField.backgroundColor = Theme.Colors.surface
        textField.layer.cornerRadius = Theme.CornerRadius.medium
        textField.layer.borderWidth = 1
        textField.layer.borderColor = Theme.Colors.primary.withAlphaComponent(0.3).cgColor
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            textField.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Theme.Spacing.xl),
            logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 80),
            logoImageView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: Theme.Spacing.md),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.sm),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            segmentedControl.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: Theme.Spacing.xl),
            segmentedControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            segmentedControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            formStackView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: Theme.Spacing.xl),
            formStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            formStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            formStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Spacing.xl)
        ])
    }
    
    private func setupKeyboardHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func segmentChanged() {
        isLoginMode = segmentedControl.selectedSegmentIndex == 0
        updateFormForMode()
    }
    
    private func updateFormForMode() {
        // Remove name fields if they exist
        if formStackView.arrangedSubviews.contains(firstNameTextField) {
            formStackView.removeArrangedSubview(firstNameTextField)
            firstNameTextField.removeFromSuperview()
        }
        
        if formStackView.arrangedSubviews.contains(lastNameTextField) {
            formStackView.removeArrangedSubview(lastNameTextField)
            lastNameTextField.removeFromSuperview()
        }
        
        if formStackView.arrangedSubviews.contains(confirmPasswordTextField) {
            formStackView.removeArrangedSubview(confirmPasswordTextField)
            confirmPasswordTextField.removeFromSuperview()
        }
        
        if !isLoginMode {
            // Add name fields for registration
            formStackView.insertArrangedSubview(firstNameTextField, at: 0)
            formStackView.insertArrangedSubview(lastNameTextField, at: 1)
            formStackView.insertArrangedSubview(confirmPasswordTextField, at: 4)
        }
        
        actionButton.setTitle(isLoginMode ? "Login" : "Sign Up", for: .normal)
        forgotPasswordButton.isHidden = !isLoginMode
    }
    
    @objc private func actionButtonTapped() {
        if isLoginMode {
            performLogin()
        } else {
            performRegistration()
        }
    }
    
    private func performLogin() {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(title: "Error", message: "Please fill in all fields")
            return
        }
        
        showLoading(true)
        
        APIService.shared.login(email: email, password: password) { [weak self] result in
            self?.showLoading(false)
            
            switch result {
            case .success(let authResponse):
                if authResponse.success, let token = authResponse.token {
                    APIService.shared.setAuthToken(token)
                    self?.dismiss(animated: true)
                } else {
                    self?.showAlert(title: "Login Failed", message: authResponse.message ?? "Invalid credentials")
                }
            case .failure(let error):
                self?.showAlert(title: "Error", message: error.localizedDescription)
            }
        }
    }
    
    private func performRegistration() {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty,
              let firstName = firstNameTextField.text, !firstName.isEmpty,
              let lastName = lastNameTextField.text, !lastName.isEmpty,
              let confirmPassword = confirmPasswordTextField.text, !confirmPassword.isEmpty else {
            showAlert(title: "Error", message: "Please fill in all fields")
            return
        }
        
        guard password == confirmPassword else {
            showAlert(title: "Error", message: "Passwords do not match")
            return
        }
        
        showLoading(true)
        
        APIService.shared.register(email: email, password: password, firstName: firstName, lastName: lastName) { [weak self] result in
            self?.showLoading(false)
            
            switch result {
            case .success(let authResponse):
                if authResponse.success, let token = authResponse.token {
                    APIService.shared.setAuthToken(token)
                    self?.dismiss(animated: true)
                } else {
                    self?.showAlert(title: "Registration Failed", message: authResponse.message ?? "Registration failed")
                }
            case .failure(let error):
                self?.showAlert(title: "Error", message: error.localizedDescription)
            }
        }
    }
    
    @objc private func forgotPasswordTapped() {
        // Implement forgot password functionality
        showAlert(title: "Forgot Password", message: "This feature will be implemented soon")
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardHeight = keyboardFrame.cgRectValue.height
            scrollView.contentInset.bottom = keyboardHeight
            scrollView.scrollIndicatorInsets.bottom = keyboardHeight
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset.bottom = 0
        scrollView.scrollIndicatorInsets.bottom = 0
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func showLoading(_ show: Bool) {
        actionButton.isEnabled = !show
        if show {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Authentication Manager
class AuthManager {
    static let shared = AuthManager()
    
    private init() {}
    
    var isLoggedIn: Bool {
        return APIService.shared.getAuthToken() != nil
    }
    
    func checkAuthenticationState() {
        // Check if user is logged in when app starts
        if !isLoggedIn {
            // Show auth screen
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let authVC = AuthViewController()
                let navController = UINavigationController(rootViewController: authVC)
                navController.modalPresentationStyle = .fullScreen
                window.rootViewController?.present(navController, animated: false)
            }
        }
    }
    
    func logout() {
        APIService.shared.clearAuthToken()
        // Don't automatically show auth screen - let user stay on current screen
    }
}