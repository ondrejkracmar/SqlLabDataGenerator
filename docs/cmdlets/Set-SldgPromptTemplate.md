---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: en-US
Module Name: SqlLabDataGenerator
ms.date: 09/12/2026
PlatyPS schema version: 2024-05-01
title: Set-SldgPromptTemplate
---

# Set-SldgPromptTemplate

## SYNOPSIS

Creates or updates a custom prompt template override.

## SYNTAX

### Content (Default)

```
Set-SldgPromptTemplate -Purpose <string> -Content <string> [-Variant <string>]
 [-Description <string>] [-Force] [-WhatIf] [-Confirm]
```

### InputObject

```
Set-SldgPromptTemplate [-InputObject <PromptTemplate>] [-Variant <string>] [-Description <string>]
 [-Force] [-WhatIf] [-Confirm]
```

### File

```
Set-SldgPromptTemplate -Purpose <string> -FilePath <string> [-Variant <string>]
 [-Description <string>] [-Force] [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Writes a custom .prompt file to the configured AI.PromptPath directory.
Custom prompts take priority over built-in templates during resolution.

If AI.PromptPath is not set, creates a 'prompts' folder next to the module
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

Copies the built-in template as a custom override (Purpose, Variant, Content bound by property name).

### EXAMPLE 4

Get-SldgPromptTemplate -Purpose structured-value -IncludeContent | Set-SldgPromptTemplate -Content ($_.Content -replace 'Generate 10', 'Generate 20') -Force

Copies and modifies the built-in template.

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

### -Content

The prompt body text.
Can include {{Variable}} placeholders.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Content
  Position: Named
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
  Position: Named
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

A prompt template object from Get-SldgPromptTemplate.
Purpose, Variant,
and Content (when present) are extracted automatically.

```yaml
Type: System.Object
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: InputObject
  Position: Named
  IsRequired: false
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Purpose

The prompt purpose to override (e.g.
'column-analysis', 'structured-value',
'batch-generation', 'plan-advice', 'locale-data', 'locale-category').

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: File
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
- Name: Content
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Variant

The variant name.
Defaults to 'default'.
Use provider names like 'openai'
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

### SqlLabDataGenerator.PromptTemplate

{{ Fill in the Description }}

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

