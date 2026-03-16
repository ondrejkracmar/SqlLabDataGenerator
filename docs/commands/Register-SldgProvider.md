---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.16.2026
PlatyPS schema version: 2024-05-01
title: Register-SldgProvider
---

# Register-SldgProvider

## SYNOPSIS

Registers a custom database provider for data generation.

## SYNTAX

### __AllParameterSets

```
Register-SldgProvider [-Name] <string> [-ConnectFunction] <string> [-GetSchemaFunction] <string>
 [-WriteDataFunction] <string> [-ReadDataFunction] <string> [-DisconnectFunction] <string>
 [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Registers a new database provider that implements the required interface
for schema discovery and data operations.
This enables support for
databases beyond the built-in SQL Server provider.

Each provider must supply functions for: Connect, GetSchema, WriteData, ReadData, Disconnect.

## EXAMPLES

### EXAMPLE 1

Register-SldgProvider -Name 'PostgreSQL' `
>>     -ConnectFunction 'Connect-PostgreSql' `
>>     -GetSchemaFunction 'Get-PostgreSqlSchema' `
>>     -WriteDataFunction 'Write-PostgreSqlData' `
>>     -ReadDataFunction 'Read-PostgreSqlData' `
>>     -DisconnectFunction 'Disconnect-PostgreSql'

## PARAMETERS

### -ConnectFunction

Name of the function that establishes a database connection.

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

### -DisconnectFunction

Name of the function that closes the database connection.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 5
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -GetSchemaFunction

Name of the function that reads the database schema.

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

### -Name

Unique name for the provider (e.g., 'PostgreSQL', 'Oracle', 'MySQL').

```yaml
Type: System.String
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

### -ReadDataFunction

Name of the function that reads existing data from a table.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 4
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -WriteDataFunction

Name of the function that writes generated data to a table.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 3
  IsRequired: true
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
- [Disconnect-SldgDatabase](Disconnect-SldgDatabase.md)