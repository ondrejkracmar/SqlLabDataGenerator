---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: en-US
Module Name: SqlLabDataGenerator
ms.date: 09/12/2026
PlatyPS schema version: 2024-05-01
title: Export-SldgGenerationProfile
---

# Export-SldgGenerationProfile

## SYNOPSIS

Exports the current generation plan and rules to a JSON profile file.

## SYNTAX

### __AllParameterSets

```
Export-SldgGenerationProfile [-Plan] <GenerationPlan> [-Path] <string> [-IncludeSemanticAnalysis]
 [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Saves the generation plan configuration including table row counts,
column semantic types, PII flags, and custom rules to a JSON file.
This profile can be imported later for consistent data generation.

Custom rules including AIGenerationHint, CrossColumnDependency, and ValueExamples
are preserved in the exported profile.
ScriptBlock rules are excluded for security.

## EXAMPLES

### EXAMPLE 1

Export-SldgGenerationProfile -Plan $plan -Path 'C:\profiles\mydb.json'

Exports the plan to a JSON file.

## PARAMETERS

### -Confirm

Prompts for confirmation before exporting the profile.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- cf
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
Type: SqlLabDataGenerator.GenerationPlan
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -WhatIf

Shows what the command would do without actually exporting the profile.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- wi
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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### SqlLabDataGenerator.GenerationPlan

{{ Fill in the Description }}

## OUTPUTS

### System.Void

{{ Fill in the Description }}

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

