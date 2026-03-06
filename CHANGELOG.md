# Changelog

All notable changes to AIO Studio will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Unit tests for all DAOs (drift in-memory database)
- AI service layer tests (request/response parsing, SSE streaming)
- Provider tests (ProjectActions CRUD and cascade delete)
- Widget tests (ProjectCard, AssetThumbnail, ChatMessageBubble)
- Database indexes for assets table (project_id, type, created_at, is_favorite)
- Image loading optimization (cacheWidth/cacheHeight, memory cache limit)
- Multi-platform CI/CD with GitHub Actions
- MSIX packaging configuration for Windows
- Android signing configuration
- iOS permission descriptions

## [1.0.0] - 2026-XX-XX

### Added
- Multi-provider AI chat with streaming (OpenAI, Anthropic, custom compatible APIs)
- AI image generation (DALL-E, Stability AI)
- AI video generation with async task queue
- Project management with archive/unarchive
- Asset management with import, tagging, favorites, and batch operations
- Prompt library with categories, variables, and optimization
- Browser extension bridge for web asset capture
- Cross-platform desktop support (Windows, macOS, Linux)
- Mobile support (Android, iOS)
- Fluent Design UI with dark/light theme
- Local SQLite database with drift ORM
- Configurable AI provider settings
