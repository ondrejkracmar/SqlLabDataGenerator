---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.16.2026
PlatyPS schema version: 2024-05-01
title: Get-SldgDatabaseSchema
---

# Get-SldgDatabaseSchema

## SYNOPSIS

Discovers and returns the complete schema of the connected database.

## SYNTAX

### __AllParameterSets

```
Get-SldgDatabaseSchema [[-SchemaFilter] <string[]>] [[-TableFilter] <string[]>]
 [[-ConnectionInfo] <Object>] [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Reads tables, columns, data types, primary keys, foreign keys, unique constraints,
and check constraints from the connected database.
Returns a structured SchemaModel
object that serves as the foundation for data generation.

## EXAMPLES

### EXAMPLE 1

$schema = Get-SldgDatabaseSchema

Discovers all tables in the connected database.

### EXAMPLE 2

$schema = Get-SldgDatabaseSchema -SchemaFilter 'dbo', 'Sales' -TableFilter 'Customer', 'Order'

Discovers only specific tables.

## PARAMETERS

### -ConnectionInfo

Explicit connection to use.
If not specified, uses the active connection from Connect-SldgDatabase.

```yaml
Type: System.Object
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

### -SchemaFilter

Optional list of schema names to include (e.g., 'dbo', 'Sales').
If not specified, all schemas are included.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -TableFilter

Optional list of table names to include.
If not specified, all tables are included.

```yaml
Type: System.String[]
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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

- [Connect-SldgDatabase](Connect-SldgDatabase.md)
- [Get-SldgColumnAnalysis](Get-SldgColumnAnalysis.md)
- [New-SldgGenerationPlan](New-SldgGenerationPlan.md)