---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03/30/2026
PlatyPS schema version: 2024-05-01
title: Get-SldgSession
---

# Get-SldgSession

## SYNOPSIS

Returns the current SqlLabDataGenerator session state.

## SYNTAX

### __AllParameterSets (Default)

```
Get-SldgSession [<CommonParameters>]
```

### Full

```
Get-SldgSession [-Full] [<CommonParameters>]
```

## DESCRIPTION

Provides a summary of the active session including connection details,
registered providers, locale packs, AI configuration, cache sizes,
and generation history.

Use this to inspect what is currently loaded and active without
navigating internal state. Useful for diagnostics and scripting.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-SldgSession
```

Returns a summary of the current session showing connection, AI provider,
registered providers/locales/transformers, cache sizes, and generation history.

### EXAMPLE 2

```powershell
Get-SldgSession -Full
```

Returns the raw SldgSession object with all internal collections and state.

### EXAMPLE 3

```powershell
(Get-SldgSession).CacheSizes
```

Shows the number of entries in each AI cache (AIValueCache, AILocaleCache,
AILocaleCategoryCache, CacheTimestamps).

## PARAMETERS

### -Full

Returns the raw SldgSession object with all internal collections.
By default, a summary SessionInfo object is returned.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: 'False'
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Full
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

### SqlLabDataGenerator.SessionInfo

A summary object containing SessionId, CreatedAt, Connection (ConnectionSummary),
AIProvider (AIProviderSummary), RegisteredProviders, RegisteredTransformers,
RegisteredLocales, CacheSizes (CacheSummary), GenerationPlans, and GenerationHistory.

### SqlLabDataGenerator.SldgSession

When `-Full` is specified, returns the raw session object with all internal collections.

## NOTES

The SessionInfo object provides computed type extensions:
- `ConnectionStatus` — returns the connection state or 'Disconnected'
- `TotalCacheEntries` — sum of all cache entry counts

## RELATED LINKS

- [Reset-SldgSession](Reset-SldgSession.md)
- [Clear-SldgCache](Clear-SldgCache.md)
- [Connect-SldgDatabase](Connect-SldgDatabase.md)
- [Get-SldgHealth](Get-SldgHealth.md)
