---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.16.2026
PlatyPS schema version: 2024-05-01
title: Get-SldgColumnAnalysis
---

# Get-SldgColumnAnalysis

## SYNOPSIS

Performs semantic analysis on database columns.

## SYNTAX

### __AllParameterSets

```
Get-SldgColumnAnalysis [-Schema] <Object> [[-IndustryHint] <string>] [[-Locale] <string>] [-UseAI]
 [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Classifies each column in the schema using pattern matching and optionally AI analysis.
Returns the schema model enriched with semantic types, PII flags, and recommended
generation strategies.

When AI is enabled, the analysis is significantly richer — AI understands column
names in any language (Czech, German, etc.), recognizes business context from
table/column relationships, and provides specific generation instructions with
example values and cross-column dependencies.

## EXAMPLES

### EXAMPLE 1

$schema = Get-SldgDatabaseSchema
PS C:\> $analyzed = Get-SldgColumnAnalysis -Schema $schema

Analyzes columns using pattern matching.

### EXAMPLE 2

$analyzed = Get-SldgColumnAnalysis -Schema $schema -UseAI -IndustryHint 'Healthcare'

Uses AI for deeper healthcare-specific analysis.

### EXAMPLE 3

$analyzed = Get-SldgColumnAnalysis -Schema $schema -UseAI -Locale 'cs-CZ'

AI generates Czech-specific value examples and recognizes Czech column names.

## PARAMETERS

### -IndustryHint

Optional hint about the industry domain (e.g., 'Healthcare', 'Finance', 'Retail').
Improves AI classification accuracy with domain-specific context.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Locale

Target locale for AI-generated value examples (e.g., 'cs-CZ', 'de-DE').

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Schema

The schema model from Get-SldgDatabaseSchema.

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

### -UseAI

If specified, uses the configured AI provider for deeper semantic analysis.
AI recognizes columns like DisplayName, Jmeno, Prijmeni, Telefon, etc.
Requires AI.Provider to be configured (+ AI.ApiKey for OpenAI/AzureOpenAI).

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

- [Get-SldgDatabaseSchema](Get-SldgDatabaseSchema.md)
- [New-SldgGenerationPlan](New-SldgGenerationPlan.md)
- [Set-SldgAIProvider](Set-SldgAIProvider.md)