<#
en-US locale data pack - United States English
Loaded after configuration.ps1 and locale functions (alphabetical: l < providers p)
#>
Register-SldgLocaleInternal -Name 'en-US' -Data @{
	# Person names
	MaleNames   = @('James', 'John', 'Robert', 'Michael', 'David', 'William', 'Richard', 'Joseph', 'Thomas', 'Christopher', 'Charles', 'Daniel', 'Matthew', 'Anthony', 'Mark', 'Steven', 'Andrew', 'Paul', 'Joshua', 'Kenneth', 'Kevin', 'Brian', 'George', 'Timothy', 'Ronald', 'Edward', 'Jason', 'Jeffrey', 'Ryan', 'Jacob', 'Nicholas', 'Eric', 'Benjamin', 'Samuel', 'Alexander', 'Patrick', 'Nathan', 'Adam', 'Henry', 'Peter', 'Ethan', 'Noah', 'Mason', 'Logan', 'Oliver', 'Lucas', 'Aiden', 'Elijah', 'Sebastian', 'Jack')
	FemaleNames = @('Mary', 'Patricia', 'Jennifer', 'Linda', 'Barbara', 'Elizabeth', 'Susan', 'Jessica', 'Sarah', 'Karen', 'Lisa', 'Nancy', 'Betty', 'Margaret', 'Sandra', 'Ashley', 'Dorothy', 'Kimberly', 'Emily', 'Donna', 'Michelle', 'Carol', 'Amanda', 'Melissa', 'Deborah', 'Stephanie', 'Rebecca', 'Sharon', 'Laura', 'Cynthia', 'Kathleen', 'Amy', 'Angela', 'Shirley', 'Anna', 'Brenda', 'Pamela', 'Emma', 'Nicole', 'Helen', 'Olivia', 'Sophia', 'Isabella', 'Mia', 'Charlotte', 'Amelia', 'Harper', 'Evelyn', 'Abigail', 'Grace')
	LastNames   = @('Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin', 'Lee', 'Perez', 'Thompson', 'White', 'Harris', 'Sanchez', 'Clark', 'Ramirez', 'Lewis', 'Robinson', 'Walker', 'Young', 'Allen', 'King', 'Wright', 'Scott', 'Torres', 'Nguyen', 'Hill', 'Flores', 'Green', 'Adams', 'Nelson', 'Baker', 'Hall', 'Rivera', 'Campbell', 'Mitchell', 'Carter', 'Roberts')

	# Address
	StreetNames = @('Main', 'Oak', 'Elm', 'Park', 'Cedar', 'Maple', 'Pine', 'Washington', 'Lake', 'Hill', 'River', 'Sunset', 'Broadway', 'Forest', 'Highland', 'Valley', 'Meadow', 'Spring', 'Cherry', 'Walnut', 'Lincoln', 'Madison', 'Jefferson', 'Franklin', 'Adams')
	StreetTypes = @('St', 'Ave', 'Blvd', 'Dr', 'Ln', 'Rd', 'Way', 'Ct', 'Pl', 'Cir')
	Locations   = @(
		@{ City = 'New York'; State = 'NY'; ZipPrefix = '100' }
		@{ City = 'Los Angeles'; State = 'CA'; ZipPrefix = '900' }
		@{ City = 'Chicago'; State = 'IL'; ZipPrefix = '606' }
		@{ City = 'Houston'; State = 'TX'; ZipPrefix = '770' }
		@{ City = 'Phoenix'; State = 'AZ'; ZipPrefix = '850' }
		@{ City = 'Philadelphia'; State = 'PA'; ZipPrefix = '191' }
		@{ City = 'San Antonio'; State = 'TX'; ZipPrefix = '782' }
		@{ City = 'San Diego'; State = 'CA'; ZipPrefix = '921' }
		@{ City = 'Dallas'; State = 'TX'; ZipPrefix = '752' }
		@{ City = 'Austin'; State = 'TX'; ZipPrefix = '787' }
		@{ City = 'Denver'; State = 'CO'; ZipPrefix = '802' }
		@{ City = 'Seattle'; State = 'WA'; ZipPrefix = '981' }
		@{ City = 'Boston'; State = 'MA'; ZipPrefix = '021' }
		@{ City = 'Nashville'; State = 'TN'; ZipPrefix = '372' }
		@{ City = 'Portland'; State = 'OR'; ZipPrefix = '972' }
		@{ City = 'Atlanta'; State = 'GA'; ZipPrefix = '303' }
		@{ City = 'Miami'; State = 'FL'; ZipPrefix = '331' }
		@{ City = 'Minneapolis'; State = 'MN'; ZipPrefix = '554' }
		@{ City = 'Charlotte'; State = 'NC'; ZipPrefix = '282' }
		@{ City = 'Detroit'; State = 'MI'; ZipPrefix = '482' }
	)
	Countries     = @('United States', 'US', 'USA')
	ZipFormat     = '{Prefix}{Suffix:D2}'
	AddressFormat = '{Number} {Street} {StreetType}'
	StateLabel    = 'State'

	# Contact
	EmailDomains = @('gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com', 'mail.com', 'protonmail.com', 'icloud.com', 'aol.com', 'zoho.com', 'fastmail.com', 'company.com', 'enterprise.org', 'corp.net', 'business.io', 'work.com')

	PhoneFormat = @{
		AreaCodes = @('201', '202', '205', '206', '207', '208', '209', '210', '212', '213', '214', '215', '216', '217', '218', '219', '224', '225', '228', '229', '231', '234', '239', '240', '248', '251', '252', '253', '254', '256', '260', '262', '267', '269', '270', '276', '281', '301', '302', '303', '304', '305', '307', '308', '309', '310', '312', '313', '314', '315', '316', '317', '318', '319', '320', '321')
		Formats   = @{
			Standard      = '({Area}) {Exchange}-{Subscriber}'
			International = '+1-{Area}-{Exchange}-{Subscriber}'
			Simple        = '{Area}{Exchange}{Subscriber}'
		}
		ExchangeMin    = 200
		ExchangeMax    = 999
		SubscriberMin  = 1000
		SubscriberMax  = 9999
	}

	# Business
	CompanyPrefixes = @('Acme', 'Global', 'United', 'Pacific', 'Atlantic', 'Premier', 'Advanced', 'National', 'American', 'Western', 'Northern', 'Southern', 'Eastern', 'Central', 'Metro', 'Summit', 'Apex', 'Prime', 'Elite', 'Pinnacle')
	CompanyCores    = @('Tech', 'Systems', 'Solutions', 'Industries', 'Services', 'Group', 'Partners', 'Holdings', 'Dynamics', 'Networks', 'Digital', 'Data', 'Cloud', 'Logic', 'Soft', 'Ware', 'Corp', 'Energy', 'Health', 'Bio')
	CompanySuffixes = @('Inc', 'LLC', 'Corp', 'Ltd', 'Co', 'Group', 'International', 'Enterprises', 'Associates', 'Consulting')
	Departments     = @('Engineering', 'Sales', 'Marketing', 'Human Resources', 'Finance', 'Accounting', 'Legal', 'Operations', 'Customer Support', 'Research & Development', 'Product Management', 'Quality Assurance', 'IT', 'Security', 'Administration', 'Logistics', 'Procurement', 'Training', 'Compliance', 'Business Development')
	JobTitles       = @('Software Engineer', 'Senior Developer', 'Project Manager', 'Business Analyst', 'Data Analyst', 'Product Manager', 'Sales Representative', 'Account Manager', 'Marketing Specialist', 'HR Coordinator', 'Financial Analyst', 'Operations Manager', 'Quality Engineer', 'Technical Lead', 'Architect', 'Consultant', 'Director', 'Vice President', 'Chief Technology Officer', 'Chief Financial Officer', 'Database Administrator', 'Systems Administrator', 'DevOps Engineer', 'Security Analyst', 'UX Designer', 'Technical Writer', 'Support Specialist', 'Procurement Officer', 'Compliance Manager', 'Team Lead')
	Industries      = @('Technology', 'Healthcare', 'Finance', 'Manufacturing', 'Retail', 'Education', 'Transportation', 'Energy', 'Telecommunications', 'Real Estate', 'Insurance', 'Consulting', 'Automotive', 'Pharmaceutical', 'Food & Beverage', 'Construction', 'Media', 'Aerospace', 'Agriculture', 'Hospitality')

	# Identifiers
	NationalIdFormat = '{Area:D3}-{Group:D2}-{Serial:D4}'   # SSN-like
	TaxIdFormat      = '{Part1:D2}-{Part2:D7}'
	IBANCountries    = @('US')
	Currencies       = @('USD', 'EUR', 'GBP', 'CAD', 'AUD')

	# Text
	Statuses   = @('Active', 'Inactive', 'Pending', 'Approved', 'Rejected', 'Cancelled', 'Completed', 'In Progress', 'On Hold', 'Draft', 'Archived', 'Closed', 'Open', 'New', 'Processing')
	Genders    = @('Male', 'Female', 'Non-binary', 'Other', 'Prefer not to say')
	Categories = @('Type A', 'Type B', 'Type C', 'Standard', 'Premium', 'Basic', 'Advanced', 'Professional', 'Enterprise', 'Starter')
}
