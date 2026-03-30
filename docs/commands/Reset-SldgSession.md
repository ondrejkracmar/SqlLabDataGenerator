---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03/30/2026
PlatyPS schema version: 2024-05-01
title: Reset-SldgSession
---

# Reset-SldgSession

## SYNOPSIS

Resets the SqlLabDataGenerator session to a clean state.

## SYNTAX

### __AllParameterSets

```
Reset-SldgSession [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION

Closes the active database connection, clears all registered providers,
transformers, locales, generation plans, AI caches, and model overrides.

After reset, the module behaves as if freshly imported — built-in providers
and locales are NOT re-registered automatically. Use `Import-Module -Force`
if you need a fresh module import with built-in registrations.

Use `Clear-SldgCache` if you only want to clear AI caches without losing
connection and registrations.

## EXAMPLES

### EXAMPLE 1

```powershell
Reset-SldgSession
```

Prompts for confirmation, then resets the entire session.

### EXAMPLE 2

```powershell
Reset-SldgSession -Force
```

Resets the session without confirmation.

## PARAMETERS

### -Force

Skips the confirmation prompt.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: 'False'
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

Shows what would happen if the cmdlet runs. The cmdlet is not run.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: 'False'
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

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: 'False'
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

This is a destructive operation with `ConfirmImpact = 'High'`. The confirmation prompt
is shown by default unless `-Force` is specified.

Built-in providers and locales are NOT re-registered after reset.
Use `Import-Module SqlLabDataGenerator -Force` for a full module reload.

## RELATED LINKS

- [Clear-SldgCache](Clear-SldgCache.md)
- [Get-SldgSession](Get-SldgSession.md)
- [Disconnect-SldgDatabase](Disconnect-SldgDatabase.md)
