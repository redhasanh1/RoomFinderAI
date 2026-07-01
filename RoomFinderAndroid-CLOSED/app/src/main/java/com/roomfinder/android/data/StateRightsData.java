package com.roomfinder.android.data;

import java.util.HashMap;
import java.util.Map;

public class StateRightsData {
    
    public static class TenantRightsInfo {
        private String securityDepositRights;
        private String rentIncreaseRights;
        private String repairMaintenanceRights;
        private String evictionProtectionRights;
        private String state;
        
        public TenantRightsInfo(String state, String securityDepositRights, String rentIncreaseRights, 
                              String repairMaintenanceRights, String evictionProtectionRights) {
            this.state = state;
            this.securityDepositRights = securityDepositRights;
            this.rentIncreaseRights = rentIncreaseRights;
            this.repairMaintenanceRights = repairMaintenanceRights;
            this.evictionProtectionRights = evictionProtectionRights;
        }
        
        public String getSecurityDepositRights() { return securityDepositRights; }
        public String getRentIncreaseRights() { return rentIncreaseRights; }
        public String getRepairMaintenanceRights() { return repairMaintenanceRights; }
        public String getEvictionProtectionRights() { return evictionProtectionRights; }
        public String getState() { return state; }
    }
    
    private static Map<String, TenantRightsInfo> stateRightsMap = null;
    private static final Object lock = new Object();
    
