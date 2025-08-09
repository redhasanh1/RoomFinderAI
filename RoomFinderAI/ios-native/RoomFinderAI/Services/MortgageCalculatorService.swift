import Foundation

class MortgageCalculatorService: ObservableObject {
    static let shared = MortgageCalculatorService()
    
    private init() {}
    
    // MARK: - Mortgage Calculations
    
    func calculateMortgage(
        homePrice: Double,
        downPayment: Double,
        interestRate: Double,
        loanTerm: Int,
        propertyTax: Double = 0,
        homeInsurance: Double = 0,
        pmi: Double = 0,
        hoaFees: Double = 0
    ) -> MortgageResult {
        
        let principal = homePrice - downPayment
        let monthlyRate = interestRate / 100 / 12
        let numberOfPayments = Double(loanTerm * 12)
        
        // Calculate monthly payment using formula: M = P * (r(1+r)^n) / ((1+r)^n - 1)
        let monthlyPayment: Double
        if monthlyRate == 0 {
            monthlyPayment = principal / numberOfPayments
        } else {
            let factor = pow(1 + monthlyRate, numberOfPayments)
            monthlyPayment = principal * (monthlyRate * factor) / (factor - 1)
        }
        
        // Calculate total costs
        let totalInterest = (monthlyPayment * numberOfPayments) - principal
        let totalCost = homePrice + totalInterest
        
        // Calculate monthly totals
        let monthlyPropertyTax = propertyTax / 12
        let monthlyInsurance = homeInsurance / 12
        let monthlyPMI = pmi / 12
        let monthlyHOA = hoaFees / 12
        
        let totalMonthlyPayment = monthlyPayment + monthlyPropertyTax + monthlyInsurance + monthlyPMI + monthlyHOA
        
        // Generate amortization schedule
        let amortizationSchedule = generateAmortizationSchedule(
            principal: principal,
            monthlyRate: monthlyRate,
            numberOfPayments: Int(numberOfPayments),
            monthlyPayment: monthlyPayment
        )
        
        return MortgageResult(
            monthlyPayment: monthlyPayment,
            totalMonthlyPayment: totalMonthlyPayment,
            totalInterest: totalInterest,
            totalCost: totalCost,
            principal: principal,
            monthlyBreakdown: MonthlyBreakdown(
                principalAndInterest: monthlyPayment,
                propertyTax: monthlyPropertyTax,
                homeInsurance: monthlyInsurance,
                pmi: monthlyPMI,
                hoaFees: monthlyHOA
            ),
            amortizationSchedule: amortizationSchedule,
            loanToValueRatio: (principal / homePrice) * 100,
            downPaymentPercentage: (downPayment / homePrice) * 100
        )
    }
    
    // MARK: - Affordability Calculator
    
    func calculateAffordability(
        monthlyIncome: Double,
        monthlyDebts: Double,
        downPayment: Double,
        interestRate: Double,
        loanTerm: Int,
        debtToIncomeRatio: Double = 0.28,
        frontEndRatio: Double = 0.36
    ) -> AffordabilityResult {
        
        // Calculate maximum monthly payment based on income
        let maxMonthlyPayment = monthlyIncome * debtToIncomeRatio
        
        // Calculate maximum monthly housing payment including debts
        let maxHousingPayment = (monthlyIncome * frontEndRatio) - monthlyDebts
        
        // Use the more conservative estimate
        let affordableMonthlyPayment = min(maxMonthlyPayment, maxHousingPayment)
        
        // Calculate maximum loan amount
        let monthlyRate = interestRate / 100 / 12
        let numberOfPayments = Double(loanTerm * 12)
        
        let maxLoanAmount: Double
        if monthlyRate == 0 {
            maxLoanAmount = affordableMonthlyPayment * numberOfPayments
        } else {
            let factor = pow(1 + monthlyRate, numberOfPayments)
            maxLoanAmount = affordableMonthlyPayment * (factor - 1) / (monthlyRate * factor)
        }
        
        let maxHomePrice = maxLoanAmount + downPayment
        
        return AffordabilityResult(
            maxHomePrice: maxHomePrice,
            maxLoanAmount: maxLoanAmount,
            maxMonthlyPayment: affordableMonthlyPayment,
            recommendedDownPayment: downPayment,
            debtToIncomeRatio: (monthlyDebts / monthlyIncome) * 100,
            frontEndRatio: (affordableMonthlyPayment / monthlyIncome) * 100
        )
    }
    
