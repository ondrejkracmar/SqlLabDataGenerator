---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: en-US
Module Name: SqlLabDataGenerator
ms.date: 09/12/2026
PlatyPS schema version: 2024-05-01
title: Get-SldgSession
---

# Get-SldgSession

## SYNOPSIS

Returns the current SqlLabDataGenerator session state.

## SYNTAX

### Full

```
Get-SldgSession [-Full]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Provides a summary of the active session including connection details,
registered providers, locale packs, AI configuration, cache sizes,
and generation history.

Use this to inspect what is currently loaded and active without
navigating internal state.
Useful for diagnostics and scripting.

## EXAMPLES

### EXAMPLE 1

Get-SldgSession

Returns a summary of the current session.

### EXAMPLE 2

Get-SldgSession -Full

Returns the raw SldgSession object with all collections.

### EXAMPLE 3

(Get-SldgSession).CacheSizes

Shows the number of entries in each AI cache.

## PARAMETERS

### -Full

Returns the raw SldgSession object with all internal collections.
By default, a summary PSCustomObject is returned.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
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

{{ Fill in the Description }}

### SqlLabDataGenerator.SldgSession

{{ Fill in the Description }}

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

