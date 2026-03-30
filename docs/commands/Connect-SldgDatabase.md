---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.16.2026
PlatyPS schema version: 2024-05-01
title: Connect-SldgDatabase
---

# Connect-SldgDatabase

## SYNOPSIS

Connects to a database for schema discovery and data generation.

## SYNTAX

### __AllParameterSets

```
Connect-SldgDatabase [-ServerInstance] <string> [-Database] <string> [[-Provider] <string>]
 [[-Credential] <pscredential>] [[-ConnectionTimeout] <int>] [-TrustServerCertificate]
 [<CommonParameters>]
```

## DESCRIPTION

Establishes a connection to a database using the specified provider.
The connection is stored as the active connection for subsequent commands.
Currently supports SQL Server via the built-in SqlServer provider.

## EXAMPLES

### EXAMPLE 1

Connect-SldgDatabase -ServerInstance 'localhost' -Database 'AdventureWorks'

Connects to AdventureWorks on localhost using Windows authentication.

### EXAMPLE 2

$cred = Get-Credential
PS C:\> Connect-SldgDatabase -ServerInstance 'dbserver\SQLEXPRESS' -Database 'TestDB' -Credential $cred

Connects using SQL authentication.

## PARAMETERS

### -ConnectionTimeout

Connection timeout in seconds.
Default is 30.

```yaml
Type: System.Int32
DefaultValue: 30
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

### -Credential

SQL authentication credentials.
If not specified, Windows/Integrated authentication is used.

```yaml
Type: System.Management.Automation.PSCredential
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

### -Database

The database name to connect to.

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

### -Provider

The database provider to use.
Default is 'SqlServer'.

```yaml
Type: System.String
DefaultValue: SqlServer
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

### -ServerInstance

The server instance to connect to (e.g., 'localhost', 'server\instance', 'server,port').

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

### -TrustServerCertificate

Whether to trust the server certificate without validation.

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

- [Disconnect-SldgDatabase](Disconnect-SldgDatabase.md)
- [Get-SldgDatabaseSchema](Get-SldgDatabaseSchema.md)