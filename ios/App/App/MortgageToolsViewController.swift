import UIKit

class MortgageToolsViewController: UIViewController {
    
    // MARK: - UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    // Calculator Selection
    private let calculatorSegment = UISegmentedControl(items: ["Mortgage", "Affordability", "Rent vs Buy"])
    
    // Input Fields
    private let loanAmountField = UITextField()
    private let interestRateField = UITextField()
    private let loanTermField = UITextField()
    private let downPaymentField = UITextField()
    private let homeValueField = UITextField()
    private let monthlyIncomeField = UITextField()
    private let monthlyDebtsField = UITextField()
    private let monthlyRentField = UITextField()
    
    // Results
    private let resultsContainerView = UIView()
    private let monthlyPaymentLabel = UILabel()
    private let totalInterestLabel = UILabel()
    private let totalPaymentLabel = UILabel()
    private let maxAffordableLabel = UILabel()
    private let recommendationLabel = UILabel()
    
    // Calculate Button
    private let calculateButton = UIButton(type: .system)
    
    // Current calculator type
    private var currentCalculator: CalculatorType = .mortgage
    
    enum CalculatorType {
        case mortgage
        case affordability
        case rentVsBuy
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCalculatorSegment()
        setupConstraints()
        configureForMortgageCalculator()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = Theme.backgroundColor
        title = "Mortgage Tools"
        
        // Configure scroll view
        scrollView.backgroundColor = Theme.backgroundColor
        scrollView.showsVerticalScrollIndicator = false
        
        // Configure content view
        contentView.backgroundColor = Theme.backgroundColor
        
        // Configure title
        titleLabel.text = "Mortgage Calculator"
        titleLabel.font = Theme.boldFont(size: 28)
        titleLabel.textColor = Theme.textColor
        titleLabel.textAlignment = .center
        
        // Configure subtitle
        subtitleLabel.text = "Calculate your monthly mortgage payment"
        subtitleLabel.font = Theme.regularFont(size: 16)
        subtitleLabel.textColor = Theme.secondaryTextColor
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        // Configure calculator segment
        calculatorSegment.backgroundColor = Theme.cardBackgroundColor
        calculatorSegment.selectedSegmentTintColor = Theme.primaryColor
        calculatorSegment.setTitleTextAttributes([.foregroundColor: Theme.textColor], for: .normal)
        calculatorSegment.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        calculatorSegment.layer.cornerRadius = 8
        calculatorSegment.selectedSegmentIndex = 0
        
        // Configure input fields
        configureInputField(loanAmountField, placeholder: "Loan Amount ($)")
        configureInputField(interestRateField, placeholder: "Interest Rate (%)")
        configureInputField(loanTermField, placeholder: "Loan Term (years)")
        configureInputField(downPaymentField, placeholder: "Down Payment ($)")
        configureInputField(homeValueField, placeholder: "Home Value ($)")
        configureInputField(monthlyIncomeField, placeholder: "Monthly Income ($)")
        configureInputField(monthlyDebtsField, placeholder: "Monthly Debts ($)")
        configureInputField(monthlyRentField, placeholder: "Monthly Rent ($)")
        
        // Configure results container
        resultsContainerView.backgroundColor = Theme.cardBackgroundColor
        resultsContainerView.layer.cornerRadius = 12
        resultsContainerView.layer.shadowColor = UIColor.black.cgColor
        resultsContainerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        resultsContainerView.layer.shadowOpacity = 0.1
        resultsContainerView.layer.shadowRadius = 4
        resultsContainerView.isHidden = true
        
        // Configure result labels
        configureResultLabel(monthlyPaymentLabel, title: "Monthly Payment")
        configureResultLabel(totalInterestLabel, title: "Total Interest")
        configureResultLabel(totalPaymentLabel, title: "Total Payment")
        configureResultLabel(maxAffordableLabel, title: "Max Affordable")
        configureResultLabel(recommendationLabel, title: "Recommendation")
        
