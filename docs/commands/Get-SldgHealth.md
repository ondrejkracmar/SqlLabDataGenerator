---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03/30/2026
PlatyPS schema version: 2024-05-01
title: Get-SldgHealth
---

# Get-SldgHealth

## SYNOPSIS

Returns the health status of the SqlLabDataGenerator module.

## SYNTAX

### __AllParameterSets

```
Get-SldgHealth [<CommonParameters>]
```

## DESCRIPTION

Returns version, registered providers, AI configuration status, active connection info,
registered locales, and available transformers.

Used as the health check endpoint for the Azure Functions API and for local diagnostics.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-SldgHealth
```

Returns the current module health status including version, providers, and AI settings.

### EXAMPLE 2

```powershell
(Get-SldgHealth).AIEnabled
```

Checks whether AI-assisted generation is currently enabled.

## PARAMETERS

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### SqlLabDataGenerator.HealthStatus

A PSCustomObject with PSTypeName `SqlLabDataGenerator.HealthStatus` containing:
Status, ModuleVersion, PowerShellVersion, Providers, AIEnabled, AILocaleEnabled,
ActiveConnection, RegisteredLocales, Transformers, and Timestamp.

## NOTES

The HealthStatus object includes nested connection information when a database is connected.
Access it via `(Get-SldgHealth).ActiveConnection`.

## RELATED LINKS

- [Get-SldgSession](Get-SldgSession.md)
- [Connect-SldgDatabase](Connect-SldgDatabase.md)
