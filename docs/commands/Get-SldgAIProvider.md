---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.16.2026
PlatyPS schema version: 2024-05-01
title: Get-SldgAIProvider
---

# Get-SldgAIProvider

## SYNOPSIS

Returns the current AI provider configuration.

## SYNTAX

### __AllParameterSets

```
Get-SldgAIProvider [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Shows which AI provider is configured, model, endpoint, and which AI features are enabled.
Returns a structured object useful for pipelines and display.

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

### EXAMPLE 2

(Get-SldgAIProvider).Provider
Ollama

## PARAMETERS

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

- [Set-SldgAIProvider](Set-SldgAIProvider.md)
- [Test-SldgAIProvider](Test-SldgAIProvider.md)