        // Configure calculate button
        calculateButton.setTitle("Calculate", for: .normal)
        calculateButton.backgroundColor = Theme.primaryColor
        calculateButton.setTitleColor(.white, for: .normal)
        calculateButton.titleLabel?.font = Theme.boldFont(size: 18)
        calculateButton.layer.cornerRadius = 12
        calculateButton.addTarget(self, action: #selector(calculateTapped), for: .touchUpInside)
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(calculatorSegment)
        contentView.addSubview(loanAmountField)
        contentView.addSubview(interestRateField)
        contentView.addSubview(loanTermField)
        contentView.addSubview(downPaymentField)
        contentView.addSubview(homeValueField)
        contentView.addSubview(monthlyIncomeField)
        contentView.addSubview(monthlyDebtsField)
        contentView.addSubview(monthlyRentField)
        contentView.addSubview(calculateButton)
        contentView.addSubview(resultsContainerView)
        
        resultsContainerView.addSubview(monthlyPaymentLabel)
        resultsContainerView.addSubview(totalInterestLabel)
        resultsContainerView.addSubview(totalPaymentLabel)
        resultsContainerView.addSubview(maxAffordableLabel)
        resultsContainerView.addSubview(recommendationLabel)
    }
    
    private func configureInputField(_ field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.backgroundColor = Theme.cardBackgroundColor
        field.textColor = Theme.textColor
        field.font = Theme.regularFont(size: 16)
        field.layer.cornerRadius = 8
        field.layer.borderWidth = 1
        field.layer.borderColor = Theme.borderColor.cgColor
        field.keyboardType = .decimalPad
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        field.rightViewMode = .always
        
        // Add toolbar with done button
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
        toolbar.setItems([doneButton], animated: false)
        field.inputAccessoryView = toolbar
    }
    
    private func configureResultLabel(_ label: UILabel, title: String) {
        label.text = title + ": $0"
        label.font = Theme.regularFont(size: 16)
        label.textColor = Theme.textColor
        label.numberOfLines = 0
    }
    
    // MARK: - Calculator Segment Setup
    