    // MARK: - Refinancing Calculator
    
    func calculateRefinancing(
        currentLoanBalance: Double,
        currentInterestRate: Double,
        currentRemainingTerm: Int,
        newInterestRate: Double,
        newLoanTerm: Int,
        closingCosts: Double = 0
    ) -> RefinancingResult {
        
        // Calculate current monthly payment
        let currentMonthlyRate = currentInterestRate / 100 / 12
        let currentPayments = Double(currentRemainingTerm * 12)
        
        let currentMonthlyPayment: Double
        if currentMonthlyRate == 0 {
            currentMonthlyPayment = currentLoanBalance / currentPayments
        } else {
            let currentFactor = pow(1 + currentMonthlyRate, currentPayments)
            currentMonthlyPayment = currentLoanBalance * (currentMonthlyRate * currentFactor) / (currentFactor - 1)
        }
        
        // Calculate new monthly payment
        let newMonthlyRate = newInterestRate / 100 / 12
        let newPayments = Double(newLoanTerm * 12)
        
        let newMonthlyPayment: Double
        if newMonthlyRate == 0 {
            newMonthlyPayment = currentLoanBalance / newPayments
        } else {
            let newFactor = pow(1 + newMonthlyRate, newPayments)
            newMonthlyPayment = currentLoanBalance * (newMonthlyRate * newFactor) / (newFactor - 1)
        }
        
        // Calculate savings
        let monthlySavings = currentMonthlyPayment - newMonthlyPayment
        let totalCurrentCost = currentMonthlyPayment * currentPayments
        let totalNewCost = newMonthlyPayment * newPayments + closingCosts
        let totalSavings = totalCurrentCost - totalNewCost
        
        // Calculate break-even point
        let breakEvenMonths = closingCosts / monthlySavings
        
        return RefinancingResult(
            currentMonthlyPayment: currentMonthlyPayment,
            newMonthlyPayment: newMonthlyPayment,
            monthlySavings: monthlySavings,
            totalSavings: totalSavings,
            breakEvenMonths: breakEvenMonths,
            closingCosts: closingCosts,
            isWorthRefinancing: totalSavings > 0 && breakEvenMonths <= 60 // 5 years
        )
    }
    
    // MARK: - Rent vs Buy Calculator
    
    func calculateRentVsBuy(
        homePrice: Double,
        downPayment: Double,
        interestRate: Double,
        loanTerm: Int,
        monthlyRent: Double,
        propertyTax: Double,
        homeInsurance: Double,
        maintenance: Double,
        hoa: Double,
        rentIncrease: Double = 0.03,
        homeAppreciation: Double = 0.03,
        timeHorizon: Int = 10
    ) -> RentVsBuyResult {
        
        // Calculate mortgage details
        let mortgageResult = calculateMortgage(
            homePrice: homePrice,
            downPayment: downPayment,
            interestRate: interestRate,
            loanTerm: loanTerm,
            propertyTax: propertyTax,
            homeInsurance: homeInsurance,
            hoaFees: hoa
        )
        
        // Calculate costs over time horizon
        var totalBuyingCost = downPayment
        var totalRentCost: Double = 0
        var currentRent = monthlyRent
        var currentHomeValue = homePrice
        
        for year in 1...timeHorizon {
            // Buying costs
            let yearlyMortgagePayments = mortgageResult.monthlyPayment * 12
            let yearlyPropertyTax = propertyTax
            let yearlyInsurance = homeInsurance
            let yearlyMaintenance = maintenance
            let yearlyHOA = hoa
            
            totalBuyingCost += yearlyMortgagePayments + yearlyPropertyTax + yearlyInsurance + yearlyMaintenance + yearlyHOA
            
            // Rent costs
            totalRentCost += currentRent * 12
            currentRent *= (1 + rentIncrease)
            
            // Home appreciation
            currentHomeValue *= (1 + homeAppreciation)
        }
        
        // Calculate remaining mortgage balance
        let remainingBalance = calculateRemainingBalance(
            principal: mortgageResult.principal,
            monthlyRate: interestRate / 100 / 12,
            monthlyPayment: mortgageResult.monthlyPayment,
            paymentsMade: timeHorizon * 12
        )
        
        // Net cost of buying (total cost - equity built)
        let equityBuilt = currentHomeValue - remainingBalance
        let netBuyingCost = totalBuyingCost - equityBuilt
        
        return RentVsBuyResult(
            totalRentCost: totalRentCost,
            totalBuyingCost: totalBuyingCost,
            netBuyingCost: netBuyingCost,
            equityBuilt: equityBuilt,
            homeValueAfterAppreciation: currentHomeValue,
            recommendation: netBuyingCost < totalRentCost ? "Buy" : "Rent",
            savings: abs(netBuyingCost - totalRentCost),
            breakEvenYear: calculateBreakEvenYear(
                mortgageResult: mortgageResult,
                monthlyRent: monthlyRent,
                downPayment: downPayment,
                propertyTax: propertyTax,
                homeInsurance: homeInsurance,
                maintenance: maintenance,
                hoa: hoa,
                rentIncrease: rentIncrease,
                homeAppreciation: homeAppreciation
            )
        )
    }
    
