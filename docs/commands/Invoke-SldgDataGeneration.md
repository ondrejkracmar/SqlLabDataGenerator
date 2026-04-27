---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.16.2026
PlatyPS schema version: 2024-05-01
title: Invoke-SldgDataGeneration
---

# Invoke-SldgDataGeneration

## SYNOPSIS

Executes data generation according to a generation plan.

## SYNTAX

### __AllParameterSets

```
Invoke-SldgDataGeneration [-Plan] <Object> [[-ConnectionInfo] <Object>] [-NoInsert] [-PassThru]
 [-UseTransaction] [-Parallel] [[-ThrottleLimit] <Int32>] [-ValidateAfterGeneration]
 [-FailOnValidationError] [-FailOnSkippedRows] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION

Generates synthetic data for all tables in the plan, respecting FK dependencies,
unique constraints, and custom rules.
Data is generated in topological order
so that parent tables are populated before child tables.

The result includes a `QualityReport` property with requested, inserted, skipped, failed,
FK fallback, and validation counts. Use `-ValidateAfterGeneration` to run database integrity
checks immediately after insertion and attach `ValidationResults` to the generation result.

## EXAMPLES

### EXAMPLE 1

$result = Invoke-SldgDataGeneration -Plan $plan

Generates and inserts data for all tables in the plan.

### EXAMPLE 2

$result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -PassThru

Generates data in memory without inserting.

### EXAMPLE 3

$result = Invoke-SldgDataGeneration -Plan $plan -ValidateAfterGeneration -FailOnValidationError -FailOnSkippedRows

Generates and inserts data, validates FK/unique/data type constraints after generation, and fails
the run if validation errors or skipped inserted rows are detected.

## PARAMETERS

### -Confirm

Prompts you for confirmation before running the cmdlet.

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

### -ConnectionInfo

Target database connection.
If not specified, uses the active connection.

```yaml
Type: System.Object
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

### -FailOnSkippedRows

Fails the generation run when a provider inserts fewer rows than requested for any table.
This catches silent provider behaviors such as ignored constraint violations.

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

### -FailOnValidationError

Fails the generation run when `-ValidateAfterGeneration` finds validation errors.

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

### -NoInsert

Generates data in memory but does not write to the database.
Use this with -PassThru to get the generated DataTables.

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

### -PassThru

Returns the generated data as part of the result object.

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

### -Parallel

Generates independent tables in parallel when supported by the current PowerShell runtime.

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

### -Plan

The generation plan from New-SldgGenerationPlan.

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

### -ThrottleLimit

Maximum number of tables generated concurrently when `-Parallel` is used.

```yaml
Type: System.Int32
DefaultValue: ''
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

### -UseTransaction

Wraps inserts in a single transaction where supported. If generation fails before commit, inserted
data is rolled back.

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

### -ValidateAfterGeneration

Runs `Test-SldgGeneratedData` after inserted generation completes. The validation output is attached
to the returned result as `ValidationResults`, and aggregate counts are included in `QualityReport`.

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

### -WhatIf

Shows what would be generated without actually inserting data.

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

## OUTPUTS

## NOTES

When columns have `-CrossColumnDependency` rules (set via `Set-SldgGenerationRule`), the engine
automatically reorders column generation within each row so that dependency columns are generated
first. The dependency column's value is then passed to AI as context for generating the dependent
column (e.g., a JSON column that varies its structure based on a report type column).

When the plan contains per-table generation notes from schema analysis
(`$plan.AIAdvice.TableGenerationNotes` — populated by `New-SldgGenerationPlan -UseAI` when a
`schema-analysis` purpose provider is configured), the notes are automatically injected into the
batch-generation AI system prompt for each table. This guides the data generation model with
expert-level analysis of table purposes, relationships, and realistic value patterns — enabling
higher-quality data especially when using a fast local model (Ollama) for generation.

## RELATED LINKS

- [New-SldgGenerationPlan](New-SldgGenerationPlan.md)
- [Test-SldgGeneratedData](Test-SldgGeneratedData.md)
- [Connect-SldgDatabase](Connect-SldgDatabase.md)
- [Export-SldgTransformedData](Export-SldgTransformedData.md)