    private static void initializeStateRights() {
        stateRightsMap = new HashMap<>();
        // California
        stateRightsMap.put("California", new TenantRightsInfo(
            "California",
            // Security Deposits
            "In California:\n" +
            "• Maximum deposit is 2x monthly rent for unfurnished units, 3x for furnished\n" +
            "• Deposits must be returned within 21 days after move-out\n" +
            "• Itemized list of deductions required if any amount is withheld\n" +
            "• Interest may be required in some cities (like San Francisco)\n" +
            "• Landlord cannot charge for normal wear and tear\n" +
            "• Photos and receipts must be provided for claimed damages\n" +
            "• Bad faith retention can result in up to $600 in damages plus attorney fees",
            
            // Rent Increases
            "In California:\n" +
            "• 30-day notice required for rent increases up to 10%\n" +
            "• 90-day notice required for increases over 10%\n" +
            "• Rent control laws vary by city (LA, SF, Oakland, etc.)\n" +
            "• AB 1482 limits increases to 5% + inflation (max 10%) statewide\n" +
            "• Just cause eviction requirements for properties over 15 years old\n" +
            "• Some cities have stronger rent stabilization ordinances\n" +
            "• Mobile home rent increases have special 90-day notice requirements",
            
            // Repairs & Maintenance
            "In California:\n" +
            "• Warranty of habitability - landlord must maintain livable conditions\n" +
            "• Required to repair within 30 days of written notice\n" +
            "• Tenant can withhold rent for serious habitability issues\n" +
            "• Tenant can 'repair and deduct' up to one month's rent\n" +
            "• Right to break lease for uninhabitable conditions\n" +
            "• Landlord must provide 24-hour notice before entry (except emergencies)\n" +
            "• Retaliation for repair requests is illegal and can be costly for landlords",
            
            // Eviction Protection
            "In California:\n" +
            "• Just cause required for evictions in many cities and statewide (AB 1482)\n" +
            "• 3-day notice for nonpayment of rent\n" +
            "• 30-day notice for no-fault evictions (where allowed)\n" +
            "• 60-day notice if tenant has lived there over 1 year\n" +
            "• Ellis Act allows evictions for going out of rental business\n" +
            "• COVID-19 protections may still apply\n" +
            "• Right to legal representation in some cities\n" +
            "• Unlawful detainer process required - self-help evictions are illegal"
        ));
        
        // New York
        stateRightsMap.put("New York", new TenantRightsInfo(
            "New York",
            // Security Deposits
            "In New York:\n" +
            "• Maximum deposit is 1 month's rent\n" +
            "• Must be returned within 14 days (unless lease specifies reasonable time)\n" +
            "• Interest required on deposits over $1,000 held more than 1 year\n" +
            "• Itemized statement required for any deductions\n" +
            "• Must be held in separate bank account\n" +
            "• Normal wear and tear cannot be charged to tenant\n" +
            "• Failure to return can result in double damages",
            
            // Rent Increases  
            "In New York:\n" +
            "• Rent stabilized units: increases set by Rent Guidelines Board\n" +
            "• Market rate units: 30-day notice for month-to-month tenancies\n" +
            "• Lease renewals: increases limited by rent stabilization laws\n" +
            "• Major Capital Improvements (MCI) have special rules\n" +
            "• Individual Apartment Improvements (IAI) are limited\n" +
            "• Housing Stability and Tenant Protection Act limits increases\n" +
            "• Good cause eviction laws in some areas",
            
            // Repairs & Maintenance
            "In New York:\n" +
            "• Warranty of habitability applies to all rental units\n" +
            "• Housing code violations must be corrected\n" +
            "• Tenant can request HPD inspection\n" +
            "• Right to withhold rent for serious violations (with court approval)\n" +
            "• Emergency repairs can be made and charged to landlord\n" +
            "• Lead paint disclosure required\n" +
            "• Heat and hot water must be provided (specific temperature requirements)",
            
            // Eviction Protection
            "In New York:\n" +
            "• Good cause eviction protections in many areas\n" +
            "• 14-day notice for nonpayment (can pay to cure)\n" +
            "• 30-day notice for lease violations (10 days to cure)\n" +
            "• Right to legal representation (Right to Counsel)\n" +
            "• Rent stabilized tenants have strong eviction protections\n" +
            "• Emergency Tenant Protection Act (ETPA) in some areas\n" +
            "• COVID-19 protections extended multiple times"
        ));
        
        // Texas
        stateRightsMap.put("Texas", new TenantRightsInfo(
            "Texas",
            // Security Deposits
            "In Texas:\n" +
            "• No statewide limit on security deposit amounts\n" +
            "• Must be returned within 30 days after move-out\n" +
            "• Itemized list required if any amount is withheld\n" +
            "• Normal wear and tear cannot be charged\n" +
            "• Bad faith retention can result in $100 + 3x deposit in damages\n" +
            "• Interest not required unless specified in lease\n" +
            "• Must provide forwarding address to get deposit back",
            
            // Rent Increases
            "In Texas:\n" +
            "• No rent control - landlords can increase rent freely\n" +
            "• Must give notice as specified in lease (typically 30 days)\n" +
            "• Month-to-month: 30-day notice required\n" +
            "• Cannot increase during lease term unless lease allows\n" +
            "• No statewide limit on amount of increase\n" +
            "• Some cities may have limited protections\n" +
            "• Retaliatory rent increases are prohibited",
            
            // Repairs & Maintenance
            "In Texas:\n" +
            "• Landlord must make repairs affecting health and safety\n" +
            "• Written notice required before tenant can take action\n" +
            "• Tenant can terminate lease for failure to repair\n" +
            "• Limited repair and deduct rights (must follow specific procedures)\n" +
            "• Landlord must provide reasonable entry notice\n" +
            "• Air conditioning not required by law\n" +
            "• Local housing codes may provide additional protections",
            
            // Eviction Protection
            "In Texas:\n" +
            "• 3-day notice for nonpayment of rent\n" +
            "• 30-day notice for lease violations\n" +
            "• No statewide just cause requirement\n" +
            "• Fast-track eviction process (can be completed in weeks)\n" +
            "• Self-help evictions are prohibited\n" +
            "• Tenant has right to jury trial\n" +
            "• Some cities have tenant protection ordinances"
        ));
        
        // Florida
        stateRightsMap.put("Florida", new TenantRightsInfo(
            "Florida",
            // Security Deposits
            "In Florida:\n" +
            "• No limit on security deposit amounts\n" +
            "• Must be returned within 15 days (30 days if deductions made)\n" +
            "• Must provide written notice of intention to impose claim\n" +
            "• Tenant has 15 days to object to deductions\n" +
            "• Interest required if deposit exceeds $50 and is held over 6 months\n" +
            "• Must be held in separate Florida bank account\n" +
            "• Bad faith retention can result in damages up to amount of deposit",
            
            // Rent Increases
            "In Florida:\n" +
            "• No rent control allowed by state law\n" +
            "• 15-day notice required for week-to-week tenancies\n" +
            "• 30-day notice required for month-to-month tenancies\n" +
            "• Cannot increase during lease term unless lease allows\n" +
            "• No limit on amount of increase\n" +
            "• Retaliatory increases are prohibited\n" +
            "• Mobile home rent increases have special notice requirements",
            
            // Repairs & Maintenance
            "In Florida:\n" +
            "• Landlord must maintain premises in good repair\n" +
            "• Must comply with building, housing, and health codes\n" +
            "• 7-day written notice required before tenant action\n" +
            "• Tenant can terminate lease for failure to maintain\n" +
            "• Limited withholding of rent allowed (with court deposit)\n" +
            "• 12-hour notice required for landlord entry\n" +
            "• Air conditioning repair required if provided",
            
            // Eviction Protection
            "In Florida:\n" +
            "• 3-day notice for nonpayment (excluding weekends/holidays)\n" +
            "• 7-day notice for lease violations (some allow cure period)\n" +
            "• 15-day notice for month-to-month termination\n" +
            "• No statewide just cause requirement\n" +
            "• Relatively fast eviction process\n" +
            "• Self-help evictions are prohibited\n" +
            "• Some counties have mediation programs"
        ));
        
        // Illinois
        stateRightsMap.put("Illinois", new TenantRightsInfo(
            "Illinois",
            // Security Deposits
            "In Illinois:\n" +
            "• No statewide limit (Chicago limits to 1.5x rent)\n" +
            "• Must be returned within 45 days after move-out\n" +
            "• Itemized statement required for deductions\n" +
            "• Interest required on deposits held over 6 months\n" +
            "• Must be held in separate account\n" +
            "• Normal wear and tear cannot be charged\n" +
            "• Bad faith retention can result in 2x deposit in damages",
            
            // Rent Increases
            "In Illinois:\n" +
            "• 30-day notice required for month-to-month tenancies\n" +
            "• Chicago has rent control ordinance for some units\n" +
            "• Cannot increase during lease term unless lease allows\n" +
            "• Some municipalities have rent stabilization\n" +
            "• Retaliatory increases are prohibited\n" +
            "• Mobile home increases have special requirements\n" +
            "• Just cause eviction in some cities",
            
            // Repairs & Maintenance
            "In Illinois:\n" +
            "• Warranty of habitability applies\n" +
            "• Landlord must maintain premises in habitable condition\n" +
            "• 14-day written notice required before tenant action\n" +
            "• Right to withhold rent for serious habitability issues\n" +
            "• Repair and deduct allowed in some circumstances\n" +
            "• 48-hour notice required for entry\n" +
            "• Local housing codes provide additional protections",
            
            // Eviction Protection
            "In Illinois:\n" +
            "• 5-day notice for nonpayment of rent\n" +
            "• 10-day notice for lease violations (some curable)\n" +
            "• 30-day notice for month-to-month termination\n" +
            "• Some cities require just cause for eviction\n" +
            "• Chicago has strong tenant protections\n" +
            "• Right to legal representation in some areas\n" +
            "• Sealed eviction records available in some cases"
        ));
    }
    
