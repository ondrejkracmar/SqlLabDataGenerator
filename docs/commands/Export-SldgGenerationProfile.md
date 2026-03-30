---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.16.2026
PlatyPS schema version: 2024-05-01
title: Export-SldgGenerationProfile
---

# Export-SldgGenerationProfile

## SYNOPSIS

Exports the current generation plan and rules to a JSON profile file.

## SYNTAX

### __AllParameterSets

```
Export-SldgGenerationProfile [-Plan] <Object> [-Path] <string> [-IncludeSemanticAnalysis]
 [<CommonParameters>]
```

## DESCRIPTION

Saves the generation plan configuration including table row counts,
column semantic types, PII flags, and custom rules to a JSON file.
This profile can be imported later for consistent data generation.

Custom rules including `-AIGenerationHint`, `-CrossColumnDependency`, and `-ValueExamples`
are preserved in the exported profile. ScriptBlock rules are excluded from export for security.

## EXAMPLES

### EXAMPLE 1

Export-SldgGenerationProfile -Plan $plan -Path 'C:\profiles\mydb.json'

Exports the plan to a JSON file.

## PARAMETERS

### -IncludeSemanticAnalysis

If specified, includes the full semantic analysis (types, PII flags) in the export.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Path

The file path to save the JSON profile.

```yaml
Type: System.String
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

### -Plan

The generation plan to export.

```yaml
Type: System.Object
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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

- [Import-SldgGenerationProfile](Import-SldgGenerationProfile.md)
- [New-SldgGenerationPlan](New-SldgGenerationPlan.md)