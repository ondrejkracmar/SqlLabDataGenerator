---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.16.2026
PlatyPS schema version: 2024-05-01
title: New-SldgGenerationPlan
---

# New-SldgGenerationPlan

## SYNOPSIS

Creates a data generation plan from an analyzed schema.

## SYNTAX

### __AllParameterSets

```
New-SldgGenerationPlan [-Schema] <Object> [[-RowCount] <int>] [[-TableRowCounts] <hashtable>]
 [[-Mode] <string>] [[-IndustryHint] <string>] [-UseAI] [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Builds an ordered execution plan for data generation.
Resolves table dependencies
via foreign keys (topological sort), assigns row counts, and maps each column
to its generator.
The plan can be reviewed and modified before execution.

When -UseAI is specified, AI analyzes the schema to suggest:
- Optimal row counts per table (lookup tables vs transaction tables)
- Custom generation rules for domain-specific columns
- Cross-table consistency requirements

When a `schema-analysis` purpose provider is configured (via `Set-SldgAIProvider -Purpose 'schema-analysis'`),
the command also performs deep schema analysis — querying sample data from each table and sending
the full schema model + samples to a powerful AI model. The resulting per-table generation notes
are stored in the plan (`$plan.AIAdvice.TableGenerationNotes`) and automatically passed to the
batch-generation model during `Invoke-SldgDataGeneration`, guiding data generation with expert-level
analysis of table purposes, relationships, and realistic value patterns.

## EXAMPLES

### EXAMPLE 1

$plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 200

Creates a plan to generate 200 rows per table.

### EXAMPLE 2

$plan = New-SldgGenerationPlan -Schema $analyzed -UseAI -RowCount 100

AI suggests table-specific row counts (scaled from base 100) and custom rules.

### EXAMPLE 3

$plan = New-SldgGenerationPlan -Schema $analyzed -UseAI -IndustryHint 'eCommerce'

AI uses eCommerce domain knowledge for realistic data patterns.

### EXAMPLE 4

Set-SldgAIProvider -Provider OpenAI -Model 'gpt-4o' -ApiKey $key -Purpose 'schema-analysis'
PS C:\> Set-SldgAIProvider -Provider Ollama -Model 'llama3' -EnableAIGeneration
PS C:\> $plan = New-SldgGenerationPlan -Schema $analyzed -UseAI -RowCount 200

Two-tier AI: GPT-4o analyzes schema + sample data, produces per-table generation notes.
The local Ollama model then uses those notes during Invoke-SldgDataGeneration.

## PARAMETERS

### -IndustryHint

Industry context for AI plan suggestions (e.g., 'Healthcare', 'eCommerce').

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 4
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Mode

Generation mode: Synthetic (new data), Masking (anonymize existing), Scenario (domain template).

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 3
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -RowCount

Default number of rows to generate per table.
Default: value from Generation.DefaultRowCount config.

```yaml
Type: System.Int32
DefaultValue: 0
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

### -Schema

The analyzed schema model (output of Get-SldgColumnAnalysis or Get-SldgDatabaseSchema).

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

### -TableRowCounts

Hashtable of table-specific row counts: @{ 'dbo.Customer' = 500; 'dbo.Order' = 2000 }.

```yaml
Type: System.Collections.Hashtable
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

### -UseAI

Let AI analyze the schema and suggest optimal row counts and generation rules.
AI-suggested row counts are used unless overridden by -TableRowCounts.
AI-suggested custom rules are applied unless columns already have rules.

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
- [Get-SldgColumnAnalysis](Get-SldgColumnAnalysis.md)
- [Invoke-SldgDataGeneration](Invoke-SldgDataGeneration.md)
- [Set-SldgGenerationRule](Set-SldgGenerationRule.md)