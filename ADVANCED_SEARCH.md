# Advanced Quran Search System

## Overview

The Advanced Quran Search System provides comprehensive search capabilities across QUL's vast Quranic resources using multiple search types and advanced filtering options. This system enables users to search through Arabic text, translations, tafsirs, and morphological data with high precision and flexibility.

## Features

### Search Types

1. **Text Search**
   - Full-text search across Arabic texts and translations
   - Supports multiple Arabic script types (QPC Hafs, Uthmani, Indo-Pak, etc.)
   - Case-insensitive and diacritic-aware searching

2. **Morphology Search** 
   - Search by grammatical categories (Parts of Speech)
   - Categories: nouns, verbs, particles, pronouns, adjectives
   - Arabic and English keyword support

3. **Semantic Search**
   - Meaning-based search using synonym expansion
   - Example: "mercy" finds verses about forgiveness, compassion, grace
   - Multilingual synonym support (English/Arabic)

4. **Root Search**
   - Search by Arabic trilateral roots
   - Find all words derived from a specific root
   - Example: "كتب" finds all k-t-b derived words

5. **Lemma Search**
   - Search by word base forms (lemmas)
   - Useful for finding word variations

6. **Stem Search**
   - Search by word stems
   - Morphological analysis-based matching

7. **Pattern Search**
   - Regular expression support
   - Advanced pattern matching capabilities
   - Example: `.*الله.*` for complex patterns

8. **Script-Specific Search**
   - Search within specific Arabic script types
   - Supports: QPC Hafs, Uthmani, Imlaei, Indo-Pak, Nastaleeq

9. **Combined Search**
   - Multi-type search with intelligent deduplication
   - Provides breakdown by search type
   - Ranks results by relevance

### Advanced Filtering

- **Chapter Filter**: Limit search to specific Quran chapters
- **Language Filter**: Filter translations by language
- **Script Filter**: Choose Arabic script type
- **Content Type**: Include/exclude translations and tafsirs
- **Morphology Category**: Filter by grammatical categories

## API Reference

### Endpoints

#### POST /api/v1/search/advanced
Main search endpoint supporting all search types.

**Parameters:**
```json
{
  "search": {
    "query": "string (required)",
    "type": "text|morphology|semantic|root|lemma|stem|pattern|script_specific|combined",
    "chapter_id": "integer (optional)",
    "script": "qpc_hafs|uthmani|imlaei|indopak|qpc_nastaleeq|uthmani_simple",
    "morphology_category": "noun|verb|particle|pronoun|proper_noun|adjective",
    "translation_language": "string (optional)",
    "include_translations": "boolean (default: true)",
    "include_tafsirs": "boolean (default: false)"
  }
}
```

**Response:**
```json
{
  "search": {
    "type": "text",
    "query": "الله",
    "filters": {},
    "total_count": 2851,
    "execution_time": 1234567890.123
  },
  "data": {
    "verses": [...],
    "translations": [...],
    "tafsirs": [...],
    "morphology_words": [...],
    "breakdown": {
      "text": 1200,
      "roots": 800,
      "lemmas": 600
    }
  }
}
```

#### GET /api/v1/search/morphology_categories
Returns available morphological categories.

#### GET /api/v1/search/arabic_scripts  
Returns supported Arabic script types.

#### GET /api/v1/search/suggestions?q=query
Returns search suggestions for auto-complete.

## Web Interface

### Access
- Main interface: `/advanced_search`
- Search results: `/search?query=...`

### Features
- Real-time search suggestions
- Dynamic form updates based on search type
- Turbo-powered result loading
- Responsive design with Tailwind CSS
- Result highlighting and formatting

## Usage Examples

### Basic Text Search
```bash
curl -X POST /api/v1/search/advanced \
  -H "Content-Type: application/json" \
  -d '{
    "search": {
      "query": "الله",
      "type": "text"
    }
  }'
```

### Morphology Search
```bash
curl -X POST /api/v1/search/advanced \
  -H "Content-Type: application/json" \
  -d '{
    "search": {
      "query": "noun",
      "type": "morphology",
      "morphology_category": "noun"
    }
  }'
```

