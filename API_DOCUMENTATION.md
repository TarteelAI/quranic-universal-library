# QUL API Documentation

## Overview

The Quranic Universal Library (QUL) API provides access to comprehensive Quran data including verses, translations, tafsirs, topics, and morphological analysis.

## Base URL

```
/api/v1
```

## Authentication

Currently, no authentication is required for read-only access to the API.

## Response Format

All API responses are in JSON format and follow a consistent structure with pagination metadata when applicable.

## Endpoints

### Chapters API

#### Get All Chapters
```
GET /api/v1/chapters
```

#### Get Single Chapter
```
GET /api/v1/chapters/:id
```

### Verses API

#### Get Verses
```
GET /api/v1/verses
```

Parameters:
- `filter`: Filter type (e.g., "by_chapter")
- `id`: Chapter ID when using filter
- `fields`: Comma-separated list of verse fields to include
- `words`: Include word data (boolean)
- `translations`: Comma-separated list of translation IDs
- `page`: Page number for pagination
- `per_page`: Results per page (max 50)

#### Get Verses for Specific Chapter
```
GET /api/v1/chapters/:id/verses
```

### Translations API

#### Get All Translations
```
GET /api/v1/translations
```

Parameters:
- `verse_id`: Filter by specific verse
- `chapter_id`: Filter by chapter
- `resource_content_id`: Filter by translation resource
- `language_id`: Filter by language
- `page`: Page number
- `per_page`: Results per page

#### Get Single Translation
```
GET /api/v1/translations/:id
```

### Tafsirs API

#### Get All Tafsirs
```
GET /api/v1/tafsirs
```

Parameters:
- `verse_id`: Filter by specific verse (returns tafsirs covering this verse)
- `chapter_id`: Filter by chapter
- `resource_content_id`: Filter by tafsir resource
- `language_id`: Filter by language
- `page`: Page number
- `per_page`: Results per page

#### Get Single Tafsir
```
GET /api/v1/tafsirs/:id
```

### Topics API

#### Get All Topics
```
GET /api/v1/topics
```

Parameters:
- `verse_id`: Filter by topics associated with specific verse
- `chapter_id`: Filter by topics associated with chapter
- `parent_id`: Filter by parent topic
- `thematic`: Filter thematic topics (true/false)
- `ontology`: Filter ontology topics (true/false)
- `page`: Page number
- `per_page`: Results per page

#### Get Single Topic
```
GET /api/v1/topics/:id
```

### Ayah Themes API

#### Get All Ayah Themes
```
GET /api/v1/ayah_themes
```

Parameters:
- `verse_id`: Filter by themes covering specific verse
- `chapter_id`: Filter by chapter
- `theme`: Text search in theme content
- `page`: Page number
- `per_page`: Results per page

#### Get Single Ayah Theme
```
GET /api/v1/ayah_themes/:id
```

### Resources API

#### Get All Resources
```
GET /api/v1/resources
```

Parameters:
- `resource_type`: Filter by resource type
- `sub_type`: Filter by sub type (translation, tafsir, etc.)
- `cardinality_type`: Filter by cardinality
- `language_id`: Filter by language
- `author_id`: Filter by author
- `search`: Text search in name and description
- `page`: Page number
- `per_page`: Results per page

#### Get Single Resource
```
GET /api/v1/resources/:id
```

### Morphology API

#### Roots

##### Get All Roots
```
GET /api/v1/morphology/roots
```

Parameters:
- `word_id`: Filter by roots of specific word
- `verse_id`: Filter by roots used in specific verse
- `chapter_id`: Filter by roots used in chapter
- `value`: Text search in root value
- `page`: Page number
- `per_page`: Results per page

##### Get Single Root
```
GET /api/v1/morphology/roots/:id
```

#### Stems

##### Get All Stems
```
GET /api/v1/morphology/stems
```

Parameters:
- `word_id`: Filter by stems of specific word
- `verse_id`: Filter by stems used in specific verse
- `chapter_id`: Filter by stems used in chapter
- `text`: Text search in stem text
- `page`: Page number
- `per_page`: Results per page

##### Get Single Stem
```
GET /api/v1/morphology/stems/:id
```

#### Lemmas

##### Get All Lemmas
```
GET /api/v1/morphology/lemmas
```

Parameters:
- `word_id`: Filter by lemmas of specific word
- `verse_id`: Filter by lemmas used in specific verse
- `chapter_id`: Filter by lemmas used in chapter
- `text`: Text search in lemma text
- `page`: Page number
- `per_page`: Results per page

##### Get Single Lemma
```
GET /api/v1/morphology/lemmas/:id
```

### Audio API (Existing)

#### Surah Recitations
```
GET /api/v1/audio/surah_recitations
GET /api/v1/audio/surah_recitations/:id
```

#### Ayah Recitations
```
GET /api/v1/audio/ayah_recitations
GET /api/v1/audio/ayah_recitations/:id
```

#### Audio Segments
```
GET /api/v1/audio/surah_segments/:recitation_id
GET /api/v1/audio/ayah_segments/:recitation_id
```

## Error Handling

The API returns appropriate HTTP status codes:

- `200 OK`: Successful request
- `404 Not Found`: Resource not found
- `400 Bad Request`: Invalid parameters

Error responses include a JSON object with error details:

```json
{
  "error": "Not Found",
  "message": "Resource with ID 123 not found"
}
```

## Rate Limiting

Currently, no rate limiting is enforced, but this may change in future versions.

## Caching

Responses are cached for 7 days in production environments with appropriate cache headers.