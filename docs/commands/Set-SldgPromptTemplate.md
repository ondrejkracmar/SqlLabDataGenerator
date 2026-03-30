---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.20.2026
PlatyPS schema version: 2024-05-01
title: Set-SldgPromptTemplate
---

# Set-SldgPromptTemplate

## SYNOPSIS

Creates or updates a custom prompt template override.

## SYNTAX

### Content

```
Set-SldgPromptTemplate [-Purpose] <string> [-Content] <string> [[-Variant] <string>]
 [[-Description] <string>] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### File

```
Set-SldgPromptTemplate [-Purpose] <string> [-FilePath] <string> [[-Variant] <string>]
 [[-Description] <string>] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### InputObject

```
Set-SldgPromptTemplate [-InputObject] <Object> [[-Variant] <string>]
 [[-Description] <string>] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION

Writes a custom .prompt file to the configured AI.PromptPath directory.
Custom prompts take priority over built-in templates during resolution.

If AI.PromptPath is not set, creates a 'CustomPrompts' folder next to the module
and configures it automatically.

The prompt file uses YAML front matter for metadata and supports
{{Variable}} placeholders that are substituted at runtime.

Accepts pipeline input from Get-SldgPromptTemplate — Purpose, Variant,
and Content are bound by property name.

## EXAMPLES

### EXAMPLE 1

Set-SldgPromptTemplate -Purpose 'structured-value' -Variant 'default' -Content $myPrompt -Description 'Custom JSON/XML generator for reports'

Creates a custom structured-value prompt template.

### EXAMPLE 2

Set-SldgPromptTemplate -Purpose 'column-analysis' -Variant 'ollama' -FilePath '.\my-ollama-prompt.txt'

Creates an Ollama-specific override for column analysis from a file.

### EXAMPLE 3

Get-SldgPromptTemplate -Purpose structured-value -IncludeContent | Set-SldgPromptTemplate -Force

Copies the built-in template as a custom override (Purpose, Variant, Content bound via pipeline).

### EXAMPLE 4

$t = Get-SldgPromptTemplate -Purpose structured-value -IncludeContent
PS C:\> Set-SldgPromptTemplate -Purpose structured-value -Content ($t.Content -replace 'Generate 10', 'Generate 20') -Force

Copies and modifies the built-in template.

## PARAMETERS

### -Content

The prompt body text. Can include {{Variable}} placeholders.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Content
  Position: 1
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Description

Optional description stored in the YAML front matter.

```yaml
Type: System.String
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

### -FilePath

Read the prompt content from an existing file instead of -Content.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: File
  Position: 1
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Force

Overwrite an existing custom prompt without confirmation.

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

### -InputObject

A prompt template object from Get-SldgPromptTemplate. Purpose, Variant,
and Content (when present) are extracted automatically.

```yaml
Type: System.Object
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: InputObject
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

The prompt purpose to override (e.g. 'column-analysis', 'structured-value',
'batch-generation', 'plan-advice', 'locale-data', 'locale-category').

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Content
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
- Name: File
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

The variant name. Defaults to 'default'. Use provider names like 'openai'
or 'ollama' to create provider-specific overrides.

```yaml
Type: System.String
DefaultValue: default
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
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
Purpose, Variant, and Content properties are bound by property name.

## OUTPUTS

### SqlLabDataGenerator.PromptTemplate

Returns the created/updated prompt template object.

## NOTES

Custom prompts are stored in the directory configured by AI.PromptPath.
If that config is not set, a 'CustomPrompts' directory is created automatically.

## RELATED LINKS

- [Get-SldgPromptTemplate](Get-SldgPromptTemplate.md)
- [Remove-SldgPromptTemplate](Remove-SldgPromptTemplate.md)
- [Set-SldgAIProvider](Set-SldgAIProvider.md)
