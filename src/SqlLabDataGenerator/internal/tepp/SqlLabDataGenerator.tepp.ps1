# Provider names
Register-PSFTeppScriptblock -Name "SqlLabDataGenerator.Provider" -ScriptBlock {
	$script:SldgState.Providers.Keys | Sort-Object
}

# Generation modes
Register-PSFTeppScriptblock -Name "SqlLabDataGenerator.GenerationMode" -ScriptBlock {
	'Synthetic', 'Masking', 'Scenario'
}

# AI provider names
Register-PSFTeppScriptblock -Name "SqlLabDataGenerator.AIProvider" -ScriptBlock {
	'None', 'OpenAI', 'AzureOpenAI', 'Ollama'
}

# Semantic types
Register-PSFTeppScriptblock -Name "SqlLabDataGenerator.SemanticType" -ScriptBlock {
	'FirstName', 'LastName', 'FullName', 'MiddleName', 'Email', 'Phone',
	'Street', 'City', 'State', 'ZipCode', 'Country',
	'SSN', 'NationalId', 'TaxId', 'IBAN', 'CreditCard', 'BankAccount',
	'Money', 'Currency', 'BusinessNumber',
	'BirthDate', 'PastDate', 'FutureDate', 'Timestamp',
	'CompanyName', 'Department', 'JobTitle',
	'Url', 'IpAddress', 'Username', 'Password',
	'Text', 'Status', 'Category', 'Gender', 'Age',
	'Integer', 'Decimal', 'Boolean', 'Quantity', 'Percentage',
	'Guid', 'Code'
}

# Industry hints
Register-PSFTeppScriptblock -Name "SqlLabDataGenerator.Industry" -ScriptBlock {
	'Technology', 'Healthcare', 'Finance', 'Manufacturing', 'Retail', 'Education',
	'Transportation', 'Energy', 'Telecommunications', 'Real Estate', 'Insurance',
	'Consulting', 'Automotive', 'Pharmaceutical', 'Hospitality', 'Government'
}

# Locale names (static + AI-generated)
Register-PSFTeppScriptblock -Name "SqlLabDataGenerator.Locale" -ScriptBlock {
	($script:SldgState.Locales.Keys + $script:SldgState.AILocaleCache.Keys) | Sort-Object -Unique
}

# Locale categories (for mixing)
Register-PSFTeppScriptblock -Name "SqlLabDataGenerator.LocaleCategory" -ScriptBlock {
	'PersonNames', 'Addresses', 'PhoneFormat', 'Companies', 'Identifiers', 'Email', 'Text'
}

# Transformer names
Register-PSFTeppScriptblock -Name "SqlLabDataGenerator.Transformer" -ScriptBlock {
	$script:SldgState.Transformers.Keys | Sort-Object
}

# Phone format
Register-PSFTeppScriptblock -Name "SqlLabDataGenerator.PhoneFormat" -ScriptBlock {
	'Standard', 'International', 'Simple'
}