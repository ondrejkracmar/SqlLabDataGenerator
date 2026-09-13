---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: en-US
Module Name: SqlLabDataGenerator
ms.date: 09/13/2026
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
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

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

Filter to a specific prompt purpose (e.g.
'column-analysis', 'batch-generation').

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

Show a specific variant.
Defaults to the effective variant for the active provider.

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

{{ Fill in the Description }}

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

