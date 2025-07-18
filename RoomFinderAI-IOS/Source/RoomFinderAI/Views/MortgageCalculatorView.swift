import SwiftUI
// ResultRow is now in SharedComponents

struct MortgageCalculatorView: View {
    @StateObject private var mortgageService = MortgageCalculatorService.shared
    @State private var homePrice = ""
    @State private var downPayment = ""
    @State private var interestRate = ""
    @State private var loanTerm = 30
    @State private var propertyTax = ""
    @State private var homeInsurance = ""
    @State private var pmi = ""
    @State private var hoaFees = ""
    
    @State private var mortgageResult: MortgageResult?
    @State private var selectedCalculatorType: CalculatorType = .mortgage
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Calculator Type Selector
                    Picker("Calculator Type", selection: $selectedCalculatorType) {
                        ForEach(CalculatorType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    switch selectedCalculatorType {
                    case .mortgage:
                        MortgageCalculatorContent(
                            homePrice: $homePrice,
                            downPayment: $downPayment,
                            interestRate: $interestRate,
                            loanTerm: $loanTerm,
                            propertyTax: $propertyTax,
                            homeInsurance: $homeInsurance,
                            pmi: $pmi,
                            hoaFees: $hoaFees,
                            mortgageResult: $mortgageResult,
                            mortgageService: mortgageService
                        )
                        
                    case .affordability:
                        AffordabilityCalculatorContent(mortgageService: mortgageService)
                        
                    case .refinance:
                        RefinanceCalculatorContent(mortgageService: mortgageService)
                        
                    case .rentVsBuy:
                        RentVsBuyCalculatorContent(mortgageService: mortgageService)
                    }
                }
                .padding()
            }
            .navigationTitle("Mortgage Calculator")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MortgageCalculatorContent: View {
    @Binding var homePrice: String
    @Binding var downPayment: String
    @Binding var interestRate: String
    @Binding var loanTerm: Int
    @Binding var propertyTax: String
    @Binding var homeInsurance: String
    @Binding var pmi: String
    @Binding var hoaFees: String
    @Binding var mortgageResult: MortgageResult?
    
    let mortgageService: MortgageCalculatorService
    
    var body: some View {
        VStack(spacing: 24) {
            // Input Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Loan Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(spacing: 12) {
                    InputField(title: "Home Price", value: $homePrice, placeholder: "500,000")
                    InputField(title: "Down Payment", value: $downPayment, placeholder: "100,000")
                    InputField(title: "Interest Rate (%)", value: $interestRate, placeholder: "6.5")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Loan Term (years)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Picker("Loan Term", selection: $loanTerm) {
                            ForEach([15, 20, 25, 30], id: \.self) { term in
                                Text("\(term) years").tag(term)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Additional Costs
            VStack(alignment: .leading, spacing: 16) {
                Text("Additional Costs (Annual)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(spacing: 12) {
                    InputField(title: "Property Tax", value: $propertyTax, placeholder: "6,000")
                    InputField(title: "Home Insurance", value: $homeInsurance, placeholder: "1,200")
                    InputField(title: "PMI", value: $pmi, placeholder: "2,400")
                    InputField(title: "HOA Fees", value: $hoaFees, placeholder: "1,800")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Calculate Button
            Button(action: calculateMortgage) {
                Text("Calculate")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primaryBlue)
                    .cornerRadius(12)
            }
            .disabled(!canCalculate)
            
            // Results
            if let result = mortgageResult {
                MortgageResultView(result: result)
            }
        }
    }
    
    private var canCalculate: Bool {
        return !homePrice.isEmpty && !downPayment.isEmpty && !interestRate.isEmpty
    }
    
    private func calculateMortgage() {
        guard let homePriceValue = Double(homePrice.replacingOccurrences(of: ",", with: "")),
              let downPaymentValue = Double(downPayment.replacingOccurrences(of: ",", with: "")),
              let interestRateValue = Double(interestRate) else {
            return
        }
        
        let propertyTaxValue = Double(propertyTax.replacingOccurrences(of: ",", with: "")) ?? 0
        let homeInsuranceValue = Double(homeInsurance.replacingOccurrences(of: ",", with: "")) ?? 0
        let pmiValue = Double(pmi.replacingOccurrences(of: ",", with: "")) ?? 0
        let hoaFeesValue = Double(hoaFees.replacingOccurrences(of: ",", with: "")) ?? 0
        
        mortgageResult = mortgageService.calculateMortgage(
            homePrice: homePriceValue,
            downPayment: downPaymentValue,
            interestRate: interestRateValue,
            loanTerm: loanTerm,
            propertyTax: propertyTaxValue,
            homeInsurance: homeInsuranceValue,
            pmi: pmiValue,
            hoaFees: hoaFeesValue
        )
    }
}

struct AffordabilityCalculatorContent: View {
    let mortgageService: MortgageCalculatorService
    
    @State private var monthlyIncome = ""
    @State private var monthlyDebts = ""
    @State private var downPayment = ""
    @State private var interestRate = ""
    @State private var loanTerm = 30
    @State private var affordabilityResult: AffordabilityResult?
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Income & Debt Information")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(spacing: 12) {
                    InputField(title: "Monthly Income", value: $monthlyIncome, placeholder: "8,000")
                    InputField(title: "Monthly Debts", value: $monthlyDebts, placeholder: "500")
                    InputField(title: "Down Payment", value: $downPayment, placeholder: "50,000")
                    InputField(title: "Interest Rate (%)", value: $interestRate, placeholder: "6.5")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Loan Term (years)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Picker("Loan Term", selection: $loanTerm) {
                            ForEach([15, 20, 25, 30], id: \.self) { term in
                                Text("\(term) years").tag(term)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            Button(action: calculateAffordability) {
                Text("Calculate Affordability")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primaryBlue)
                    .cornerRadius(12)
            }
            .disabled(!canCalculateAffordability)
            
            if let result = affordabilityResult {
                AffordabilityResultView(result: result)
            }
        }
    }
    
    private var canCalculateAffordability: Bool {
        return !monthlyIncome.isEmpty && !monthlyDebts.isEmpty && !downPayment.isEmpty && !interestRate.isEmpty
    }
    
    private func calculateAffordability() {
        guard let monthlyIncomeValue = Double(monthlyIncome.replacingOccurrences(of: ",", with: "")),
              let monthlyDebtsValue = Double(monthlyDebts.replacingOccurrences(of: ",", with: "")),
              let downPaymentValue = Double(downPayment.replacingOccurrences(of: ",", with: "")),
              let interestRateValue = Double(interestRate) else {
            return
        }
        
        affordabilityResult = mortgageService.calculateAffordability(
            monthlyIncome: monthlyIncomeValue,
            monthlyDebts: monthlyDebtsValue,
            downPayment: downPaymentValue,
            interestRate: interestRateValue,
            loanTerm: loanTerm
        )
    }
}

struct RefinanceCalculatorContent: View {
    let mortgageService: MortgageCalculatorService
    
    @State private var currentLoanBalance = ""
    @State private var currentInterestRate = ""
    @State private var currentRemainingTerm = ""
    @State private var newInterestRate = ""
    @State private var newLoanTerm = ""
    @State private var closingCosts = ""
    @State private var refinanceResult: RefinancingResult?
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Current Loan Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(spacing: 12) {
                    InputField(title: "Current Loan Balance", value: $currentLoanBalance, placeholder: "300,000")
                    InputField(title: "Current Interest Rate (%)", value: $currentInterestRate, placeholder: "7.5")
                    InputField(title: "Remaining Term (years)", value: $currentRemainingTerm, placeholder: "25")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("New Loan Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(spacing: 12) {
                    InputField(title: "New Interest Rate (%)", value: $newInterestRate, placeholder: "6.0")
                    InputField(title: "New Loan Term (years)", value: $newLoanTerm, placeholder: "30")
                    InputField(title: "Closing Costs", value: $closingCosts, placeholder: "5,000")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            Button(action: calculateRefinance) {
                Text("Calculate Refinance")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primaryBlue)
                    .cornerRadius(12)
            }
            .disabled(!canCalculateRefinance)
            
            if let result = refinanceResult {
                RefinanceResultView(result: result)
            }
        }
    }
    
    private var canCalculateRefinance: Bool {
        return !currentLoanBalance.isEmpty && !currentInterestRate.isEmpty && !currentRemainingTerm.isEmpty && !newInterestRate.isEmpty && !newLoanTerm.isEmpty
    }
    
    private func calculateRefinance() {
        guard let currentLoanBalanceValue = Double(currentLoanBalance.replacingOccurrences(of: ",", with: "")),
              let currentInterestRateValue = Double(currentInterestRate),
              let currentRemainingTermValue = Int(currentRemainingTerm),
              let newInterestRateValue = Double(newInterestRate),
              let newLoanTermValue = Int(newLoanTerm) else {
            return
        }
        
        let closingCostsValue = Double(closingCosts.replacingOccurrences(of: ",", with: "")) ?? 0
        
        refinanceResult = mortgageService.calculateRefinancing(
            currentLoanBalance: currentLoanBalanceValue,
            currentInterestRate: currentInterestRateValue,
            currentRemainingTerm: currentRemainingTermValue,
            newInterestRate: newInterestRateValue,
            newLoanTerm: newLoanTermValue,
            closingCosts: closingCostsValue
        )
    }
}

struct RentVsBuyCalculatorContent: View {
    let mortgageService: MortgageCalculatorService
    
    @State private var homePrice = ""
    @State private var downPayment = ""
    @State private var interestRate = ""
    @State private var loanTerm = 30
    @State private var monthlyRent = ""
    @State private var propertyTax = ""
    @State private var homeInsurance = ""
    @State private var maintenance = ""
    @State private var hoa = ""
    @State private var timeHorizon = 10
    @State private var rentVsBuyResult: RentVsBuyResult?
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Home Purchase Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(spacing: 12) {
                    InputField(title: "Home Price", value: $homePrice, placeholder: "500,000")
                    InputField(title: "Down Payment", value: $downPayment, placeholder: "100,000")
                    InputField(title: "Interest Rate (%)", value: $interestRate, placeholder: "6.5")
                    InputField(title: "Monthly Rent", value: $monthlyRent, placeholder: "2,500")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Annual Costs")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(spacing: 12) {
                    InputField(title: "Property Tax", value: $propertyTax, placeholder: "6,000")
                    InputField(title: "Home Insurance", value: $homeInsurance, placeholder: "1,200")
                    InputField(title: "Maintenance", value: $maintenance, placeholder: "3,000")
                    InputField(title: "HOA Fees", value: $hoa, placeholder: "1,800")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Time Horizon (years)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Time Horizon", selection: $timeHorizon) {
                    ForEach([5, 10, 15, 20], id: \.self) { years in
                        Text("\(years) years").tag(years)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Button(action: calculateRentVsBuy) {
                Text("Calculate Rent vs Buy")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primaryBlue)
                    .cornerRadius(12)
            }
            .disabled(!canCalculateRentVsBuy)
            
            if let result = rentVsBuyResult {
                RentVsBuyResultView(result: result)
            }
        }
    }
    
    private var canCalculateRentVsBuy: Bool {
        return !homePrice.isEmpty && !downPayment.isEmpty && !interestRate.isEmpty && !monthlyRent.isEmpty
    }
    
    private func calculateRentVsBuy() {
        guard let homePriceValue = Double(homePrice.replacingOccurrences(of: ",", with: "")),
              let downPaymentValue = Double(downPayment.replacingOccurrences(of: ",", with: "")),
              let interestRateValue = Double(interestRate),
              let monthlyRentValue = Double(monthlyRent.replacingOccurrences(of: ",", with: "")) else {
            return
        }
        
        let propertyTaxValue = Double(propertyTax.replacingOccurrences(of: ",", with: "")) ?? 0
        let homeInsuranceValue = Double(homeInsurance.replacingOccurrences(of: ",", with: "")) ?? 0
        let maintenanceValue = Double(maintenance.replacingOccurrences(of: ",", with: "")) ?? 0
        let hoaValue = Double(hoa.replacingOccurrences(of: ",", with: "")) ?? 0
        
        rentVsBuyResult = mortgageService.calculateRentVsBuy(
            homePrice: homePriceValue,
            downPayment: downPaymentValue,
            interestRate: interestRateValue,
            loanTerm: loanTerm,
            monthlyRent: monthlyRentValue,
            propertyTax: propertyTaxValue,
            homeInsurance: homeInsuranceValue,
            maintenance: maintenanceValue,
            hoa: hoaValue,
            timeHorizon: timeHorizon
        )
    }
}

// MARK: - Result Views

struct MortgageResultView: View {
    let result: MortgageResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mortgage Results")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                ResultRow(
                    title: "Monthly Payment",
                    value: result.monthlyPayment.currencyFormatted(),
                    isHighlighted: true
                )
                
