# Quranic Universal Library - Advanced Search API

## Overview

The QUL Advanced Search API provides powerful, scalable search capabilities across Quranic text, translations, and morphological data using Elasticsearch. It supports exact, partial, morphological, and semantic queries.

## Base URL

```
https://your-qul-domain.com/api/v1/search
```

## Authentication

All API requests require an API key. Include your API key in the request header:

```
X-API-Key: your_api_key_here
```

Or as a query parameter:

```
?api_key=your_api_key_here
```

## Rate Limiting

- Default limit: 1000 requests per month per API key
- Rate limit headers included in all responses
- Exceeding limits returns HTTP 429 (Too Many Requests)

## Endpoints

### 1. General Search

Search across verses, translations, and words.

**Endpoint:** `GET /api/v1/search`

**Parameters:**
- `q` (required): Search query
- `page`: Page number (default: 1)
- `per_page`: Results per page (default: 20, max: 100)
- `chapter_id`: Filter by chapter ID
- `juz_number`: Filter by Juz number (1-30)
- `hizb_number`: Filter by Hizb number
- `language_id`: Filter by translation language ID

**Example:**
```bash
curl -H "X-API-Key: your_key" \
  "https://qul-api.com/api/v1/search?q=الحمد لله&chapter_id=1"
```

### 2. Morphology Search

Search by grammatical attributes.

**Endpoint:** `GET /api/v1/search/morphology`

**Parameters:**
- `part_of_speech`: Part of speech (e.g., "noun", "verb", "particle")
- `pos_tags`: POS tags
- `root`: Root letters (e.g., "ك-ت-ب")
- `lemma`: Lemma form
- `grammar_role`: Grammar role
- `verb_form`: Verb form (I-X)
- `page`, `per_page`: Pagination

### 3. Semantic Search

Search using conceptual similarity.

**Endpoint:** `GET /api/v1/search/semantic`

**Parameters:**
- `q` (required): Concept or theme query
- `similarity_threshold`: Minimum similarity score (0.1-1.0, default: 0.7)
- Standard filters (chapter_id, juz_number, etc.)

### 4. Script Search

Search specific Arabic scripts.

**Endpoint:** `GET /api/v1/search/script`

**Parameters:**
- `q` (required): Arabic text query
- `script_type`: Script type (`uthmani`, `qpc_hafs`, `indopak`)
- Standard filters and pagination

### 5. Autocomplete

Get search suggestions as user types.

**Endpoint:** `GET /api/v1/search/autocomplete`

**Parameters:**
- `q` (required): Partial query (minimum 2 characters)

## Search Syntax

### General Search
- **Exact phrase**: `"الحمد لله"` 
- **Wildcard**: `رحم*` (finds رحمن, رحيم, etc.)
- **Boolean**: `الله AND رحمن`
- **Field search**: `chapter_id:1`

### Morphology Search
- **Multiple filters**: Combine part_of_speech, root, grammar_role
- **Root patterns**: Use Arabic root notation (ف-ع-ل)
- **POS tags**: Standard linguistic notation

### Semantic Search
- **Concepts**: Use thematic words like "mercy", "guidance"
- **Multilingual**: Works with Arabic concepts and English translations
- **Threshold**: Adjust similarity_threshold for broader/narrower results

## Performance

- **Target response time**: < 1 second for 95% of queries
- **Concurrent requests**: Supports 100+ concurrent queries
- **Index size**: Optimized for fast retrieval
- **Caching**: Results cached for frequently accessed queries

## Examples

### Complete Surah Search
```bash
# Search for complete Surah Al-Fatiha
curl -H "X-API-Key: your_key" \
  "https://qul-api.com/api/v1/search?q=بسم الله الرحمن الرحيم الحمد لله رب العالمين"
```

### Find All Nouns in Specific Chapter
```bash
# Find all nouns in Al-Baqarah
curl -H "X-API-Key: your_key" \
  "https://qul-api.com/api/v1/search/morphology?part_of_speech=noun&chapter_id=2"
```

### Thematic Search
```bash
# Find verses about prayer/salah
curl -H "X-API-Key: your_key" \
  "https://qul-api.com/api/v1/search/semantic?q=prayer salah&similarity_threshold=0.6"
```

---

*This API provides comprehensive access to Quranic text analysis and search capabilities. All responses maintain academic accuracy and respect the sacred nature of the content.*