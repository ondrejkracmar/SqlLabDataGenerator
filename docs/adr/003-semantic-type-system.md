# ADR-003: Semantic Type Classification System

## Status
Accepted

## Date
2025-01-01

## Context
Generating realistic data requires understanding what each column *means*, not just its SQL type. A column named `email_address` (nvarchar) should get email-shaped data, not random strings.

## Decision
Implement a two-tier semantic classification system:

1. **Pattern-based classification** (`Resolve-SldgSemanticType`): Regex patterns match column names to semantic types (Email, Phone, FirstName, SSN, etc.) with confidence scores. This is fast and works without external dependencies.

2. **AI-assisted classification** (`Get-SldgAIColumnAnalysis`): When an AI provider is configured, sends table/column metadata to an LLM for deeper semantic understanding, especially for ambiguous or domain-specific columns.

Semantic types map to generator functions via `Get-SldgGeneratorMap`, which picks the appropriate data generator and locale-specific parameters.

PII detection is integrated — columns classified as PII-sensitive types are flagged for awareness.

## Consequences
- **Positive**: Generates realistic, contextually appropriate data without manual column-by-column configuration.
- **Positive**: Pattern-based classification works offline with zero latency; AI augmentation is optional.
- **Negative**: Pattern matching can misclassify columns with ambiguous names.
- **Negative**: AI classification adds latency and cost; requires careful rate limiting and error handling.
