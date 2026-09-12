---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: en-US
Module Name: SqlLabDataGenerator
ms.date: 09/12/2026
PlatyPS schema version: 2024-05-01
title: Connect-SldgDatabase
---

# Connect-SldgDatabase

## SYNOPSIS

Connects to a database for schema discovery and data generation.

## SYNTAX

### File (Default)

```
Connect-SldgDatabase -Database <string> -Provider <string> [-Credential <pscredential>]
 [-TrustServerCertificate] [-ConnectionTimeout <int>] [-CreateIfNotExists]
 [-ProviderParameter <hashtable>]
```

### Server

```
Connect-SldgDatabase -ServerInstance <string> -Database <string> [-Provider <string>]
 [-Credential <pscredential>] [-TrustServerCertificate] [-ConnectionTimeout <int>]
 [-ProviderParameter <hashtable>]
```

### ConnectionString

```
Connect-SldgDatabase -ConnectionString <string> [-Provider <string>] [-Credential <pscredential>]
 [-TrustServerCertificate] [-ConnectionTimeout <int>] [-ProviderParameter <hashtable>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Opens a connection through PSSqlRepository and stores it as the active connection
for the other Sldg commands.
Any provider PSSqlRepository knows can be used:
SqlServer and Sqlite ship with it, DuckDB and further engines come as
PSSqlRepository extensions (Install-PSSqlRepositoryExtension).
Run
Get-PSSqlRepositoryProvider to see what is available.

Three ways to say where to connect:

- Server set: -ServerInstance and -Database, optionally -Credential for
  SQL authentication and -TrustServerCertificate.
Integrated authentication is used
  when no credential is given.
- File set (default): -Provider Sqlite (or another file-based engine) with -Database
  pointing at the database file.
- ConnectionString set: -ConnectionString for anything the provider accepts; add
  -Credential when the string carries no credentials.

Provider-specific switches that this command does not surface can be passed through
-ProviderParameter as a hashtable; they are splatted onto Connect-PSSqlRepository.

The session becomes PSSqlRepository's ambient session as well, so
Get-PSSqlRepositorySession shows it and Disconnect-SldgDatabase releases it.

## EXAMPLES

### EXAMPLE 1

Connect-SldgDatabase -ServerInstance 'localhost' -Database 'AdventureWorks'

Connects to AdventureWorks on localhost using integrated authentication.

### EXAMPLE 2

$cred = Get-Credential
PS C:\> Connect-SldgDatabase -ServerInstance 'dbserver\SQLEXPRESS' -Database 'TestDB' -Credential $cred -TrustServerCertificate

Connects using SQL authentication.

### EXAMPLE 3

Connect-SldgDatabase -Provider Sqlite -Database 'C:\Data\mydb.sqlite'

Connects to a SQLite database file.

### EXAMPLE 4

Connect-SldgDatabase -Provider DuckDB -ConnectionString 'Data Source=C:\Data\lab.duckdb'

Connects to a DuckDB file through the PSSqlRepository DuckDB provider.

## PARAMETERS

### -ConnectionString

A full provider connection string.
Wins over -ServerInstance/-Database.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: ConnectionString
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

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
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -CreateIfNotExists

File set: create the database file when it does not exist yet.
Without it a missing
file is an error, so a typo in the path cannot silently produce an empty database.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: File
  Position: Named
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
If not specified, integrated authentication is used
(providers that support it).

```yaml
Type: System.Management.Automation.PSCredential
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

### -Database

The database name (Server set) or the database file path (File set).

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: File
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: Server
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Provider

The PSSqlRepository provider name.
Default is 'SqlServer'.
Tab-completes from the
providers PSSqlRepository has loaded.

```yaml
Type: System.String
DefaultValue: SqlServer
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: ConnectionString
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: File
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: Server
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ProviderParameter

Additional parameters for Connect-PSSqlRepository (for example
@{ DisableRetryOnFailure = $true } on SqlServer, or the connect parameters of an
installed provider extension).

```yaml
Type: System.Collections.Hashtable
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

### -ServerInstance

The server instance to connect to (e.g., 'localhost', 'server\instance', 'server,port').

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Server
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -TrustServerCertificate

Skip TLS certificate validation (dev/test servers with self-signed certificates).

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

### SqlLabDataGenerator.Connection

{{ Fill in the Description }}

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