    private func setupCalculatorSegment() {
        calculatorSegment.addTarget(self, action: #selector(calculatorChanged), for: .valueChanged)
    }
    
    @objc private func calculatorChanged() {
        let selectedIndex = calculatorSegment.selectedSegmentIndex
        
        switch selectedIndex {
        case 0:
            currentCalculator = .mortgage
            configureForMortgageCalculator()
        case 1:
            currentCalculator = .affordability
            configureForAffordabilityCalculator()
        case 2:
            currentCalculator = .rentVsBuy
            configureForRentVsBuyCalculator()
        default:
            break
        }
        
        resultsContainerView.isHidden = true
        clearResults()
    }
    
    private func configureForMortgageCalculator() {
        titleLabel.text = "Mortgage Calculator"
        subtitleLabel.text = "Calculate your monthly mortgage payment"
        
        // Show/hide fields
        loanAmountField.isHidden = false
        interestRateField.isHidden = false
        loanTermField.isHidden = false
        downPaymentField.isHidden = false
        homeValueField.isHidden = true
        monthlyIncomeField.isHidden = true
        monthlyDebtsField.isHidden = true
        monthlyRentField.isHidden = true
        
        // Show/hide result labels
        monthlyPaymentLabel.isHidden = false
        totalInterestLabel.isHidden = false
        totalPaymentLabel.isHidden = false
        maxAffordableLabel.isHidden = true
        recommendationLabel.isHidden = true
    }
    
    private func configureForAffordabilityCalculator() {
        titleLabel.text = "Affordability Calculator"
        subtitleLabel.text = "Calculate how much house you can afford"
        
        // Show/hide fields
        loanAmountField.isHidden = true
        interestRateField.isHidden = false
        loanTermField.isHidden = false
        downPaymentField.isHidden = false
        homeValueField.isHidden = true
        monthlyIncomeField.isHidden = false
        monthlyDebtsField.isHidden = false
        monthlyRentField.isHidden = true
        
        // Show/hide result labels
        monthlyPaymentLabel.isHidden = false
        totalInterestLabel.isHidden = true
        totalPaymentLabel.isHidden = true
        maxAffordableLabel.isHidden = false
        recommendationLabel.isHidden = true
    }
    
    private func configureForRentVsBuyCalculator() {
        titleLabel.text = "Rent vs Buy Calculator"
        subtitleLabel.text = "Compare renting vs buying costs"
        
        // Show/hide fields
        loanAmountField.isHidden = true
        interestRateField.isHidden = false
        loanTermField.isHidden = false
        downPaymentField.isHidden = false
        homeValueField.isHidden = false
        monthlyIncomeField.isHidden = true
        monthlyDebtsField.isHidden = true
        monthlyRentField.isHidden = false
        
        // Show/hide result labels
        monthlyPaymentLabel.isHidden = false
        totalInterestLabel.isHidden = true
        totalPaymentLabel.isHidden = true
        maxAffordableLabel.isHidden = true
        recommendationLabel.isHidden = false
    }
    
    // MARK: - Constraints
    
    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        calculatorSegment.translatesAutoresizingMaskIntoConstraints = false
        loanAmountField.translatesAutoresizingMaskIntoConstraints = false
        interestRateField.translatesAutoresizingMaskIntoConstraints = false
        loanTermField.translatesAutoresizingMaskIntoConstraints = false
        downPaymentField.translatesAutoresizingMaskIntoConstraints = false
        homeValueField.translatesAutoresizingMaskIntoConstraints = false
        monthlyIncomeField.translatesAutoresizingMaskIntoConstraints = false
        monthlyDebtsField.translatesAutoresizingMaskIntoConstraints = false
        monthlyRentField.translatesAutoresizingMaskIntoConstraints = false
        calculateButton.translatesAutoresizingMaskIntoConstraints = false
        resultsContainerView.translatesAutoresizingMaskIntoConstraints = false
        monthlyPaymentLabel.translatesAutoresizingMaskIntoConstraints = false
        totalInterestLabel.translatesAutoresizingMaskIntoConstraints = false
        totalPaymentLabel.translatesAutoresizingMaskIntoConstraints = false
        maxAffordableLabel.translatesAutoresizingMaskIntoConstraints = false
        recommendationLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Calculator segment
            calculatorSegment.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            calculatorSegment.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            calculatorSegment.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            calculatorSegment.heightAnchor.constraint(equalToConstant: 40),
            
            // Input fields
            loanAmountField.topAnchor.constraint(equalTo: calculatorSegment.bottomAnchor, constant: 30),
            loanAmountField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            loanAmountField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            loanAmountField.heightAnchor.constraint(equalToConstant: 50),
            
            interestRateField.topAnchor.constraint(equalTo: loanAmountField.bottomAnchor, constant: 15),
            interestRateField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            interestRateField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            interestRateField.heightAnchor.constraint(equalToConstant: 50),
            
            loanTermField.topAnchor.constraint(equalTo: interestRateField.bottomAnchor, constant: 15),
            loanTermField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            loanTermField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            loanTermField.heightAnchor.constraint(equalToConstant: 50),
            
            downPaymentField.topAnchor.constraint(equalTo: loanTermField.bottomAnchor, constant: 15),
            downPaymentField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            downPaymentField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            downPaymentField.heightAnchor.constraint(equalToConstant: 50),
            
            homeValueField.topAnchor.constraint(equalTo: downPaymentField.bottomAnchor, constant: 15),
            homeValueField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            homeValueField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            homeValueField.heightAnchor.constraint(equalToConstant: 50),
            
            monthlyIncomeField.topAnchor.constraint(equalTo: homeValueField.bottomAnchor, constant: 15),
            monthlyIncomeField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            monthlyIncomeField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            monthlyIncomeField.heightAnchor.constraint(equalToConstant: 50),
            
            monthlyDebtsField.topAnchor.constraint(equalTo: monthlyIncomeField.bottomAnchor, constant: 15),
            monthlyDebtsField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            monthlyDebtsField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            monthlyDebtsField.heightAnchor.constraint(equalToConstant: 50),
            
            monthlyRentField.topAnchor.constraint(equalTo: monthlyDebtsField.bottomAnchor, constant: 15),
            monthlyRentField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            monthlyRentField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            monthlyRentField.heightAnchor.constraint(equalToConstant: 50),
            
            // Calculate button
            calculateButton.topAnchor.constraint(equalTo: monthlyRentField.bottomAnchor, constant: 30),
            calculateButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            calculateButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            calculateButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Results container
            resultsContainerView.topAnchor.constraint(equalTo: calculateButton.bottomAnchor, constant: 20),
            resultsContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            resultsContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            resultsContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            // Result labels
            monthlyPaymentLabel.topAnchor.constraint(equalTo: resultsContainerView.topAnchor, constant: 20),
            monthlyPaymentLabel.leadingAnchor.constraint(equalTo: resultsContainerView.leadingAnchor, constant: 20),
            monthlyPaymentLabel.trailingAnchor.constraint(equalTo: resultsContainerView.trailingAnchor, constant: -20),
            
            totalInterestLabel.topAnchor.constraint(equalTo: monthlyPaymentLabel.bottomAnchor, constant: 10),
            totalInterestLabel.leadingAnchor.constraint(equalTo: resultsContainerView.leadingAnchor, constant: 20),
            totalInterestLabel.trailingAnchor.constraint(equalTo: resultsContainerView.trailingAnchor, constant: -20),
            
            totalPaymentLabel.topAnchor.constraint(equalTo: totalInterestLabel.bottomAnchor, constant: 10),
            totalPaymentLabel.leadingAnchor.constraint(equalTo: resultsContainerView.leadingAnchor, constant: 20),
            totalPaymentLabel.trailingAnchor.constraint(equalTo: resultsContainerView.trailingAnchor, constant: -20),
            
            maxAffordableLabel.topAnchor.constraint(equalTo: totalPaymentLabel.bottomAnchor, constant: 10),
            maxAffordableLabel.leadingAnchor.constraint(equalTo: resultsContainerView.leadingAnchor, constant: 20),
            maxAffordableLabel.trailingAnchor.constraint(equalTo: resultsContainerView.trailingAnchor, constant: -20),
            
            recommendationLabel.topAnchor.constraint(equalTo: maxAffordableLabel.bottomAnchor, constant: 10),
            recommendationLabel.leadingAnchor.constraint(equalTo: resultsContainerView.leadingAnchor, constant: 20),
            recommendationLabel.trailingAnchor.constraint(equalTo: resultsContainerView.trailingAnchor, constant: -20),
            recommendationLabel.bottomAnchor.constraint(equalTo: resultsContainerView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func calculateTapped() {
        dismissKeyboard()
        
        switch currentCalculator {
        case .mortgage:
            calculateMortgage()
        case .affordability:
            calculateAffordability()
        case .rentVsBuy:
            calculateRentVsBuy()
        }
    }
    
    // MARK: - Calculator Logic
    
    private func calculateMortgage() {
        guard let loanAmount = Double(loanAmountField.text ?? ""),
              let interestRate = Double(interestRateField.text ?? ""),
              let loanTerm = Double(loanTermField.text ?? ""),
              loanAmount > 0, interestRate > 0, loanTerm > 0 else {
            showAlert(title: "Invalid Input", message: "Please enter valid values for all fields.")
            return
        }
        
        let monthlyRate = interestRate / 100 / 12
        let numberOfPayments = loanTerm * 12
        
        let monthlyPayment = loanAmount * (monthlyRate * pow(1 + monthlyRate, numberOfPayments)) / (pow(1 + monthlyRate, numberOfPayments) - 1)
        let totalPayment = monthlyPayment * numberOfPayments
        let totalInterest = totalPayment - loanAmount
        
        monthlyPaymentLabel.text = "Monthly Payment: $\(String(format: "%.2f", monthlyPayment))"
        totalInterestLabel.text = "Total Interest: $\(String(format: "%.2f", totalInterest))"
        totalPaymentLabel.text = "Total Payment: $\(String(format: "%.2f", totalPayment))"
        
        resultsContainerView.isHidden = false
        
        // Animate results appearance
        resultsContainerView.alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.resultsContainerView.alpha = 1
        }
    }
    
    private func calculateAffordability() {
        guard let monthlyIncome = Double(monthlyIncomeField.text ?? ""),
              let monthlyDebts = Double(monthlyDebtsField.text ?? ""),
              let interestRate = Double(interestRateField.text ?? ""),
              let loanTerm = Double(loanTermField.text ?? ""),
              let downPayment = Double(downPaymentField.text ?? ""),
              monthlyIncome > 0, interestRate > 0, loanTerm > 0 else {
            showAlert(title: "Invalid Input", message: "Please enter valid values for all fields.")
            return
        }
        
        // Use 28% DTI rule
        let maxMonthlyPayment = monthlyIncome * 0.28 - monthlyDebts
        
        if maxMonthlyPayment <= 0 {
            showAlert(title: "Cannot Afford", message: "Based on your income and debts, you may not qualify for a mortgage.")
            return
        }
        
        let monthlyRate = interestRate / 100 / 12
        let numberOfPayments = loanTerm * 12
        
        let maxLoanAmount = maxMonthlyPayment * (pow(1 + monthlyRate, numberOfPayments) - 1) / (monthlyRate * pow(1 + monthlyRate, numberOfPayments))
        let maxHomeValue = maxLoanAmount + downPayment
        
        monthlyPaymentLabel.text = "Max Monthly Payment: $\(String(format: "%.2f", maxMonthlyPayment))"
        maxAffordableLabel.text = "Max Affordable Home: $\(String(format: "%.2f", maxHomeValue))"
        
        resultsContainerView.isHidden = false
        
        // Animate results appearance
        resultsContainerView.alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.resultsContainerView.alpha = 1
        }
    }
    
