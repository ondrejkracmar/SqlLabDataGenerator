---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: en-US
Module Name: SqlLabDataGenerator
ms.date: 09/13/2026
PlatyPS schema version: 2024-05-01
title: Set-SldgGenerationRule
---

# Set-SldgGenerationRule

## SYNOPSIS

Sets custom generation rules for specific columns or tables.

## SYNTAX

### __AllParameterSets

```
Set-SldgGenerationRule [-Plan] <GenerationPlan> [-TableName] <string> [-ColumnName] <string>
 [[-ValueList] <string[]>] [[-StaticValue] <Object>] [[-Generator] <string>]
 [[-GeneratorParams] <hashtable>] [[-ScriptBlock] <scriptblock>] [[-AIGenerationHint] <string>]
 [[-CrossColumnDependency] <string>] [[-ValueExamples] <string[]>] [-WhatIf] [-Confirm]
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

## EXAMPLES

### EXAMPLE 1

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Customer' -ColumnName 'Status' -ValueList @('Active', 'Inactive', 'Pending')

Sets the Status column to randomly pick from a predefined list.

### EXAMPLE 2

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Order' -ColumnName 'Currency' -StaticValue 'USD'

Sets the Currency column to always use 'USD'.

### EXAMPLE 3

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Product' -ColumnName 'SKU' -ScriptBlock { "SKU-$(Get-Random -Minimum 10000 -Maximum 99999)" }

Sets the SKU column to use a custom scriptblock for value generation.

### EXAMPLE 4

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.UsageReport' -ColumnName 'ReportData' `
    -Generator 'Json' `
    -AIGenerationHint 'Generate Microsoft 365 usage report data. Structure varies by report type: UserActivity has sessions/actions, MailboxUsage has storage/itemCount, TeamsDeviceUsage has deviceType/usageMinutes.' `
    -CrossColumnDependency 'ReportType'

Sets the ReportData JSON column to use AI generation, varying the JSON structure
based on the ReportType column value in each row.

## PARAMETERS

### -AIGenerationHint

Instructions for AI-powered generation.
Provides context about what kind of data
to generate — especially useful for JSON/XML columns where the structure should
vary based on business context.
Example: 'Generate M365 usage report data.
Vary JSON structure by report type:
UserActivity, MailboxUsage, OneDriveUsage, TeamsDeviceUsage, SharePointSiteUsage.'

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 8
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

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

### -CrossColumnDependency

Specifies another column name in the same table that this column depends on.
During generation, the value of the dependency column is passed to AI so it can
generate context-appropriate data.
For example, a 'Report' JSON column might
depend on 'ReportId' to vary its structure by report type.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 9
  IsRequired: false
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
Type: SqlLabDataGenerator.GenerationPlan
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

### -ValueExamples

Example values that illustrate the expected format.
Passed to AI to guide generation.
For JSON/XML columns, provide example documents showing the expected structure.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 10
  IsRequired: false
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

### -WhatIf

Runs the command in a mode that only reports what would happen without performing the actions.

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

### System.Void

{{ Fill in the Description }}

## NOTES

SECURITY WARNING: The -ScriptBlock parameter executes arbitrary PowerShell code
during data generation.
Only use ScriptBlocks from trusted sources.
ScriptBlocks
are intentionally NOT supported in JSON profiles (Import-SldgGenerationProfile)
to prevent code injection from untrusted files.


## RELATED LINKS

{{ Fill in the related links here }}

