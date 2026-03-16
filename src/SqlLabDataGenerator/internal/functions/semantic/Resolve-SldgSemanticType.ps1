function Resolve-SldgSemanticType {
	<#
	.SYNOPSIS
		Maps a SQL data type to a semantic type and generator for fallback classification.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$DataType,

		$MaxLength,

		[bool]$IsNullable
	)

	$mapping = switch -Regex ($DataType.ToLower()) {
		'^(int|bigint|smallint|tinyint)$' { @{ Type = 'Integer'; Generator = 'Number' } }
		'^(decimal|numeric|float|real|money|smallmoney)$' { @{ Type = 'Decimal'; Generator = 'Number' } }
		'^(bit)$' { @{ Type = 'Boolean'; Generator = 'Boolean' } }
		'^(date)$' { @{ Type = 'Date'; Generator = 'Date' } }
		'^(datetime|datetime2|smalldatetime|datetimeoffset)$' { @{ Type = 'DateTime'; Generator = 'Date' } }
		'^(time)$' { @{ Type = 'Time'; Generator = 'Date' } }
		'^(char|nchar)$' {
			if ($MaxLength -and $MaxLength -le 10) { @{ Type = 'Code'; Generator = 'Identifier' } }
			else { @{ Type = 'FixedString'; Generator = 'Text' } }
		}
		'^(varchar|nvarchar)$' {
			if ($MaxLength -and $MaxLength -le 20) { @{ Type = 'ShortString'; Generator = 'Identifier' } }
			elseif ($MaxLength -and $MaxLength -le 100) { @{ Type = 'MediumString'; Generator = 'Text' } }
			elseif ($MaxLength -and $MaxLength -le 500) { @{ Type = 'LongString'; Generator = 'Text' } }
			else { @{ Type = 'LongString'; Generator = 'Text' } }
		}
		'^(text|ntext)$' { @{ Type = 'LongString'; Generator = 'Text' } }
		'^(uniqueidentifier)$' { @{ Type = 'Guid'; Generator = 'Identifier' } }
		'^(binary|varbinary|image)$' { @{ Type = 'Binary'; Generator = 'Skip' } }
		'^(xml)$' { @{ Type = 'Xml'; Generator = 'Skip' } }
		'^(geography|geometry|hierarchyid)$' { @{ Type = 'Spatial'; Generator = 'Skip' } }
		'^(sql_variant)$' { @{ Type = 'Variant'; Generator = 'Text' } }
		'^(timestamp|rowversion)$' { @{ Type = 'RowVersion'; Generator = 'Skip' } }
		default { @{ Type = 'Unknown'; Generator = 'Text' } }
	}

	[PSCustomObject]@{
		Type      = $mapping.Type
		Generator = $mapping.Generator
	}
}
