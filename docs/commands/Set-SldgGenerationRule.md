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
 [[-GeneratorParams] <hashtable>] [[-ScriptBlock] <scriptblock>] [<CommonParameters>]
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

### EXAMPLE 2

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Order' -ColumnName 'Currency' -StaticValue 'USD'

### EXAMPLE 3

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Product' -ColumnName 'SKU' -ScriptBlock { "SKU-$(Get-Random -Minimum 10000 -Maximum 99999)" }

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

- [New-SldgGenerationPlan](New-SldgGenerationPlan.md)
- [Invoke-SldgDataGeneration](Invoke-SldgDataGeneration.md)
- [Import-SldgGenerationProfile](Import-SldgGenerationProfile.md)