---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.16.2026
PlatyPS schema version: 2024-05-01
title: Get-SldgTransformer
---

# Get-SldgTransformer

## SYNOPSIS

Lists available data transformers.

## SYNTAX

### __AllParameterSets

```
Get-SldgTransformer [[-Name] <string>] [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Returns information about registered data transformers that can be used
with Export-SldgTransformedData to convert generated data into different
target formats (e.g., Entra ID users, Entra ID groups).

## EXAMPLES

### EXAMPLE 1

Get-SldgTransformer

Lists all available transformers.

### EXAMPLE 2

Get-SldgTransformer -Name 'EntraId*'

Lists Entra ID-related transformers.

## PARAMETERS

### -Name

Optional name filter.
Supports wildcards.

```yaml
Type: System.String
DefaultValue: '*'
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

- [Register-SldgTransformer](Register-SldgTransformer.md)
- [Export-SldgTransformedData](Export-SldgTransformedData.md)