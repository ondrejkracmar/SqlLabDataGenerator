---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: en-US
Module Name: SqlLabDataGenerator
ms.date: 09/12/2026
PlatyPS schema version: 2024-05-01
title: Get-SldgAIProvider
---

# Get-SldgAIProvider

## SYNOPSIS

Returns the current AI provider configuration.

## SYNTAX

### __AllParameterSets

```
Get-SldgAIProvider [[-Purpose] <string>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Shows which AI provider is configured, model, endpoint, and which AI features are enabled.
Returns a structured object useful for pipelines and display.

When per-purpose model overrides are configured (via Set-SldgAIProvider -Purpose),
they are included in the ModelOverrides property.

## EXAMPLES

### EXAMPLE 1

Get-SldgAIProvider

Provider       : Ollama
Model          : llama3
Endpoint       : http://localhost:11434
ApiKeySet      : False
MaxTokens      : 4096
Temperature    : 0.3
AIGeneration   : True
AILocale       : True
Locale         : cs-CZ
ModelOverrides : {structured-value, batch-generation}

### EXAMPLE 2

(Get-SldgAIProvider).Provider
Ollama

### EXAMPLE 3

Get-SldgAIProvider -Purpose 'structured-value'

Shows which provider/model would be used for structured-value generation.

## PARAMETERS

### -Purpose

Show the effective AI configuration for a specific purpose, resolving overrides.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### SqlLabDataGenerator.AIProviderInfo

{{ Fill in the Description }}

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