                ResultRow(
                    title: "Total Monthly Payment",
                    value: result.totalMonthlyPayment.currencyFormatted(),
                    isHighlighted: true
                )
                
                ResultRow(
                    title: "Total Interest",
                    value: result.totalInterest.currencyFormatted()
                )
                
                ResultRow(
                    title: "Total Cost",
                    value: result.totalCost.currencyFormatted()
                )
                
                ResultRow(
                    title: "Loan-to-Value Ratio",
                    value: "\(result.loanToValueRatio, specifier: "%.1f")%"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AffordabilityResultView: View {
    let result: AffordabilityResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Affordability Results")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                ResultRow(
                    title: "Maximum Home Price",
                    value: result.maxHomePrice.currencyFormatted(),
                    isHighlighted: true
                )
                
                ResultRow(
                    title: "Maximum Monthly Payment",
                    value: result.maxMonthlyPayment.currencyFormatted(),
                    isHighlighted: true
                )
                
                ResultRow(
                    title: "Maximum Loan Amount",
                    value: result.maxLoanAmount.currencyFormatted()
                )
                
                ResultRow(
                    title: "Debt-to-Income Ratio",
                    value: "\(result.debtToIncomeRatio, specifier: "%.1f")%"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RefinanceResultView: View {
    let result: RefinancingResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Refinancing Results")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                ResultRow(
                    title: "Current Monthly Payment",
                    value: result.currentMonthlyPayment.currencyFormatted()
                )
                
                ResultRow(
                    title: "New Monthly Payment",
                    value: result.newMonthlyPayment.currencyFormatted(),
                    isHighlighted: true
                )
                
                ResultRow(
                    title: "Monthly Savings",
                    value: result.monthlySavings.currencyFormatted(),
                    isHighlighted: true
                )
                
                ResultRow(
                    title: "Total Savings",
                    value: result.totalSavings.currencyFormatted()
                )
                
                ResultRow(
                    title: "Break-Even Point",
                    value: "\(result.breakEvenMonths, specifier: "%.1f") months"
                )
                
                HStack {
                    Text("Recommendation:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(result.isWorthRefinancing ? "Refinance" : "Keep Current Loan")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(result.isWorthRefinancing ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RentVsBuyResultView: View {
    let result: RentVsBuyResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rent vs Buy Results")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                ResultRow(
                    title: "Total Rent Cost",
                    value: result.totalRentCost.currencyFormatted()
                )
                
                ResultRow(
                    title: "Total Buying Cost",
                    value: result.totalBuyingCost.currencyFormatted()
                )
                
                ResultRow(
                    title: "Net Buying Cost",
                    value: result.netBuyingCost.currencyFormatted()
                )
                
                ResultRow(
                    title: "Equity Built",
                    value: result.equityBuilt.currencyFormatted(),
                    isHighlighted: true
                )
                
                ResultRow(
                    title: "Savings",
                    value: result.savings.currencyFormatted()
                )
                
                HStack {
                    Text("Recommendation:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(result.recommendation)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(result.recommendation == "Buy" ? .green : .blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Helper Views

struct InputField: View {
    let title: String
    @Binding var value: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField(placeholder, text: $value)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.decimalPad)
        }
    }
}

// ResultRow moved to SharedComponents

enum CalculatorType: String, CaseIterable {
    case mortgage = "mortgage"
    case affordability = "affordability"
    case refinance = "refinance"
    case rentVsBuy = "rentVsBuy"
    
    var displayName: String {
        switch self {
        case .mortgage: return "Mortgage"
        case .affordability: return "Affordability"
        case .refinance: return "Refinance"
        case .rentVsBuy: return "Rent vs Buy"
        }
    }
}

#Preview {
    MortgageCalculatorView()
}