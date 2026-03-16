function Get-SldgGeneratorMap {
	<#
	.SYNOPSIS
		Maps semantic types to generator functions and parameters.
	.DESCRIPTION
		Returns a hashtable mapping each semantic type to the appropriate generator
		function and its default parameters. Uses the configured locale for data generation.
	#>
	[CmdletBinding()]
	param (
		[string]$Locale
	)

	if (-not $Locale) {
		$Locale = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.Locale'
	}

	@{
		# Person
		'FirstName'      = @{ Function = 'New-SldgPersonName'; Params = @{ Type = 'First'; Locale = $Locale } }
		'LastName'       = @{ Function = 'New-SldgPersonName'; Params = @{ Type = 'Last'; Locale = $Locale } }
		'MiddleName'     = @{ Function = 'New-SldgPersonName'; Params = @{ Type = 'Middle'; Locale = $Locale } }
		'FullName'       = @{ Function = 'New-SldgPersonName'; Params = @{ Type = 'Full'; Locale = $Locale } }

		# Contact
		'Email'          = @{ Function = 'New-SldgEmail'; Params = @{ Locale = $Locale } }
		'Phone'          = @{ Function = 'New-SldgPhone'; Params = @{ Format = 'Standard'; Locale = $Locale } }

		# Address
		'Street'         = @{ Function = 'New-SldgAddress'; Params = @{ Type = 'Street'; Locale = $Locale } }
		'City'           = @{ Function = 'New-SldgAddress'; Params = @{ Type = 'City'; Locale = $Locale } }
		'State'          = @{ Function = 'New-SldgAddress'; Params = @{ Type = 'State'; Locale = $Locale } }
		'ZipCode'        = @{ Function = 'New-SldgAddress'; Params = @{ Type = 'ZipCode'; Locale = $Locale } }
		'Country'        = @{ Function = 'New-SldgAddress'; Params = @{ Type = 'Country'; Locale = $Locale } }

		# Identity
		'SSN'            = @{ Function = 'New-SldgIdentifier'; Params = @{ Type = 'SSN'; Locale = $Locale } }
		'NationalId'     = @{ Function = 'New-SldgIdentifier'; Params = @{ Type = 'NationalId'; Locale = $Locale } }
		'PassportNumber' = @{ Function = 'New-SldgIdentifier'; Params = @{ Type = 'PassportNumber'; Locale = $Locale } }
		'LicenseNumber'  = @{ Function = 'New-SldgIdentifier'; Params = @{ Type = 'LicenseNumber'; Locale = $Locale } }
		'TaxId'          = @{ Function = 'New-SldgIdentifier'; Params = @{ Type = 'TaxId'; Locale = $Locale } }
		'Username'       = @{ Function = 'New-SldgIdentifier'; Params = @{ Type = 'Username'; Locale = $Locale } }
		'Password'       = @{ Function = 'New-SldgText'; Params = @{ Type = 'Password'; Locale = $Locale } }

		# Financial
		'IBAN'           = @{ Function = 'New-SldgIdentifier'; Params = @{ Type = 'IBAN'; Locale = $Locale } }
		'CreditCard'     = @{ Function = 'New-SldgIdentifier'; Params = @{ Type = 'CreditCard'; Locale = $Locale } }
		'BankAccount'    = @{ Function = 'New-SldgIdentifier'; Params = @{ Type = 'BankAccount'; Locale = $Locale } }
		'Money'          = @{ Function = 'New-SldgNumber'; Params = @{ Type = 'Money' } }
		'Currency'       = @{ Function = 'New-SldgFinancial'; Params = @{ Type = 'Currency'; Locale = $Locale } }
		'BusinessNumber' = @{ Function = 'New-SldgIdentifier'; Params = @{ Type = 'BusinessNumber'; Locale = $Locale } }

		# Dates
		'BirthDate'      = @{ Function = 'New-SldgDate'; Params = @{ Type = 'BirthDate' } }
		'PastDate'       = @{ Function = 'New-SldgDate'; Params = @{ Type = 'PastDate' } }
		'FutureDate'     = @{ Function = 'New-SldgDate'; Params = @{ Type = 'FutureDate' } }
		'Timestamp'      = @{ Function = 'New-SldgDate'; Params = @{ Type = 'Timestamp'; IncludeTime = $true } }
		'Date'           = @{ Function = 'New-SldgDate'; Params = @{ Type = 'Date' } }
		'DateTime'       = @{ Function = 'New-SldgDate'; Params = @{ Type = 'DateTime'; IncludeTime = $true } }
		'Time'           = @{ Function = 'New-SldgDate'; Params = @{ Type = 'Time' } }

		# Business
		'CompanyName'    = @{ Function = 'New-SldgCompany'; Params = @{ Type = 'Company'; Locale = $Locale } }
		'Department'     = @{ Function = 'New-SldgCompany'; Params = @{ Type = 'Department'; Locale = $Locale } }
		'JobTitle'       = @{ Function = 'New-SldgCompany'; Params = @{ Type = 'JobTitle'; Locale = $Locale } }

		# Web/Tech
		'Url'            = @{ Function = 'New-SldgText'; Params = @{ Type = 'Url'; Locale = $Locale } }
		'IpAddress'      = @{ Function = 'New-SldgText'; Params = @{ Type = 'IpAddress'; Locale = $Locale } }

		# Descriptive
		'Text'           = @{ Function = 'New-SldgText'; Params = @{ Type = 'Text'; Locale = $Locale } }
		'Status'         = @{ Function = 'New-SldgText'; Params = @{ Type = 'Status'; Locale = $Locale } }
		'Category'       = @{ Function = 'New-SldgText'; Params = @{ Type = 'Category'; Locale = $Locale } }
		'Gender'         = @{ Function = 'New-SldgText'; Params = @{ Type = 'Gender'; Locale = $Locale } }
		'Age'            = @{ Function = 'New-SldgNumber'; Params = @{ Type = 'Age' } }

		# Numeric
		'Integer'        = @{ Function = 'New-SldgNumber'; Params = @{ Type = 'Integer' } }
		'Decimal'        = @{ Function = 'New-SldgNumber'; Params = @{ Type = 'Decimal' } }
		'Boolean'        = @{ Function = 'New-SldgNumber'; Params = @{ Type = 'Boolean' } }
		'Quantity'       = @{ Function = 'New-SldgNumber'; Params = @{ Type = 'Quantity' } }
		'Percentage'     = @{ Function = 'New-SldgNumber'; Params = @{ Type = 'Percentage' } }

		# Identifiers
		'Guid'           = @{ Function = 'New-SldgIdentifier'; Params = @{ Type = 'Guid' } }
		'Code'           = @{ Function = 'New-SldgIdentifier'; Params = @{ Type = 'Code' } }

		# Generic strings
		'ShortString'    = @{ Function = 'New-SldgText'; Params = @{ Type = 'ShortString'; Locale = $Locale } }
		'MediumString'   = @{ Function = 'New-SldgText'; Params = @{ Type = 'MediumString'; Locale = $Locale } }
		'LongString'     = @{ Function = 'New-SldgText'; Params = @{ Type = 'LongString'; Locale = $Locale } }
		'FixedString'    = @{ Function = 'New-SldgText'; Params = @{ Type = 'ShortString'; Locale = $Locale } }
	}
}
