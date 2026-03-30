---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.20.2026
PlatyPS schema version: 2024-05-01
title: Remove-SldgPromptTemplate
---

# Remove-SldgPromptTemplate

## SYNOPSIS

Removes a custom prompt template override.

## SYNTAX

### ByName (Default)

```
Remove-SldgPromptTemplate [-Purpose] <string> [[-Variant] <string>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

### InputObject

```
Remove-SldgPromptTemplate [-InputObject] <Object>
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION

Deletes a custom .prompt file from the AI.PromptPath directory.
Only custom overrides can be removed — built-in templates are skipped
with a warning.

After removal, the built-in template (if any) becomes active again for
the given purpose and variant.

Supports ShouldProcess with ConfirmImpact 'Medium'.

## EXAMPLES

### EXAMPLE 1

Remove-SldgPromptTemplate -Purpose 'column-analysis'

Removes the custom override for the 'column-analysis' purpose
(default variant).

### EXAMPLE 2

Remove-SldgPromptTemplate -Purpose 'structured-value' -Variant 'ollama'

Removes only the Ollama-specific override for structured-value.

### EXAMPLE 3

Get-SldgPromptTemplate | Where-Object IsCustom | Remove-SldgPromptTemplate

Pipes all custom templates to removal.

### EXAMPLE 4

Remove-SldgPromptTemplate -Purpose 'column-analysis' -WhatIf

Shows what would be removed without deleting anything.

## PARAMETERS

### -InputObject

A prompt template object from Get-SldgPromptTemplate. The Purpose and
Variant properties are used to locate the file to remove.

```yaml
Type: System.Object
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: InputObject
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Purpose

The prompt purpose to remove (e.g. 'column-analysis', 'structured-value',
'batch-generation', 'plan-advice', 'locale-data', 'locale-category').

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: ByName
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Variant

The variant name. Defaults to 'default'.

```yaml
Type: System.String
DefaultValue: default
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: ByName
  Position: 1
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
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

### SqlLabDataGenerator.PromptTemplate

Accepts prompt template objects from Get-SldgPromptTemplate via pipeline.

## OUTPUTS

### None

This cmdlet does not produce output.

## NOTES

Only custom overrides stored in AI.PromptPath can be removed.
Built-in templates are part of the module and cannot be deleted.

## RELATED LINKS

- [Get-SldgPromptTemplate](Get-SldgPromptTemplate.md)
- [Set-SldgPromptTemplate](Set-SldgPromptTemplate.md)
- [Set-SldgAIProvider](Set-SldgAIProvider.md)
