---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: en-US
Module Name: SqlLabDataGenerator
ms.date: 09/13/2026
PlatyPS schema version: 2024-05-01
title: Remove-SldgPromptTemplate
---

# Remove-SldgPromptTemplate

## SYNOPSIS

Removes a custom prompt template override.

## SYNTAX

### __AllParameterSets

```
Remove-SldgPromptTemplate [[-InputObject] <PromptTemplate>] [[-Purpose] <string>]
 [[-Variant] <string>] [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Deletes a custom .prompt file from the AI.PromptPath directory.
Only custom overrides can be removed — built-in templates are protected.

After removal, the module falls back to the built-in template for that purpose.

Accepts pipeline input from Get-SldgPromptTemplate — Purpose and Variant
are bound by property name.
Built-in templates piped in are skipped.

## EXAMPLES

### EXAMPLE 1

Remove-SldgPromptTemplate -Purpose 'structured-value'

Removes the custom default variant of the structured-value prompt.

### EXAMPLE 2

Remove-SldgPromptTemplate -Purpose 'column-analysis' -Variant 'ollama'

Removes the Ollama-specific column-analysis override.

### EXAMPLE 3

Get-SldgPromptTemplate | Where-Object IsCustom | Remove-SldgPromptTemplate

Removes all custom prompt overrides via pipeline.

### EXAMPLE 4

Get-SldgPromptTemplate -Purpose 'structured-value' | Where-Object IsCustom | Remove-SldgPromptTemplate

Removes custom overrides for a specific purpose.

## PARAMETERS

### -Confirm

If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

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

### -InputObject

A prompt template object from Get-SldgPromptTemplate.
Purpose and Variant
are extracted automatically.
Built-in (non-custom) templates are skipped.

```yaml
Type: System.Object
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Purpose

The prompt purpose to remove (e.g.
'structured-value', 'column-analysis').

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Variant

The variant to remove.
Defaults to 'default'.

```yaml
Type: System.String
DefaultValue: default
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -WhatIf

If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

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

### System.Object

{{ Fill in the Description }}

### System.String

{{ Fill in the Description }}

## OUTPUTS

### System.Void

{{ Fill in the Description }}

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