    // MARK: - Helper Methods
    
    private func generateAmortizationSchedule(
        principal: Double,
        monthlyRate: Double,
        numberOfPayments: Int,
        monthlyPayment: Double
    ) -> [AmortizationEntry] {
        
        var schedule: [AmortizationEntry] = []
        var remainingBalance = principal
        
        for month in 1...numberOfPayments {
            let interestPayment = remainingBalance * monthlyRate
            let principalPayment = monthlyPayment - interestPayment
            remainingBalance -= principalPayment
            
            schedule.append(AmortizationEntry(
                month: month,
                payment: monthlyPayment,
                principal: principalPayment,
                interest: interestPayment,
                balance: max(0, remainingBalance)
            ))
            
            if remainingBalance <= 0 { break }
        }
        
        return schedule
    }
    
    private func calculateRemainingBalance(
        principal: Double,
        monthlyRate: Double,
        monthlyPayment: Double,
        paymentsMade: Int
    ) -> Double {
        
        if monthlyRate == 0 {
            return principal - (monthlyPayment * Double(paymentsMade))
        }
        
        let factor = pow(1 + monthlyRate, Double(paymentsMade))
        return principal * factor - monthlyPayment * (factor - 1) / monthlyRate
    }
    
    private func calculateBreakEvenYear(
        mortgageResult: MortgageResult,
        monthlyRent: Double,
        downPayment: Double,
        propertyTax: Double,
        homeInsurance: Double,
        maintenance: Double,
        hoa: Double,
        rentIncrease: Double,
        homeAppreciation: Double
    ) -> Int {
        
        var totalBuyingCost = downPayment
        var totalRentCost: Double = 0
        var currentRent = monthlyRent
        
        for year in 1...30 {
            // Annual costs
            totalBuyingCost += mortgageResult.monthlyPayment * 12 + propertyTax + homeInsurance + maintenance + hoa
            totalRentCost += currentRent * 12
            currentRent *= (1 + rentIncrease)
            
            if totalBuyingCost <= totalRentCost {
                return year
            }
        }
        
        return 30 // Default to 30 years if no break-even found
    }
}

// MARK: - Models

struct MortgageResult {
    let monthlyPayment: Double
    let totalMonthlyPayment: Double
    let totalInterest: Double
    let totalCost: Double
    let principal: Double
    let monthlyBreakdown: MonthlyBreakdown
    let amortizationSchedule: [AmortizationEntry]
    let loanToValueRatio: Double
    let downPaymentPercentage: Double
}

struct MonthlyBreakdown {
    let principalAndInterest: Double
    let propertyTax: Double
    let homeInsurance: Double
    let pmi: Double
    let hoaFees: Double
}

struct AmortizationEntry {
    let month: Int
    let payment: Double
    let principal: Double
    let interest: Double
    let balance: Double
}

struct AffordabilityResult {
    let maxHomePrice: Double
    let maxLoanAmount: Double
    let maxMonthlyPayment: Double
    let recommendedDownPayment: Double
    let debtToIncomeRatio: Double
    let frontEndRatio: Double
}

struct RefinancingResult {
    let currentMonthlyPayment: Double
    let newMonthlyPayment: Double
    let monthlySavings: Double
    let totalSavings: Double
    let breakEvenMonths: Double
    let closingCosts: Double
    let isWorthRefinancing: Bool
}

struct RentVsBuyResult {
    let totalRentCost: Double
    let totalBuyingCost: Double
    let netBuyingCost: Double
    let equityBuilt: Double
    let homeValueAfterAppreciation: Double
    let recommendation: String
    let savings: Double
    let breakEvenYear: Int
}