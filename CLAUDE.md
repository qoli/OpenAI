# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Swift Package Manager library that provides a community-maintained Swift implementation of the OpenAI API. The library supports multiple AI providers beyond OpenAI, including Glama.AI and Qwen.ai, with customizable API versions (e.g., Google Gemini's v1beta).

## Development Commands

### Building
```bash
# Build the package
swift build

# Build with verbose output
swift build -v
```

### Testing
```bash
# Run all tests
swift test

# Run tests for a specific target
swift test --filter OpenAITests
```

### Demo Application
The project includes a demo iOS application in the `Demo/` directory:
- Main app project: `Demo/Demo.xcodeproj`
- Demo chat package: `Demo/DemoChat/`

To run the demo:
1. Open `Demo/Demo.xcodeproj` in Xcode
2. Build and run the target

## Code Architecture

### Core Structure
- **Sources/OpenAI/**: Main library source code
  - **OpenAI.swift**: Main OpenAI client class implementing OpenAIProtocol
  - **Public/**: Public API interfaces and models
    - **Protocols/**: Protocol definitions (OpenAIProtocol, async/combine extensions)
    - **Models/**: Request/response models for different API endpoints
    - **Utilities/**: Helper utilities including vector operations
  - **Private/**: Internal implementation details
    - Network request builders and session management
    - Streaming session handling
    - Multipart form data encoding

### Key Components

#### OpenAI Client Configuration
The main `OpenAI` class supports flexible configuration:
- Custom API hosts (not just api.openai.com)
- Custom API versions (configurable via `apiVersion` property)
- Custom base paths for proxy setups
- Configurable timeouts (default 900 seconds)
- Support for different schemes and ports

#### API Endpoints
- **Chat Completions**: Regular and streaming chat with GPT models
- **Images**: Generation, editing, and variations using DALL-E
- **Audio**: Speech synthesis, transcriptions, and translations
- **Embeddings**: Text embeddings for semantic search
- **Models**: List and retrieve model information
- **Moderations**: Content moderation capabilities

#### Model Definitions
Models are defined as string type aliases in `Sources/OpenAI/Public/Models/Models/Models.swift`:
- GPT-4 variants (including gpt-4o, gpt-4-turbo)
- GPT-3.5 variants
- DALL-E models
- Whisper for audio
- Text-to-speech models
- Embedding models

### Architecture Patterns
- **Protocol-based design**: OpenAIProtocol defines the public interface
- **Result-based error handling**: All async methods return Result<T, Error>
- **Multiple async patterns**: Supports closures, Combine publishers, and structured concurrency
- **Streaming support**: Real-time streaming for chat completions
- **Thread-safe operations**: ArrayWithThreadSafety for managing concurrent streaming sessions

### Network Layer
- Custom URLRequestBuildable protocol for flexible request construction
- Separate handling for JSON requests vs multipart form data
- Configurable authentication and organization headers
- Robust error handling with API-specific error types

### Testing
- Comprehensive test suite in `Tests/OpenAITests/`
- Mock implementations for URLSession and data tasks
- Async/await and Combine testing patterns
- Error case testing with API error models

## Important Notes

### Customization Features
This fork diverges from the original MacPaw implementation and focuses on:
- OpenAI API compatibility as the primary goal
- Support for alternative AI providers (Glama.AI, Qwen.ai)
- Configurable API versions for different providers
- Not all new OpenAI features may be implemented

### API Version Handling
The library supports custom API versions through the `Configuration.apiVersion` property, allowing integration with providers that use different versioning schemes (e.g., Google Gemini's v1beta).

### Request Timeout
Default API timeout is set to 900 seconds (15 minutes) to accommodate long-running requests, particularly for complex generation tasks.