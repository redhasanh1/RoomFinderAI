/**
 * True Cost Calculator Module
 * Calculates and displays the real monthly cost of renting including all fees and expenses
 * Features: utilities, parking, pet fees, internet, insurance, and commute costs
 */

class TrueCostCalculator {
    constructor(config) {
        this.config = config;
        this.googleMapsApiKey = config.GOOGLE_API_KEY;
    }

    /**
     * Calculate total monthly cost for a listing
     * @param {Object} listing - The listing object with all cost data
     * @param {Object} userPreferences - User's work location and transportation preferences
     * @returns {Object} - Breakdown of all costs
     */
    async calculateTotalCost(listing, userPreferences = {}) {
        try {
            const breakdown = {
                baseRent: listing.price || 0,
                utilities: listing.utilities_cost || await this.estimateUtilities(listing),
                internet: listing.internet_cost || 50, // Default $50/month
                parking: listing.parking_fee || 0,
                petFee: listing.pet_fee || 0,
                amenityFees: listing.amenity_fees || 0,
                insurance: listing.renters_insurance || await this.estimateInsurance(listing.price),
                commuteCost: 0, // Will be calculated if user provides work location
                total: 0
            };

            // Calculate commute cost if user provided work location
            if (userPreferences.workLocation && listing.address) {
                const commute = await this.calculateCommuteCost(
                    listing.address,
                    userPreferences.workLocation,
                    userPreferences.transportMode || 'driving'
                );
                breakdown.commuteCost = commute.monthlyCost;
                breakdown.commuteDetails = commute;
            }

            // Calculate total
            breakdown.total =
                breakdown.baseRent +
                breakdown.utilities +
                breakdown.internet +
                breakdown.parking +
                breakdown.petFee +
                breakdown.amenityFees +
                breakdown.insurance +
                breakdown.commuteCost;

            // Round to 2 decimal places
            breakdown.total = Math.round(breakdown.total * 100) / 100;

            return breakdown;

        } catch (error) {
            console.error('❌ Error calculating total cost:', error);
            return this.getBasicCostBreakdown(listing);
        }
    }

    /**
     * Estimate utility costs based on property size and location
     */
    async estimateUtilities(listing) {
        try {
            // Base estimates by property type and size
            const bedrooms = listing.bedrooms || 1;
            const propertyType = listing.property_type || 'apartment';

            // Average utility costs per bedroom
            const utilityCostPerBedroom = {
                'apartment': 80,
                'house': 120,
                'condo': 90,
                'townhouse': 100,
                'studio': 60
            };

            const baseCost = utilityCostPerBedroom[propertyType] || 90;
            const estimatedCost = baseCost + ((bedrooms - 1) * 30);

            // Adjust for climate (if location data available)
            // TODO: Use weather API to adjust for heating/cooling costs

            console.log(`💡 Estimated utilities: $${estimatedCost}/month (${bedrooms} bed ${propertyType})`);
            return estimatedCost;

        } catch (error) {
            console.error('❌ Error estimating utilities:', error);
            return 100; // Default fallback
        }
    }

    /**
     * Estimate renters insurance based on property value
     */
    async estimateInsurance(monthlyRent) {
        try {
            // Typical renters insurance: $15-30/month
            // Higher for expensive properties
            if (monthlyRent >= 3000) {
                return 30;
            } else if (monthlyRent >= 2000) {
                return 25;
            } else if (monthlyRent >= 1500) {
                return 20;
            } else {
                return 15;
            }
        } catch (error) {
            console.error('❌ Error estimating insurance:', error);
            return 20; // Default fallback
        }
    }

