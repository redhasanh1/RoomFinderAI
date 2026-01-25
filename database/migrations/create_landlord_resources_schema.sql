-- Landlord Resources Schema
-- Stores state-specific legal resources, guides, templates, and calculators for landlords

-- Create landlord_resources table
CREATE TABLE IF NOT EXISTS landlord_resources (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  state_code TEXT NOT NULL, -- 'CA', 'NY', 'TX', 'FL', 'ALL' for federal/nationwide resources
  category TEXT NOT NULL CHECK (category IN (
    'rights', 'responsibilities', 'eviction', 'lease_templates', 'fair_housing',
    'security_deposits', 'maintenance', 'legal_forms', 'calculators', 'associations'
  )),
  title TEXT NOT NULL,
  content TEXT NOT NULL, -- Markdown formatted content
  resource_type TEXT NOT NULL CHECK (resource_type IN (
    'guide', 'template', 'faq', 'law_reference', 'calculator', 'contact', 'link'
  )),
  url TEXT, -- External resource link (if applicable)
  file_url TEXT, -- File attachment URL (for downloadable templates)
  metadata JSONB DEFAULT '{}'::jsonb, -- Additional metadata: {pdf_url, doc_url, tags: [], related_laws: []}
  last_updated DATE NOT NULL DEFAULT CURRENT_DATE,
  is_active BOOLEAN DEFAULT true, -- For soft deletion or hiding outdated resources
  display_order INTEGER DEFAULT 0, -- For custom ordering within category
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for faster queries
CREATE INDEX idx_landlord_resources_state ON landlord_resources(state_code);
CREATE INDEX idx_landlord_resources_category ON landlord_resources(category);
CREATE INDEX idx_landlord_resources_type ON landlord_resources(resource_type);
CREATE INDEX idx_landlord_resources_state_category ON landlord_resources(state_code, category);
CREATE INDEX idx_landlord_resources_active ON landlord_resources(is_active);

-- Enable Row Level Security
ALTER TABLE landlord_resources ENABLE ROW LEVEL SECURITY;

-- RLS Policy: All authenticated users can view resources
CREATE POLICY landlord_resources_select_all ON landlord_resources
  FOR SELECT
  USING (is_active = true); -- Only show active resources

-- Function to update updated_at timestamp
CREATE TRIGGER update_landlord_resources_updated_at
  BEFORE UPDATE ON landlord_resources
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Comment on table
COMMENT ON TABLE landlord_resources IS 'State-specific legal resources, guides, and templates for landlords including eviction procedures, security deposit rules, and fair housing compliance';

-- Comment on columns
COMMENT ON COLUMN landlord_resources.state_code IS 'Two-letter state code (e.g., CA, NY) or ALL for federal/nationwide resources';
COMMENT ON COLUMN landlord_resources.category IS 'Resource category for organization and filtering';
COMMENT ON COLUMN landlord_resources.content IS 'Main content in Markdown format for rich text rendering';
COMMENT ON COLUMN landlord_resources.metadata IS 'JSONB field for additional data like downloadable file URLs, tags, related laws';
COMMENT ON COLUMN landlord_resources.display_order IS 'Custom ordering within category (lower numbers appear first)';

-- Insert sample federal/nationwide resources
INSERT INTO landlord_resources (state_code, category, title, content, resource_type, url, display_order) VALUES

-- Federal Fair Housing Resources
('ALL', 'fair_housing', 'Federal Fair Housing Act Overview', '# Federal Fair Housing Act

The Fair Housing Act prohibits discrimination in housing based on:
- Race or color
- National origin
- Religion
- Sex (including sexual orientation and gender identity)
- Familial status (families with children under 18)
- Disability

**Prohibited Actions:**
- Refusing to rent or sell
- Discriminatory terms or conditions
- Discriminatory advertising
- Falsely denying availability
- Steering (directing to specific neighborhoods)
- Discriminatory lending practices

**Reasonable Accommodations:**
Landlords must make reasonable accommodations for tenants with disabilities, including:
- Allowing service animals and emotional support animals
- Modifying rules or policies
- Allowing physical modifications (at tenant expense)

**Penalties:**
- Civil penalties up to $19,787 for first offense
- Up to $98,935 for repeat violations
- Criminal penalties for hate crimes

**Resources:**
- HUD Fair Housing: 1-800-669-9777
- File complaint: [HUD website](https://www.hud.gov/fairhousing)
', 'law_reference', 'https://www.hud.gov/program_offices/fair_housing_equal_opp/fair_housing_act_overview', 1),

('ALL', 'fair_housing', 'Service Animals vs. Emotional Support Animals', '# Service Animals vs. Emotional Support Animals

**Service Animals:**
- Trained to perform specific tasks for disability
- Allowed in all housing (no pet fees)
- Limited to dogs (and miniature horses in some cases)
- No documentation required, but can ask about tasks

**Emotional Support Animals (ESA):**
- Provide comfort and support
- Allowed with proper documentation (letter from healthcare provider)
- Can be any animal species
- No pet fees or deposits allowed
- Must be reasonable accommodation

**Landlord Rights:**
- Can deny if animal poses direct threat
- Can deny if animal causes substantial damage
- Can require documentation for ESA (not service animals)
- Can enforce leash/control requirements

**Important:**
- ESAs do NOT have public access rights (only housing)
- Online ESA certificates are often invalid
- Documentation must be from actual healthcare provider with ongoing relationship
', 'guide', 'https://www.hud.gov/sites/dfiles/PA/documents/HUDAsstAnimalNC1-28-2020.pdf', 2),

-- Security Deposit Resources (Federal Guidelines)
('ALL', 'security_deposits', 'Security Deposit Best Practices', '# Security Deposit Best Practices

While state laws vary, follow these universal best practices:

**Collection:**
- Collect deposits in writing with receipt
- Document amount clearly in lease agreement
- Use separate bank account (required in some states)
- Never mix deposits with personal funds

**Documentation:**
- Conduct move-in inspection with tenant
- Take photos/videos of property condition
- Use standardized checklist
- Both parties sign inspection report

**During Tenancy:**
- Keep deposits in interest-bearing account (if required by state)
- Track any changes to deposit amount
- Document repairs and maintenance

**Move-Out:**
- Conduct move-out inspection (ideally with tenant)
- Compare to move-in condition
- Deduct only for damages beyond normal wear and tear
- Return deposit within state deadline with itemized statement

**Deductions (Generally Allowed):**
- Unpaid rent
- Damage beyond normal wear and tear
- Cleaning (if not left in reasonable condition)
- Repair costs for tenant-caused damage

**NOT Allowed Deductions:**
- Normal wear and tear (faded paint, worn carpet, minor scuffs)
- Pre-existing damage
- Improvements/upgrades
- Costs beyond reasonable repair

**Return Timeline:**
Most states: 14-30 days after move-out
California: 21 days
New York: 14 days
Texas: 30 days

**Penalties for Non-Compliance:**
- Forfeiture of deposit
- Statutory penalties (2-3x deposit amount in some states)
- Attorney fees for tenant
', 'guide', null, 1),

-- Eviction Resources
('ALL', 'eviction', 'Legal vs. Illegal Eviction Methods', '# Legal vs. Illegal Eviction Methods

## LEGAL EVICTION PROCESS

**Step 1: Notice to Tenant**
- Written notice (pay rent or quit, cure or quit, unconditional quit)
- Proper delivery method (certified mail, personal service, posting)
- State-required waiting period (3-90 days depending on state and reason)

**Step 2: Court Filing**
- File unlawful detainer lawsuit in local court
- Pay court filing fees ($100-$500)
- Serve tenant with court summons

**Step 3: Court Hearing**
- Present evidence (lease, notices, payment records)
- Tenant can present defense
- Judge issues ruling

**Step 4: Judgment & Writ of Possession**
- If landlord wins, court issues writ of possession
- Sheriff/marshal enforces eviction
- Tenant given final move-out deadline (usually 24 hours to 5 days)

**Valid Reasons for Eviction:**
- Non-payment of rent
- Lease violations (pets, subletting, noise, damage)
- Illegal activity
- End of lease term (in some states)
- Owner move-in (with proper notice)

## ILLEGAL EVICTION (SELF-HELP)

**NEVER DO THESE - All are ILLEGAL:**
- Changing locks
- Removing tenant belongings
- Shutting off utilities (water, electricity, heat, gas)
- Threats or intimidation
- Removing doors or windows
- Physical removal of tenant
- Harassment to force tenant out

**Consequences of Illegal Eviction:**
- Tenant can sue for damages
- Statutory penalties ($100/day in some states)
- Actual damages (hotel costs, belongings damage)
- Emotional distress damages
- Attorney fees
- Criminal charges (in some states)
- Tenant may have right to remain
- Landlord loses right to evict for current reason

## RETALIATORY EVICTION (ILLEGAL)

**Cannot evict because tenant:**
- Complained about habitability issues
- Reported code violations
- Contacted health/safety inspectors
- Joined tenant union
- Exercised legal rights

**Protection Period:**
- Most states: 90-180 days after protected action
- Burden of proof shifts to landlord

## TIPS FOR LEGAL EVICTION:
1. Document everything in writing
2. Follow state notice requirements exactly
3. Never skip steps or deadlines
4. Hire an attorney if unsure
5. Be patient - process takes 30-90 days typically
6. Keep emotions out of it - it''s business
', 'guide', null, 1);

-- State-specific resources will be added via admin interface or additional migrations
-- Examples for California:
INSERT INTO landlord_resources (state_code, category, title, content, resource_type, metadata, display_order) VALUES
('CA', 'security_deposits', 'California Security Deposit Limits', '# California Security Deposit Limits

**Maximum Amounts:**
- Unfurnished: 2 months rent
- Furnished: 3 months rent
- Service members: 1 month rent (active duty military)

**Interest Requirements:**
- Not required by state law
- Some cities (e.g., San Francisco, Los Angeles) require interest

**Return Timeline:**
- 21 days after tenant moves out

**Itemization:**
- Must provide itemized statement of deductions
- Include copies of receipts if repairs exceed $126
- Failure to provide statement = forfeit right to keep any deposit

**Allowable Deductions:**
- Unpaid rent
- Damage beyond normal wear and tear
- Cleaning (if not reasonably clean)
- Costs to restore to original condition

**Penalties:**
- Bad faith retention: up to 2x deposit amount + attorney fees
', 'law_reference', jsonb_build_object('law_code', 'California Civil Code Section 1950.5'), 1),

('NY', 'security_deposits', 'New York Security Deposit Rules', '# New York Security Deposit Rules

**Maximum Amount:**
- 1 month rent (statewide since 2019)

**Interest Requirements:**
- Buildings with 6+ units must pay interest annually
- Rate set by NYS Comptroller

**Return Timeline:**
- 14 days (reasonable time)

**Itemization:**
- Must provide itemized statement of deductions
- Withholding without itemization may result in forfeiture

**Special Requirements:**
- Separate bank account required
- Cannot commingle with personal funds

**Penalties:**
- Wrongful retention: actual damages + punitive damages
', 'law_reference', jsonb_build_object('law_code', 'New York General Obligations Law 7-108'), 1);

COMMENT ON TABLE landlord_resources IS 'Contains legal resources and guidance for landlords, organized by state and category';
