---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: en-US
Module Name: SqlLabDataGenerator
ms.date: 09/12/2026
PlatyPS schema version: 2024-05-01
title: New-SldgGenerationPlan
---

# New-SldgGenerationPlan

## SYNOPSIS

Creates a data generation plan from an analyzed schema.

## SYNTAX

### __AllParameterSets

```
New-SldgGenerationPlan [-Schema] <SchemaModel> [[-RowCount] <int>] [[-TableRowCounts] <hashtable>]
 [[-Mode] <string>] [[-IndustryHint] <string>] [[-ScenarioName] <string>] [-UseAI]
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

$plan = New-SldgGenerationPlan -Schema $analyzed -Mode Scenario -ScenarioName eCommerce -RowCount 100

Generates a Scenario plan: lookup tables get ~5 rows, customers 100, orders 300, order items 800.

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

### -ScenarioName

Scenario template name for Scenario mode.
Built-in: eCommerce, Healthcare, HR,
Finance, Education.
Use 'Auto' (default) to let the module detect the best match
from table names in the schema.

```yaml
Type: System.String
DefaultValue: Auto
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 5
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
Type: SqlLabDataGenerator.SchemaModel
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

### SqlLabDataGenerator.SchemaModel

{{ Fill in the Description }}

## OUTPUTS

### SqlLabDataGenerator.GenerationPlan

{{ Fill in the Description }}

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

