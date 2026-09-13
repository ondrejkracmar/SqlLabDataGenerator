---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: en-US
Module Name: SqlLabDataGenerator
ms.date: 09/13/2026
PlatyPS schema version: 2024-05-01
title: Clear-SldgCache
---

# Clear-SldgCache

## SYNOPSIS

Clears AI-generated data caches without affecting connection or registrations.

## SYNTAX

### __AllParameterSets

```
Clear-SldgCache [[-CacheName] <string>] [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

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

Clear-SldgCache

Clears all AI caches.

### EXAMPLE 2

Clear-SldgCache -CacheName AIValueCache

Clears only the AI batch value cache (keeps locale caches).

## PARAMETERS

### -CacheName

Optional.
Clear only a specific cache: AIValueCache, AILocaleCache, or AILocaleCategoryCache.
If not specified, all caches are cleared.

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

## RELATED LINKS

{{ Fill in the related links here }}

