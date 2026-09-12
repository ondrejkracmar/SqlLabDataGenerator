---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: en-US
Module Name: SqlLabDataGenerator
ms.date: 09/12/2026
PlatyPS schema version: 2024-05-01
title: Invoke-SldgDataGeneration
---

# Invoke-SldgDataGeneration

## SYNOPSIS

Executes data generation according to a generation plan.

## SYNTAX

### __AllParameterSets

```
Invoke-SldgDataGeneration [-Plan] <GenerationPlan> [[-ConnectionInfo] <Connection>]
 [[-ThrottleLimit] <int>] [-NoInsert] [-PassThru] [-UseTransaction] [-Parallel]
 [-ValidateAfterGeneration] [-FailOnValidationError] [-FailOnSkippedRows] [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Generates synthetic data for all tables in the plan, respecting FK dependencies,
unique constraints, and custom rules.
Data is generated in topological order
so that parent tables are populated before child tables.

Within each row, columns with -CrossColumnDependency rules (set via Set-SldgGenerationRule)
are automatically reordered so that dependency columns are generated first.
This enables
context-dependent AI generation — e.g., a JSON column can vary its structure based on
the value of a report-type column in the same row.

## EXAMPLES

### EXAMPLE 1

$result = Invoke-SldgDataGeneration -Plan $plan

Generates and inserts data for all tables in the plan.

### EXAMPLE 2

$result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -PassThru

Generates data in memory without inserting.

### EXAMPLE 3

$result = Invoke-SldgDataGeneration -Plan $plan -UseTransaction

Generates and inserts data within a single transaction.
If any table fails,
all previously inserted data is rolled back.

### EXAMPLE 4

$result = Invoke-SldgDataGeneration -Plan $plan -Parallel -ThrottleLimit 4

Independent tables are generated in parallel, up to 4 at a time.

## PARAMETERS

### -Confirm

Prompts for confirmation before inserting data into each table.

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
Type: SqlLabDataGenerator.Connection
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

Turns any skipped/ignored inserted rows into a terminating error.
This is useful for strict data quality gates.

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

Turns validation errors from -ValidateAfterGeneration into a terminating error.

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

### -Parallel

Generates independent tables in parallel (Synthetic and Scenario modes; masking stays sequential).

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

### -Plan

The generation plan from New-SldgGenerationPlan.

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

### -ThrottleLimit

Maximum number of tables to generate in parallel when using -Parallel.

```yaml
Type: System.Int32
DefaultValue: 0
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

### -UseTransaction

Wraps all inserts in a single database transaction.
If any table fails,
all previously inserted data is rolled back.

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

Runs Test-SldgGeneratedData after inserts complete and attaches the validation results to the generation result.

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

### SqlLabDataGenerator.GenerationPlan

{{ Fill in the Description }}

## OUTPUTS

### SqlLabDataGenerator.GenerationResult

{{ Fill in the Description }}

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

