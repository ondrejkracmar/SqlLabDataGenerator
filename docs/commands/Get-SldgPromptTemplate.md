---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.20.2026
PlatyPS schema version: 2024-05-01
title: Get-SldgPromptTemplate
---

# Get-SldgPromptTemplate

## SYNOPSIS

Lists or reads AI prompt templates available to the module.

## SYNTAX

### __AllParameterSets

```
Get-SldgPromptTemplate [[-Purpose] <string>] [[-Variant] <string>] [-IncludeContent]
 [<CommonParameters>]
```

## DESCRIPTION

Discovers prompt template files (.prompt) from the built-in templates
directory and any custom override path configured via AI.PromptPath.

Without parameters, lists all available templates with metadata.
With -Purpose, shows details for a specific template including
which file would be resolved for the current AI provider.
With -IncludeContent, also returns the rendered prompt body.

## EXAMPLES

### EXAMPLE 1

Get-SldgPromptTemplate

Lists all available prompt templates.

### EXAMPLE 2

Get-SldgPromptTemplate -Purpose column-analysis -IncludeContent

Shows the resolved column-analysis template with its content.

### EXAMPLE 3

Get-SldgPromptTemplate -Purpose structured-value -Variant ollama

Shows only the Ollama-specific variant of the structured-value prompt.

### EXAMPLE 4

Get-SldgPromptTemplate -Purpose structured-value -IncludeContent | Set-SldgPromptTemplate -Force

Copies the built-in template as a custom override for modification.

## PARAMETERS

### -IncludeContent

Include the rendered template content in the output.

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

### -Purpose

Filter to a specific prompt purpose (e.g. 'column-analysis', 'batch-generation',
'plan-advice', 'structured-value', 'locale-data', 'locale-category').

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

### -Variant

Show a specific variant. Defaults to showing all variants.
Provider-specific variants (e.g. 'ollama', 'openai') allow per-provider prompt tuning.

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

### SqlLabDataGenerator.PromptTemplate

Returns prompt template objects with Purpose, Variant, Description, Version, Path,
IsCustom, Placeholders, and optionally Content properties.

## NOTES

Prompt files use .prompt extension with YAML front matter for metadata and
{{Variable}} placeholders for runtime substitution.

## RELATED LINKS

- [Set-SldgPromptTemplate](Set-SldgPromptTemplate.md)
- [Remove-SldgPromptTemplate](Remove-SldgPromptTemplate.md)
- [Set-SldgAIProvider](Set-SldgAIProvider.md)
