---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.16.2026
PlatyPS schema version: 2024-05-01
title: Test-SldgAIProvider
---

# Test-SldgAIProvider

## SYNOPSIS

Tests connectivity to the configured AI provider.

## SYNTAX

### __AllParameterSets

```
Test-SldgAIProvider [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Sends a simple test prompt to the currently configured AI provider and reports
whether the connection succeeded, the response time, and the model used.

## EXAMPLES

### EXAMPLE 1

Test-SldgAIProvider

Provider  : Ollama
Model     : llama3
Status    : Connected
ResponseMs: 342

### EXAMPLE 2

Test-SldgAIProvider -Verbose

Tests with verbose output showing the request/response details.

## PARAMETERS

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### SqlLabDataGenerator.AIProviderTestResult

{{ Fill in the Description }}

## NOTES

## RELATED LINKS

- [Set-SldgAIProvider](Set-SldgAIProvider.md)
- [Get-SldgAIProvider](Get-SldgAIProvider.md)