    private func calculateRentVsBuy() {
        guard let homeValue = Double(homeValueField.text ?? ""),
              let downPayment = Double(downPaymentField.text ?? ""),
              let interestRate = Double(interestRateField.text ?? ""),
              let loanTerm = Double(loanTermField.text ?? ""),
              let monthlyRent = Double(monthlyRentField.text ?? ""),
              homeValue > 0, interestRate > 0, loanTerm > 0, monthlyRent > 0 else {
            showAlert(title: "Invalid Input", message: "Please enter valid values for all fields.")
            return
        }
        
        let loanAmount = homeValue - downPayment
        let monthlyRate = interestRate / 100 / 12
        let numberOfPayments = loanTerm * 12
        
        let monthlyMortgage = loanAmount * (monthlyRate * pow(1 + monthlyRate, numberOfPayments)) / (pow(1 + monthlyRate, numberOfPayments) - 1)
        
        // Add property taxes, insurance, maintenance (estimated 1.5% of home value annually)
        let monthlyOwnershipCosts = monthlyMortgage + (homeValue * 0.015 / 12)
        
        monthlyPaymentLabel.text = "Monthly Ownership Cost: $\(String(format: "%.2f", monthlyOwnershipCosts))"
        
        let recommendation: String
        let savingsText: String
        
        if monthlyOwnershipCosts < monthlyRent {
            let savings = monthlyRent - monthlyOwnershipCosts
            recommendation = "Buying is more cost-effective"
            savingsText = "Potential monthly savings: $\(String(format: "%.2f", savings))"
        } else {
            let extraCost = monthlyOwnershipCosts - monthlyRent
            recommendation = "Renting is more cost-effective"
            savingsText = "Monthly savings with renting: $\(String(format: "%.2f", extraCost))"
        }
        
        recommendationLabel.text = "\(recommendation)\n\(savingsText)"
        
        resultsContainerView.isHidden = false
        
        // Animate results appearance
        resultsContainerView.alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.resultsContainerView.alpha = 1
        }
    }
    
    private func clearResults() {
        monthlyPaymentLabel.text = "Monthly Payment: $0"
        totalInterestLabel.text = "Total Interest: $0"
        totalPaymentLabel.text = "Total Payment: $0"
        maxAffordableLabel.text = "Max Affordable: $0"
        recommendationLabel.text = "Recommendation: -"
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}