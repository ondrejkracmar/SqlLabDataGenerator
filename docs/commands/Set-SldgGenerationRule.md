---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.16.2026
PlatyPS schema version: 2024-05-01
title: Set-SldgGenerationRule
---

# Set-SldgGenerationRule

## SYNOPSIS

Sets custom generation rules for specific columns or tables.

## SYNTAX

### __AllParameterSets

```
Set-SldgGenerationRule [-Plan] <Object> [-TableName] <string> [-ColumnName] <string>
 [[-ValueList] <string[]>] [[-StaticValue] <Object>] [[-Generator] <string>]
 [[-GeneratorParams] <hashtable>] [[-ScriptBlock] <scriptblock>]
 [[-AIGenerationHint] <string>] [[-CrossColumnDependency] <string>]
 [[-ValueExamples] <string[]>] [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Overrides the default generation behavior for specific columns.
Supports:
- ValueList: pick from a predefined list of values
- StaticValue: always use the same value
- Generator: override the semantic type mapping
- ScriptBlock: custom generation logic
- AIGenerationHint: instructions for AI-powered structured data generation
- CrossColumnDependency: vary generated content based on another column's value
- ValueExamples: provide example values to guide AI generation

## EXAMPLES

### EXAMPLE 1

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Customer' -ColumnName 'Status' -ValueList @('Active', 'Inactive', 'Pending')

### EXAMPLE 2

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Order' -ColumnName 'Currency' -StaticValue 'USD'

### EXAMPLE 3

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Product' -ColumnName 'SKU' -ScriptBlock { "SKU-$(Get-Random -Minimum 10000 -Maximum 99999)" }

### EXAMPLE 4 — Context-Dependent JSON Generation

```powershell
# ReportType column has a ValueList rule; ReportData depends on it
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.UsageReport' `
    -ColumnName 'ReportType' -ValueList @(
        'UserActivity', 'MailboxUsage', 'OneDriveUsage',
        'TeamsDeviceUsage', 'SharePointSiteUsage'
    )

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.UsageReport' `
    -ColumnName 'ReportData' `
    -Generator 'Json' `
    -AIGenerationHint 'Generate Microsoft 365 usage report data. Structure varies by report type: UserActivity has sessions/actions, MailboxUsage has storage/itemCount, TeamsDeviceUsage has deviceType/usageMinutes.' `
    -CrossColumnDependency 'ReportType'
```

During generation, the `ReportData` column reads its dependency column `ReportType` from the
current row. If `ReportType = 'MailboxUsage'`, AI generates JSON with `storage`, `itemCount`,
`quotaUsed` fields. If `ReportType = 'TeamsDeviceUsage'`, AI generates `deviceType`,
`usageMinutes`, `lastActivity`. Cache keys include the context value, so each report type
gets its own set of 10 cached JSON documents.

### EXAMPLE 5 — AI Hint with Value Examples

```powershell
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Config' `
    -ColumnName 'SettingsJson' `
    -Generator 'Json' `
    -AIGenerationHint 'Application configuration with theme, language, and notification preferences' `
    -ValueExamples @(
        '{"theme":"dark","language":"cs","notifications":{"email":true,"push":false}}',
        '{"theme":"light","language":"en","notifications":{"email":false,"push":true}}'
    )
```

The `-ValueExamples` values are passed to AI to illustrate the expected document structure.
AI uses them as reference, not as a fixed list — it generates new variations in the same style.

## PARAMETERS

### -ColumnName

The column name to set the rule for.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Generator

Override the semantic type (e.g., 'Email', 'Phone', 'CompanyName').

```yaml
Type: System.String
DefaultValue: ''
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

### -GeneratorParams

Additional parameters for the generator.

```yaml
Type: System.Collections.Hashtable
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 6
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Plan

The generation plan to modify.

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

### -ScriptBlock

Custom scriptblock that generates a value.

```yaml
Type: System.Management.Automation.ScriptBlock
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 7
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -StaticValue

A fixed value to always use.

```yaml
Type: System.Object
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

### -TableName

The fully qualified table name (e.g., 'dbo.Customer').

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

### -ValueList

A list of values to randomly pick from.

```yaml
Type: System.String[]
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

### -AIGenerationHint

Instructions for AI-powered generation. Provides context about what kind of data
to generate — especially useful for JSON/XML columns where the structure should
vary based on business context.

```yaml
Type: System.String
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

### -CrossColumnDependency

Specifies another column name in the same table that this column depends on.
During generation, the value of the dependency column is passed to AI so it can
generate context-appropriate data. For example, a 'Report' JSON column might
depend on 'ReportId' to vary its structure by report type.

The dependency column must be generated **before** this column. The module automatically
reorders columns so that dependency columns are processed first.

```yaml
Type: System.String
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

### -ValueExamples

Example values that illustrate the expected format. Passed to AI to guide generation.
For JSON/XML columns, provide example documents showing the expected structure.

```yaml
Type: System.String[]
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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

The `-AIGenerationHint`, `-CrossColumnDependency`, and `-ValueExamples` parameters are stored
in the column's `CustomRule` hashtable. They are used by the AI structured-value generation
pipeline (`New-SldgStructuredData` → `New-SldgAIStructuredValue`) when the column's generator
is `Json` or `Xml`.

When `-CrossColumnDependency` is set, cache keys include the context value, so each unique
dependency value produces its own pool of 10 AI-generated documents.

## RELATED LINKS

- [New-SldgGenerationPlan](New-SldgGenerationPlan.md)
- [Invoke-SldgDataGeneration](Invoke-SldgDataGeneration.md)
- [Import-SldgGenerationProfile](Import-SldgGenerationProfile.md)