    public static TenantRightsInfo getRightsForState(String state) {
        // Lazy initialization with thread safety
        if (stateRightsMap == null) {
            synchronized (lock) {
                if (stateRightsMap == null) {
                    initializeStateRights();
                }
            }
        }
        
        TenantRightsInfo rights = stateRightsMap.get(state);
        if (rights != null) {
            return rights;
        }
        
        // Return generic rights information for states not in database
        return new TenantRightsInfo(
            state,
            // Generic Security Deposits
            String.format("In %s:\n", state) +
            "• Security deposit laws vary by state\n" +
            "• Deposits typically must be returned within 14-60 days\n" +
            "• Itemized deductions usually required\n" +
            "• Normal wear and tear generally cannot be charged\n" +
            "• Check your state's specific laws for exact requirements\n" +
            "• Some states require interest on deposits\n" +
            "• Bad faith retention may result in damages",
            
            // Generic Rent Increases
            String.format("In %s:\n", state) +
            "• Notice requirements vary (typically 30 days)\n" +
            "• Some areas have rent control or stabilization\n" +
            "• Cannot increase during lease term unless allowed\n" +
            "• Retaliatory increases are generally prohibited\n" +
            "• Check local laws for specific requirements\n" +
            "• Some states limit the amount of increases\n" +
            "• Senior and low-income protections may apply",
            
            // Generic Repairs & Maintenance
            String.format("In %s:\n", state) +
            "• Landlords generally must maintain habitable conditions\n" +
            "• Warranty of habitability typically applies\n" +
            "• Written notice usually required before tenant action\n" +
            "• Tenants may have right to withhold rent for serious issues\n" +
            "• Repair and deduct rights vary by state\n" +
            "• Entry notice requirements vary (12-48 hours typical)\n" +
            "• Local housing codes provide additional protections",
            
            // Generic Eviction Protection
            String.format("In %s:\n", state) +
            "• Notice periods vary by reason for eviction\n" +
            "• Nonpayment notices typically 3-14 days\n" +
            "• Lease violation notices vary\n" +
            "• Self-help evictions are prohibited\n" +
            "• Court process required for legal eviction\n" +
            "• Some areas have just cause requirements\n" +
            "• Legal aid may be available for tenants"
        );
    }
    
    public static boolean hasStateData(String state) {
        // Ensure map is initialized
        if (stateRightsMap == null) {
            synchronized (lock) {
                if (stateRightsMap == null) {
                    initializeStateRights();
                }
            }
        }
        return stateRightsMap.containsKey(state);
    }
    
    public static String[] getSupportedStates() {
        // Ensure map is initialized
        if (stateRightsMap == null) {
            synchronized (lock) {
                if (stateRightsMap == null) {
                    initializeStateRights();
                }
            }
        }
        return stateRightsMap.keySet().toArray(new String[0]);
    }
}