### Root Search with Chapter Filter
```bash
curl -X POST /api/v1/search/advanced \
  -H "Content-Type: application/json" \
  -d '{
    "search": {
      "query": "كتب",
      "type": "root",
      "chapter_id": 2
    }
  }'
```

### Semantic Search
```bash
curl -X POST /api/v1/search/advanced \
  -H "Content-Type: application/json" \
  -d '{
    "search": {
      "query": "mercy",
      "type": "semantic",
      "include_translations": true
    }
  }'
```

### Pattern Search
```bash
curl -X POST /api/v1/search/advanced \
  -H "Content-Type: application/json" \
  -d '{
    "search": {
      "query": ".*رحم.*",
      "type": "pattern",
      "script": "qpc_hafs"
    }
  }'
```

## Architecture

### Backend Components

- **Search::AdvancedSearchService**: Core search logic with multiple search type handlers
- **Api::V1::SearchController**: REST API endpoints with parameter validation  
- **AdvancedSearchController**: Web interface controller with Turbo support

### Frontend Components

- **AdvancedSearchComponent**: ViewComponent for search interface
- **advanced_search_controller.js**: Stimulus controller for interactivity
- **Advanced search views**: ERB templates with Turbo frames

### Configuration

- **Elasticsearch**: Configured with environment-based indices
- **SearchConfig**: Centralized configuration for search types and filters
- **Routes**: RESTful routing with proper parameter handling

### Data Models Integration

- **Verse**: Multiple Arabic script fields, relationships to words/translations
- **Word**: Morphological data (root, stem, lemma), character types
- **Translation**: Multi-language verse translations
- **Morphology::Word**: Grammatical analysis and concepts
- **Root/Stem/Lemma**: Morphological entities with statistical data

## Performance Considerations

### Elasticsearch Integration
- Environment-specific indices for scalability
- Configurable timeouts and connection pooling
- Proper error handling and fallback mechanisms

### Query Optimization
- Limited result sets (50 verses, 30 tafsirs per query)
- Efficient database queries with proper indexing
- Smart caching for repeated searches

### UI Performance
- Debounced search suggestions (300ms)
- Turbo frame updates for fast result loading
- Progressive enhancement with JavaScript

## Testing

### Test Coverage
- Service layer tests (`test/services/search/`)
- API controller tests (`test/controllers/api/v1/`)
- Parameter validation and error handling
- Search type functionality verification

### Manual Testing Checklist
- [ ] Text search with Arabic and English queries
- [ ] Morphology search with different categories
- [ ] Root/lemma/stem searches
- [ ] Pattern search with regex
- [ ] Combined search deduplication
- [ ] Filter combinations
- [ ] API parameter validation
- [ ] Error handling scenarios

## Deployment Notes

### Requirements
- Ruby 3.3.3+ (Rails 7.0.8.4)
- PostgreSQL 14+ with quran_dev database
- Elasticsearch 7.0+ (optional, fallback to database)
- Redis for caching

### Environment Variables
```bash
ELASTICSEARCH_URL=localhost:9200  # Elasticsearch connection
```

### Database Setup
Ensure both databases are available:
- `quran_community_tarteel`: User accounts, permissions
- `quran_dev`: Quranic data (required for search)

## Future Enhancements

### Advanced Semantic Search
- Integration with sentence transformers
- Embedding-based similarity search
- Multi-language semantic matching

### Search Analytics
- Query logging and analysis
- Popular search terms tracking
- Performance monitoring

### Enhanced Morphology
- Deeper grammatical analysis
- Syntax tree searching
- Advanced linguistic features

### Real-time Features
- Live search as you type
- Collaborative search sessions
- Search result sharing

## Troubleshooting

### Common Issues

1. **Empty Results**: Check database connectivity and ensure `quran_dev` database is loaded
2. **Slow Performance**: Verify Elasticsearch is running and properly indexed
3. **Search Errors**: Check logs for specific error messages and parameter validation
4. **UI Issues**: Ensure JavaScript is enabled and Stimulus controllers are loaded

### Debug Tools
- Rails console for service testing: `Search::AdvancedSearchService.new('test').search`
- API testing with curl or Postman
- Browser developer tools for frontend issues
- Rails logs for backend debugging

---

This system provides a comprehensive, scalable, and user-friendly way to search across QUL's vast Quranic resources with multiple search paradigms and advanced filtering capabilities.