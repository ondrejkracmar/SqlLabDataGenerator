---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: en-US
Module Name: SqlLabDataGenerator
ms.date: 09/12/2026
PlatyPS schema version: 2024-05-01
title: Reset-SldgSession
---

# Reset-SldgSession

## SYNOPSIS

Resets the SqlLabDataGenerator session to a clean state.

## SYNTAX

### __AllParameterSets

```
Reset-SldgSession [-Force] [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Closes the active database connection, clears all registered providers,
transformers, locales, generation plans, AI caches, and model overrides.

After reset, the module behaves as if freshly imported — built-in providers
and locales are NOT re-registered automatically.
Use Import-Module -Force
if you need a fresh module import with built-in registrations.

Use Clear-SldgCache if you only want to clear AI caches without losing
connection and registrations.

## EXAMPLES

### EXAMPLE 1

Reset-SldgSession

Prompts for confirmation, then resets the entire session.

### EXAMPLE 2

Reset-SldgSession -Force

Resets the session without confirmation.

## PARAMETERS

### -Confirm

Prompts for confirmation before resetting the session.

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

### -Force

Skips the confirmation prompt.

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

### -WhatIf

Shows what the command would do without actually resetting the session.

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

