function Get-SldgAIColumnAnalysis {
	<#
	.SYNOPSIS
		Uses an AI provider for deep semantic analysis of database columns.
	.DESCRIPTION
		Sends full schema context (tables, columns, types, FKs, constraints) to AI
		for intelligent classification. AI recognizes column purposes from names,
		relationships, data types, and domain context — including non-English names
		like DisplayName, Jmeno, Prijmeni, Telefon, Oddeleni, etc.

		Returns enriched classifications with AI-generated value examples and
		specific generation instructions per column.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$SchemaModel,

		[string]$IndustryHint,

		[string]$Locale
	)

	$aiProvider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
	if ($aiProvider -eq 'None') {
		Write-PSFMessage -Level Verbose -Message $script:strings.'Semantic.AINotConfigured'
		return $null
	}

	if (-not $Locale) {
		$Locale = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.Locale'
	}

	# Build rich schema description with full context
	$schemaSummary = foreach ($table in $SchemaModel.Tables) {
		$colLines = foreach ($col in $table.Columns) {
			$fk = if ($col.ForeignKey) { " -> $($col.ForeignKey.ReferencedTable).$($col.ForeignKey.ReferencedColumn)" } else { "" }
			$flags = @()
			if ($col.IsPrimaryKey) { $flags += 'PK' }
			if ($col.IsIdentity) { $flags += 'IDENTITY' }
			if ($col.IsNullable) { $flags += 'NULL' }
			if ($col.IsUnique) { $flags += 'UNIQUE' }
			$flagStr = if ($flags) { " [$($flags -join ',')]" } else { "" }
			$lenStr = if ($col.MaxLength -and $col.MaxLength -gt 0) { "($($col.MaxLength))" } else { "" }
			$checkStr = if ($col.CheckConstraint) { " CHECK($($col.CheckConstraint))" } else { "" }
			"  - $($col.ColumnName) $($col.DataType)$lenStr$flagStr$fk$checkStr"
		}
		$fkSummary = foreach ($fk in $table.ForeignKeys) {
			"  FK: $($fk.ColumnName) -> $($fk.ReferencedTable).$($fk.ReferencedColumn)"
		}
		$fkText = if ($fkSummary) { "`n$($fkSummary -join "`n")" } else { "" }
		"TABLE: $($table.FullName) ($($table.ColumnCount) columns)`n$($colLines -join "`n")$fkText"
	}
	$schemaText = $schemaSummary -join "`n`n"

	$systemPrompt = @"
You are an expert database analyst and test data architect. Analyze the database schema below and provide deep semantic understanding of every column.

Your goal: understand what each column represents in the real world — from the column name, data type, table context, foreign keys, and naming conventions. Column names may be in ANY language (English, Czech, German, etc.) or use abbreviations.

For each column, determine:
1. SemanticType: What real-world concept it represents
2. IsPII: Whether it contains personally identifiable information
3. GenerationHint: Specific instructions for generating realistic test data
4. ValueExamples: 3-5 example values that would be appropriate
5. ValuePattern: Format pattern if applicable (regex or description)
6. CrossColumnDependency: Other columns this value should be consistent with

Locale for generated data: $Locale

Return ONLY a JSON array. Each object must have:
{
  "TableName": "schema.table",
  "ColumnName": "column",
  "SemanticType": "one of the types listed below",
  "IsPII": true/false,
  "GenerationHint": "specific instruction for realistic data generation",
  "ValueExamples": ["example1", "example2", "example3"],
  "ValuePattern": "format description or regex",
  "CrossColumnDependency": "e.g. Email should use FirstName+LastName" or null
}

Valid SemanticTypes: FirstName, LastName, FullName, MiddleName, Email, Phone, Street, City, State, ZipCode, Country, SSN, NationalId, TaxId, IBAN, CreditCard, BankAccount, Money, Currency, BirthDate, PastDate, FutureDate, Timestamp, BusinessNumber, CompanyName, Department, JobTitle, Url, IpAddress, Username, Password, Text, Status, Category, Gender, Age, Boolean, Quantity, Percentage, Integer, Decimal, Guid, Code

IMPORTANT recognition rules:
- "DisplayName" or "display_name" = FullName (combine first + last)
- "Name" in a Person/User/Employee table = FullName
- "Name" in a Company/Organization table = CompanyName
- "Name" in a Product/Category table = Text (product/category name)
- Recognize Czech: Jmeno=FirstName, Prijmeni=LastName, Telefon=Phone, Email=Email, Adresa=Street, Mesto=City, PSC=ZipCode, Oddeleni=Department, Pozice=JobTitle, RodneCislo=NationalId
- Recognize German: Vorname=FirstName, Nachname=LastName, Strasse=Street, Ort=City, PLZ=ZipCode, Abteilung=Department
- Recognize column context: if table is "Orders" and column is "Total", it's Money, not Integer
- Detect cross-column dependencies: Email should match FirstName+LastName pattern
- For Status columns: suggest realistic status values based on the table context
"@

	if ($IndustryHint) {
		$systemPrompt += "`n`nThe database is from the $IndustryHint industry. Use industry-specific terminology, common patterns, realistic value ranges, and domain knowledge for generation hints."
	}

	$userMessage = "Analyze this database schema and provide detailed semantic classification for every column:`n`n$schemaText"

	$response = Invoke-SldgAIRequest -SystemPrompt $systemPrompt -UserMessage $userMessage

	if (-not $response) { return $null }

	try {
		$jsonContent = $response
		if ($jsonContent -match '```(?:json)?\s*([\s\S]*?)\s*```') {
			$jsonContent = $Matches[1]
		}
		elseif ($jsonContent -match '(\[[\s\S]*\])') {
			$jsonContent = $Matches[1]
		}

		$parsed = $jsonContent | ConvertFrom-Json

		foreach ($item in $parsed) {
			[PSCustomObject]@{
				PSTypeName            = 'SqlLabDataGenerator.ColumnClassification'
				ColumnName            = $item.ColumnName
				TableName             = $item.TableName
				SemanticType          = $item.SemanticType
				IsPII                 = [bool]$item.IsPII
				Confidence            = 0.95
				Source                = 'AI'
				MatchedRule           = $item.GenerationHint
				ValueExamples         = @(if ($item.ValueExamples) { $item.ValueExamples } else { @() })
				ValuePattern          = if ($item.ValuePattern) { [string]$item.ValuePattern } else { $null }
				CrossColumnDependency = if ($item.CrossColumnDependency) { [string]$item.CrossColumnDependency } else { $null }
			}
		}
	}
	catch {
		Write-PSFMessage -Level Warning -Message ($script:strings.'AI.ParseFailed' -f $_)
		$null
	}
}
