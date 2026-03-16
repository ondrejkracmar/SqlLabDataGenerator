---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.16.2026
PlatyPS schema version: 2024-05-01
title: Import-SldgGenerationProfile
---

# Import-SldgGenerationProfile

## SYNOPSIS

Imports generation rules from a JSON profile file.

## SYNTAX

### __AllParameterSets

```
Import-SldgGenerationProfile [-Path] <string> [-Plan] <Object> [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Loads a previously exported or manually created JSON profile that defines
custom generation rules for specific tables and columns.
This allows
consistent, repeatable data generation across environments.

The JSON format is:
{
    "tables": {
        "dbo.Customer": {
            "rowCount": 200,
            "columns": {
                "Status": { "valueList": ["Active", "Inactive"] },
                "Currency": { "staticValue": "USD" },
                "Email": { "generator": "Email" }
            }
        }
    }
}

## EXAMPLES

### EXAMPLE 1

$plan = New-SldgGenerationPlan -Schema $schema
PS C:\> Import-SldgGenerationProfile -Path 'C:\profiles\retail.json' -Plan $plan

Applies the retail profile to the generation plan.

## PARAMETERS

### -Path

Path to the JSON profile file.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Plan

The generation plan to apply the profile to.

```yaml
Type: System.Object
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: true
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

- [Export-SldgGenerationProfile](Export-SldgGenerationProfile.md)
- [New-SldgGenerationPlan](New-SldgGenerationPlan.md)
- [Set-SldgGenerationRule](Set-SldgGenerationRule.md)