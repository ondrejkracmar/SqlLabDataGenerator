# ADR-004: AI Provider Integration Architecture

## Status
Accepted

## Date
2025-01-01

## Context
AI capabilities (semantic analysis, data generation, locale generation, plan advice) are valuable but must be optional, resilient, and provider-agnostic. Multiple AI backends exist (OpenAI, Azure OpenAI, Ollama) with different APIs and reliability characteristics.

## Decision
Centralize all AI HTTP communication through `Invoke-SldgAIRequest`, which handles:

- **Provider abstraction**: Builds correct endpoint URL and headers for OpenAI, AzureOpenAI, and Ollama
- **Retry with exponential backoff**: Configurable retry count and base delay (`AI.RetryCount`, `AI.RetryDelaySeconds`)
- **Timeout**: Configurable request timeout (`AI.TimeoutSeconds`, default 120s)
- **Rate limiting**: Sliding-window rate limiter (`AI.RateLimitPerMinute`, default 30 RPM)
- **TLS handling**: Certificate validation bypass scoped to Ollama only (local development)

API keys are stored as `SecureString` in PSFConfig, decrypted only at request time. Users can pass `-ApiKey [SecureString]` or `-Credential [PSCredential]`.

## Consequences
- **Positive**: Single point of resilience — all AI callers benefit from retry, timeout, and rate limiting.
- **Positive**: Swapping AI providers requires only `Set-SldgAIProvider` — no code changes for consumers.
- **Positive**: Graceful degradation — module works fully without AI, just with pattern-based classification.
- **Negative**: All AI providers must conform to OpenAI-compatible chat completion API format.
- **Negative**: Rate limiter is per-process; concurrent sessions may exceed provider limits.