    /**
     * Calculate monthly commute cost using Google Maps Distance Matrix API
     */
    async calculateCommuteCost(homeAddress, workAddress, transportMode = 'driving') {
        try {
            console.log('🚗 Calculating commute cost:', {
                from: homeAddress,
                to: workAddress,
                mode: transportMode
            });

            // Call Google Maps Distance Matrix API
            const response = await this.getDistanceMatrix(homeAddress, workAddress, transportMode);

            if (!response || !response.rows || !response.rows[0].elements[0]) {
                throw new Error('Invalid response from Distance Matrix API');
            }

            const element = response.rows[0].elements[0];

            if (element.status !== 'OK') {
                console.warn('⚠️ Could not calculate distance:', element.status);
                return { monthlyCost: 0, details: 'Unable to calculate' };
            }

            const distanceMeters = element.distance.value;
            const distanceMiles = (distanceMeters / 1609.34).toFixed(1);
            const durationSeconds = element.duration.value;
            const durationMinutes = Math.round(durationSeconds / 60);

            // Calculate monthly cost based on transportation mode
            let monthlyCost = 0;
            let details = '';

            // Assume 22 working days per month, round trip
            const monthlyMiles = distanceMiles * 2 * 22;

            switch (transportMode) {
                case 'driving':
                    // Average cost per mile: $0.67 (IRS rate 2026)
                    const costPerMile = 0.67;
                    monthlyCost = Math.round(monthlyMiles * costPerMile);
                    details = `${distanceMiles} miles one-way, ${durationMinutes} min drive`;
                    break;

                case 'transit':
                    // Average public transit monthly pass: $75-150
                    // Estimate based on distance
                    if (distanceMiles < 5) {
                        monthlyCost = 75;
                    } else if (distanceMiles < 15) {
                        monthlyCost = 100;
                    } else {
                        monthlyCost = 130;
                    }
                    details = `${distanceMiles} miles one-way, ${durationMinutes} min transit`;
                    break;

                case 'bicycling':
                    // Minimal cost for biking (maintenance, occasional ride-share)
                    monthlyCost = 20;
                    details = `${distanceMiles} miles one-way, ${durationMinutes} min bike`;
                    break;

                case 'walking':
                    // Free!
                    monthlyCost = 0;
                    details = `${distanceMiles} miles one-way, ${durationMinutes} min walk`;
                    break;

                default:
                    monthlyCost = 0;
                    details = 'Unknown transport mode';
            }

            return {
                monthlyCost,
                details,
                distanceMiles: parseFloat(distanceMiles),
                durationMinutes,
                mode: transportMode
            };

        } catch (error) {
            console.error('❌ Error calculating commute cost:', error);
            return { monthlyCost: 0, details: 'Unable to calculate commute cost' };
        }
    }

