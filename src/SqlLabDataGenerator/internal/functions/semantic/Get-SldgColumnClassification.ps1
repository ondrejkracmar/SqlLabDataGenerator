function Get-SldgColumnClassification {
	<#
	.SYNOPSIS
		Classifies a column semantically using pattern matching on the column name.
	.DESCRIPTION
		Matches column names against known patterns to determine what real-world concept
		the column represents. More specific patterns are checked first.
		Falls back to data-type-based inference if no pattern matches.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$Column,

		[string]$TableName
	)

	$name = $Column.ColumnName.ToLower()
	$dataType = $Column.DataType.ToLower()

	# Pattern matching rules (most specific first)
	$patterns = @(
		# Person names
		@{ Pattern = '(first|given|fname)[\s_]?name'; Type = 'FirstName'; IsPII = $true }
		@{ Pattern = '(last|sur|family|lname)[\s_]?name'; Type = 'LastName'; IsPII = $true }
		@{ Pattern = '(middle)[\s_]?name'; Type = 'MiddleName'; IsPII = $true }
		@{ Pattern = '(full|display)[\s_]?name'; Type = 'FullName'; IsPII = $true }

		# Contact
		@{ Pattern = 'e[\s_-]?mail'; Type = 'Email'; IsPII = $true }
		@{ Pattern = '(phone|tel|mobile|fax|cell)[\s_]?(number)?'; Type = 'Phone'; IsPII = $true }

		# Address
		@{ Pattern = '(street|address[\s_]?line|addr[\s_]?[12]?)'; Type = 'Street'; IsPII = $true }
		@{ Pattern = '^(city|town|municipality)$'; Type = 'City'; IsPII = $false }
		@{ Pattern = '(city|town|municipality)[\s_]?(name)?'; Type = 'City'; IsPII = $false }
		@{ Pattern = '(state|province|region)[\s_]?(code|name)?'; Type = 'State'; IsPII = $false }
		@{ Pattern = '(zip|postal)[\s_]?(code)?'; Type = 'ZipCode'; IsPII = $true }
		@{ Pattern = 'country'; Type = 'Country'; IsPII = $false }

		# Identity documents
		@{ Pattern = '(ssn|social[\s_]?security)'; Type = 'SSN'; IsPII = $true }
		@{ Pattern = '(national[\s_]?id|personal[\s_]?id|rodne[\s_]?cislo)'; Type = 'NationalId'; IsPII = $true }
		@{ Pattern = '(passport)'; Type = 'PassportNumber'; IsPII = $true }
		@{ Pattern = '(driver|license)[\s_]?(number|no)?'; Type = 'LicenseNumber'; IsPII = $true }
		@{ Pattern = '(tax[\s_]?id|ein|tin|ico|dic|vat[\s_]?number)'; Type = 'TaxId'; IsPII = $true }

		# Financial
		@{ Pattern = '(iban)'; Type = 'IBAN'; IsPII = $true }
		@{ Pattern = '(credit[\s_]?card|card[\s_]?number|\bpan\b)'; Type = 'CreditCard'; IsPII = $true }
		@{ Pattern = '(bank[\s_]?account|account[\s_]?number|cislo[\s_]?uctu)'; Type = 'BankAccount'; IsPII = $true }
		@{ Pattern = '(amount|total|subtotal|balance|debit|credit)(?![\s_]?(date|at|on))'; Type = 'Money'; IsPII = $false }
		@{ Pattern = '(price|cost|fee|rate(?![\s_]?date)|salary|wage|revenue)'; Type = 'Money'; IsPII = $false }
		@{ Pattern = '^currency'; Type = 'Currency'; IsPII = $false }

		# Dates
		@{ Pattern = '(birth[\s_]?date|date[\s_]?of[\s_]?birth|dob|datum[\s_]?narozeni)'; Type = 'BirthDate'; IsPII = $true }
		@{ Pattern = '(hire[\s_]?date|start[\s_]?date|join[\s_]?date|employment[\s_]?date)'; Type = 'PastDate'; IsPII = $false }
		@{ Pattern = '(end[\s_]?date|termination|expir)'; Type = 'FutureDate'; IsPII = $false }
		@{ Pattern = '(created|modified|updated|changed|inserted)[\s_]?(date|at|on|time)?$'; Type = 'Timestamp'; IsPII = $false }
		@{ Pattern = '(order[\s_]?date|invoice[\s_]?date|ship[\s_]?date|delivery[\s_]?date|purchase[\s_]?date)'; Type = 'PastDate'; IsPII = $false }

		# Business
		@{ Pattern = '(invoice[\s_]?(number|no|num|id)|order[\s_]?(number|no|num)|po[\s_]?(number|no))'; Type = 'BusinessNumber'; IsPII = $false }
		@{ Pattern = '(company|organization|employer|vendor|supplier|manufacturer)[\s_]?(name)?'; Type = 'CompanyName'; IsPII = $false }
		@{ Pattern = '(department|division|unit)[\s_]?(name)?'; Type = 'Department'; IsPII = $false }
		@{ Pattern = '(title|position|role|job[\s_]?title)'; Type = 'JobTitle'; IsPII = $false }

		# Web/Tech
		@{ Pattern = '(url|uri|website|web[\s_]?address|homepage)'; Type = 'Url'; IsPII = $false }
		@{ Pattern = '(ip[\s_]?address|ip[\s_]?addr|ipaddress)'; Type = 'IpAddress'; IsPII = $true }
		@{ Pattern = '(user[\s_]?name|login[\s_]?name|username)'; Type = 'Username'; IsPII = $true }
		@{ Pattern = '(password|passwd|pwd|heslo)'; Type = 'Password'; IsPII = $true }

		# Structured data (JSON / XML)
		@{ Pattern = '(json|json_data|json_content|jsondata|payload|metadata|properties|attributes|settings|config|configuration|options|preferences|params|parameters)'; Type = 'Json'; IsPII = $false }
		@{ Pattern = '(xml|xml_data|xml_content|xmldata|soap|message_body|request_body|response_body)'; Type = 'Xml'; IsPII = $false }

		# Descriptive text
		@{ Pattern = '(description|desc|comment|note|remark|memo|poznamka)'; Type = 'Text'; IsPII = $false }
		@{ Pattern = '(status|stav)'; Type = 'Status'; IsPII = $false }
		@{ Pattern = '(type|category|kind|class|typ|kategorie)[\s_]?(name|code|id)?$'; Type = 'Category'; IsPII = $false }
		@{ Pattern = '(gender|sex|pohlavi)'; Type = 'Gender'; IsPII = $true }
		@{ Pattern = '^age$|^vek$'; Type = 'Age'; IsPII = $false }

		# Boolean-ish
		@{ Pattern = '^(is[\s_]|has[\s_]|can[\s_]|active|enabled|disabled|deleted|archived|flag|visible)'; Type = 'Boolean'; IsPII = $false }

		# Quantity
		@{ Pattern = '(quantity|qty|count|number[\s_]?of|num[\s_]?of|pocet)'; Type = 'Quantity'; IsPII = $false }
		@{ Pattern = '(percent|pct|ratio|procento)'; Type = 'Percentage'; IsPII = $false }

		# Generic name column (low priority)
		@{ Pattern = '^name$|^nazev$|^jmeno$'; Type = 'FullName'; IsPII = $true }
	)

	foreach ($rule in $patterns) {
		if ($name -match $rule.Pattern) {
			return [PSCustomObject]@{
				PSTypeName   = 'SqlLabDataGenerator.ColumnClassification'
				ColumnName   = $Column.ColumnName
				TableName    = $TableName
				SemanticType = $rule.Type
				IsPII        = $rule.IsPII
				Confidence   = 0.8
				Source       = 'PatternMatch'
				MatchedRule  = $rule.Pattern
			}
		}
	}

	# Fallback: classify by data type
	$typeClass = Resolve-SldgSemanticType -DataType $dataType -MaxLength $Column.MaxLength -IsNullable $Column.IsNullable

	[PSCustomObject]@{
		PSTypeName   = 'SqlLabDataGenerator.ColumnClassification'
		ColumnName   = $Column.ColumnName
		TableName    = $TableName
		SemanticType = $typeClass.Type
		IsPII        = $false
		Confidence   = 0.3
		Source       = 'DataTypeInference'
		MatchedRule  = $dataType
	}
}
