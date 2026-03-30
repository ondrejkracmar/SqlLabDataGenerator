---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03/30/2026
PlatyPS schema version: 2024-05-01
title: Clear-SldgCache
---

# Clear-SldgCache

## SYNOPSIS

Clears AI-generated data caches without affecting connection or registrations.

## SYNTAX

### __AllParameterSets

```
Clear-SldgCache [[-CacheName] <string>] [<CommonParameters>]
```

## DESCRIPTION

Removes all cached AI-generated values, locale data, and locale categories.
The active database connection, registered providers, transformers, locales,
generation plans, and AI model overrides are preserved.

Use this when:
- You changed the AI provider or model and want fresh generation
- You updated prompt templates and want to see the effect
- Cached data appears stale or incorrect
- You want to free memory used by AI caches

## EXAMPLES

### EXAMPLE 1

```powershell
Clear-SldgCache
```

Clears all AI caches (value, locale, and locale category).

### EXAMPLE 2

```powershell
Clear-SldgCache -CacheName AIValueCache
```

Clears only the AI batch value cache, keeping locale caches intact.

## PARAMETERS

### -CacheName

Optional. Clear only a specific cache. If not specified, all caches are cleared.

```yaml
Type: System.String
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
AcceptedValues:
- AIValueCache
- AILocaleCache
- AILocaleCategoryCache
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

This cmdlet does not produce output.

## NOTES

Related timestamps for the cleared cache entries are also removed.
Use `Reset-SldgSession` to fully reset all state including connection and registrations.

## RELATED LINKS

- [Reset-SldgSession](Reset-SldgSession.md)
- [Get-SldgSession](Get-SldgSession.md)