    /**
     * Call Google Maps Distance Matrix API
     */
    async getDistanceMatrix(origin, destination, mode = 'driving') {
        try {
            // For backend implementation (server-side API call to avoid exposing API key)
            const response = await fetch('/api/distance-matrix', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    origin,
                    destination,
                    mode
                })
            });

            if (!response.ok) {
                throw new Error('Distance Matrix API call failed');
            }

            const data = await response.json();
            return data;

        } catch (error) {
            console.error('❌ Error calling Distance Matrix API:', error);
            throw error;
        }
    }

    /**
     * Get basic cost breakdown without API calls
     */
    getBasicCostBreakdown(listing) {
        return {
            baseRent: listing.price || 0,
            utilities: listing.utilities_cost || 100,
            internet: listing.internet_cost || 50,
            parking: listing.parking_fee || 0,
            petFee: listing.pet_fee || 0,
            amenityFees: listing.amenity_fees || 0,
            insurance: 20,
            commuteCost: 0,
            total: (listing.price || 0) + 170 + (listing.parking_fee || 0) + (listing.pet_fee || 0)
        };
    }

    /**
     * Generate HTML for cost breakdown display
     */
    generateCostBreakdownHTML(breakdown) {
        const formatCurrency = (amount) => {
            return `$${amount.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`;
        };

        return `
            <div class="true-cost-breakdown">
                <div class="cost-header">
                    <h3 class="text-lg font-bold text-gray-900">True Monthly Cost</h3>
                    <div class="total-cost text-2xl font-bold text-purple-600">
                        ${formatCurrency(breakdown.total)}/month
                    </div>
                </div>

                <div class="cost-details mt-4 space-y-2">
                    <div class="cost-item flex justify-between">
                        <span class="text-gray-700">Base Rent</span>
                        <span class="font-medium">${formatCurrency(breakdown.baseRent)}</span>
                    </div>

                    ${breakdown.utilities > 0 ? `
                    <div class="cost-item flex justify-between">
                        <span class="text-gray-700">Utilities (est.)</span>
                        <span class="font-medium">${formatCurrency(breakdown.utilities)}</span>
                    </div>
                    ` : ''}

                    ${breakdown.internet > 0 ? `
                    <div class="cost-item flex justify-between">
                        <span class="text-gray-700">Internet</span>
                        <span class="font-medium">${formatCurrency(breakdown.internet)}</span>
                    </div>
                    ` : ''}

                    ${breakdown.parking > 0 ? `
                    <div class="cost-item flex justify-between">
                        <span class="text-gray-700">Parking</span>
                        <span class="font-medium">${formatCurrency(breakdown.parking)}</span>
                    </div>
                    ` : ''}

                    ${breakdown.petFee > 0 ? `
                    <div class="cost-item flex justify-between">
                        <span class="text-gray-700">Pet Fee</span>
                        <span class="font-medium">${formatCurrency(breakdown.petFee)}</span>
                    </div>
                    ` : ''}

                    ${breakdown.amenityFees > 0 ? `
                    <div class="cost-item flex justify-between">
                        <span class="text-gray-700">Amenity Fees</span>
                        <span class="font-medium">${formatCurrency(breakdown.amenityFees)}</span>
                    </div>
                    ` : ''}

                    ${breakdown.insurance > 0 ? `
                    <div class="cost-item flex justify-between">
                        <span class="text-gray-700">Renters Insurance (est.)</span>
                        <span class="font-medium">${formatCurrency(breakdown.insurance)}</span>
                    </div>
                    ` : ''}

                    ${breakdown.commuteCost > 0 ? `
                    <div class="cost-item flex justify-between">
                        <span class="text-gray-700">Commute Cost</span>
                        <span class="font-medium">${formatCurrency(breakdown.commuteCost)}</span>
                    </div>
                    ${breakdown.commuteDetails ? `
                    <div class="text-xs text-gray-500 ml-4">
                        ${breakdown.commuteDetails.details}
                    </div>
                    ` : ''}
                    ` : ''}

                    <div class="border-t border-gray-300 my-2"></div>

                    <div class="cost-item flex justify-between text-lg font-bold">
                        <span class="text-gray-900">Total Monthly Cost</span>
                        <span class="text-purple-600">${formatCurrency(breakdown.total)}</span>
                    </div>
                </div>

                <div class="cost-info mt-3 p-3 bg-blue-50 rounded-lg">
                    <p class="text-xs text-blue-800">
                        💡 This shows your true monthly cost including all fees and expenses.
                        ${breakdown.commuteCost > 0 ? 'Commute costs are estimated based on your work location.' : 'Add your work location to see commute costs.'}
                    </p>
                </div>
            </div>
        `;
    }

    /**
     * Display cost breakdown in a container
     */
    async displayCostBreakdown(containerId, listing, userPreferences = {}) {
        try {
            const container = document.getElementById(containerId);
            if (!container) {
                console.error('❌ Container not found:', containerId);
                return;
            }

            // Show loading state
            container.innerHTML = '<div class="text-center p-4"><div class="spinner"></div><p>Calculating true cost...</p></div>';

            // Calculate cost breakdown
            const breakdown = await this.calculateTotalCost(listing, userPreferences);

            // Display breakdown
            container.innerHTML = this.generateCostBreakdownHTML(breakdown);

        } catch (error) {
            console.error('❌ Error displaying cost breakdown:', error);
            container.innerHTML = '<div class="text-red-600 p-4">Error calculating costs</div>';
        }
    }
}

// Create global instance
window.trueCostCalculator = null;

// Initialize function
window.initializeTrueCostCalculator = (config) => {
    window.trueCostCalculator = new TrueCostCalculator(config);
    return window.trueCostCalculator;
};

export default TrueCostCalculator;
