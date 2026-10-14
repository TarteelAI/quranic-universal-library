--
-- PostgreSQL database dump
--

-- Dumped from database version 14.3
-- Dumped by pg_dump version 17.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: audio; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA audio;


--
-- Name: content; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA content;


--
-- Name: i18n; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA i18n;


--
-- Name: media; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA media;


--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- Name: quran; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA quran;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: file; Type: TABLE; Schema: audio; Owner: -
--

CREATE TABLE audio.file (
    file_id integer NOT NULL,
    recitation_id integer NOT NULL,
    ayah_key text NOT NULL,
    format text NOT NULL,
    duration real,
    mime_type text NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    url text,
    segments_stats json,
    segments text[]
);


--
-- Name: _file_file_id_seq; Type: SEQUENCE; Schema: audio; Owner: -
--

CREATE SEQUENCE audio._file_file_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: _file_file_id_seq; Type: SEQUENCE OWNED BY; Schema: audio; Owner: -
--

ALTER SEQUENCE audio._file_file_id_seq OWNED BY audio.file.file_id;


--
-- Name: reciter; Type: TABLE; Schema: audio; Owner: -
--

CREATE TABLE audio.reciter (
    reciter_id integer NOT NULL,
    path text,
    slug text,
    english text NOT NULL,
    arabic text NOT NULL,
    description text
);


--
-- Name: _reciter_reciter_id_seq; Type: SEQUENCE; Schema: audio; Owner: -
--

CREATE SEQUENCE audio._reciter_reciter_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: _reciter_reciter_id_seq; Type: SEQUENCE OWNED BY; Schema: audio; Owner: -
--

ALTER SEQUENCE audio._reciter_reciter_id_seq OWNED BY audio.reciter.reciter_id;


--
-- Name: style; Type: TABLE; Schema: audio; Owner: -
--

CREATE TABLE audio.style (
    style_id integer NOT NULL,
    path text NOT NULL,
    slug text NOT NULL,
    english text NOT NULL,
    arabic text NOT NULL
);


--
-- Name: _style_style_id_seq; Type: SEQUENCE; Schema: audio; Owner: -
--

CREATE SEQUENCE audio._style_style_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: _style_style_id_seq; Type: SEQUENCE OWNED BY; Schema: audio; Owner: -
--

ALTER SEQUENCE audio._style_style_id_seq OWNED BY audio.style.style_id;


--
-- Name: recitation; Type: TABLE; Schema: audio; Owner: -
--

CREATE TABLE audio.recitation (
    recitation_id integer NOT NULL,
    reciter_id integer NOT NULL,
    style_id integer,
    is_enabled boolean DEFAULT true NOT NULL
);


--
-- Name: recitation_recitation_id_seq; Type: SEQUENCE; Schema: audio; Owner: -
--

CREATE SEQUENCE audio.recitation_recitation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recitation_recitation_id_seq; Type: SEQUENCE OWNED BY; Schema: audio; Owner: -
--

ALTER SEQUENCE audio.recitation_recitation_id_seq OWNED BY audio.recitation.recitation_id;


--
-- Name: reciter_reciter_id_seq; Type: SEQUENCE; Schema: audio; Owner: -
--

CREATE SEQUENCE audio.reciter_reciter_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: author; Type: TABLE; Schema: content; Owner: -
--

CREATE TABLE content.author (
    author_id integer NOT NULL,
    url text[],
    name text NOT NULL
);


--
-- Name: _author_author_id_seq; Type: SEQUENCE; Schema: content; Owner: -
--

CREATE SEQUENCE content._author_author_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: _author_author_id_seq; Type: SEQUENCE OWNED BY; Schema: content; Owner: -
--

ALTER SEQUENCE content._author_author_id_seq OWNED BY content.author.author_id;


--
-- Name: tafsir; Type: TABLE; Schema: content; Owner: -
--

CREATE TABLE content.tafsir (
    tafsir_id integer NOT NULL,
    resource_id integer NOT NULL,
    text text NOT NULL
);


--
-- Name: _tafsir_tafsir_id_seq; Type: SEQUENCE; Schema: content; Owner: -
--

CREATE SEQUENCE content._tafsir_tafsir_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: _tafsir_tafsir_id_seq; Type: SEQUENCE OWNED BY; Schema: content; Owner: -
--

ALTER SEQUENCE content._tafsir_tafsir_id_seq OWNED BY content.tafsir.tafsir_id;


--
-- Name: resource_resource_id_seq; Type: SEQUENCE; Schema: content; Owner: -
--

CREATE SEQUENCE content.resource_resource_id_seq
    START WITH 255
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: resource; Type: TABLE; Schema: content; Owner: -
--

CREATE TABLE content.resource (
    resource_id integer DEFAULT nextval('content.resource_resource_id_seq'::regclass) NOT NULL,
    type text NOT NULL,
    sub_type text NOT NULL,
    cardinality_type text DEFAULT '1_ayah'::text NOT NULL,
    language_code text NOT NULL,
    slug text NOT NULL,
    is_available boolean DEFAULT true NOT NULL,
    description text,
    author_id integer,
    source_id integer,
    name text NOT NULL
);


--
-- Name: resource_api_version; Type: TABLE; Schema: content; Owner: -
--

CREATE TABLE content.resource_api_version (
    resource_id integer NOT NULL,
    v1_is_enabled boolean DEFAULT false NOT NULL,
    v1_is_default boolean,
    v1_separator boolean,
    v1_label boolean,
    v1_order integer,
    v1_id integer,
    v1_name text,
    v2_is_enabled boolean DEFAULT false NOT NULL,
    v2_is_default boolean,
    v2_weighted real DEFAULT 0.618 NOT NULL
);


--
-- Name: source; Type: TABLE; Schema: content; Owner: -
--

CREATE TABLE content.source (
    source_id integer NOT NULL,
    name text NOT NULL,
    url text
);


--
-- Name: surah_infos; Type: TABLE; Schema: content; Owner: -
--

CREATE TABLE content.surah_infos (
    id integer NOT NULL,
    language_code character varying,
    description text,
    surah_id integer,
    content_source text,
    short_description text
);


--
-- Name: surah_infos_id_seq; Type: SEQUENCE; Schema: content; Owner: -
--

CREATE SEQUENCE content.surah_infos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: surah_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: content; Owner: -
--

ALTER SEQUENCE content.surah_infos_id_seq OWNED BY content.surah_infos.id;


--
-- Name: tafsir_ayah; Type: TABLE; Schema: content; Owner: -
--

CREATE TABLE content.tafsir_ayah (
    tafsir_id integer NOT NULL,
    ayah_key text NOT NULL
);


--
-- Name: translation; Type: TABLE; Schema: content; Owner: -
--

CREATE TABLE content.translation (
    resource_id integer NOT NULL,
    ayah_key text NOT NULL,
    text text NOT NULL
);


--
-- Name: transliteration; Type: TABLE; Schema: content; Owner: -
--

CREATE TABLE content.transliteration (
    resource_id integer NOT NULL,
    ayah_key text NOT NULL,
    text text NOT NULL
);


--
-- Name: language; Type: TABLE; Schema: i18n; Owner: -
--

CREATE TABLE i18n.language (
    language_code text NOT NULL,
    unicode text,
    english text NOT NULL,
    direction text DEFAULT 'ltr'::text NOT NULL,
    priority integer DEFAULT 999 NOT NULL,
    beta boolean DEFAULT true NOT NULL,
    es_analyzer_default character varying
);


--
-- Name: content; Type: TABLE; Schema: media; Owner: -
--

CREATE TABLE media.content (
    resource_id integer NOT NULL,
    ayah_key character varying,
    url character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: content_resource_id_seq; Type: SEQUENCE; Schema: media; Owner: -
--

CREATE SEQUENCE media.content_resource_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_resource_id_seq; Type: SEQUENCE OWNED BY; Schema: media; Owner: -
--

ALTER SEQUENCE media.content_resource_id_seq OWNED BY media.content.resource_id;


--
-- Name: resource; Type: TABLE; Schema: media; Owner: -
--

CREATE TABLE media.resource (
    resource_id integer NOT NULL,
    name character varying,
    url character varying,
    provider character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: resource_resource_id_seq; Type: SEQUENCE; Schema: media; Owner: -
--

CREATE SEQUENCE media.resource_resource_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: resource_resource_id_seq; Type: SEQUENCE OWNED BY; Schema: media; Owner: -
--

ALTER SEQUENCE media.resource_resource_id_seq OWNED BY media.resource.resource_id;


--
-- Name: api_client_request_stats; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.api_client_request_stats (
    id bigint NOT NULL,
    api_client_id integer,
    date date,
    requests_count integer DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: api_client_request_stats_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.api_client_request_stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: api_client_request_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.api_client_request_stats_id_seq OWNED BY quran.api_client_request_stats.id;


--
-- Name: api_clients; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.api_clients (
    id bigint NOT NULL,
    name character varying,
    api_key character varying NOT NULL,
    kalimat_api_key character varying,
    internal_api boolean DEFAULT false,
    active boolean DEFAULT true,
    request_quota integer,
    requests_count integer,
    current_period_requests_count integer,
    current_period_ends_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: api_clients_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.api_clients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: api_clients_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.api_clients_id_seq OWNED BY quran.api_clients.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: arabic_arabic_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.arabic_arabic_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: arabic_transliterations; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.arabic_transliterations (
    id integer NOT NULL,
    word_id integer,
    verse_id integer,
    text character varying,
    indopak_text character varying,
    page_number integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    position_x integer,
    position_y integer,
    zoom double precision,
    ur_translation character varying,
    continuous boolean
);


--
-- Name: arabic_transliterations_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.arabic_transliterations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: arabic_transliterations_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.arabic_transliterations_id_seq OWNED BY quran.arabic_transliterations.id;


--
-- Name: audio_change_logs; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.audio_change_logs (
    id bigint NOT NULL,
    audio_recitation_id integer,
    date timestamp without time zone,
    mini_desc text,
    rss_desc text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: audio_change_logs_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.audio_change_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audio_change_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.audio_change_logs_id_seq OWNED BY quran.audio_change_logs.id;


--
-- Name: audio_chapter_audio_files; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.audio_chapter_audio_files (
    id bigint NOT NULL,
    chapter_id integer,
    audio_recitation_id integer,
    total_files integer,
    stream_count integer,
    download_count integer,
    file_size double precision,
    bit_rate integer,
    duration integer,
    file_name character varying,
    format character varying,
    mime_type character varying,
    meta_data jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    resource_content_id integer,
    duration_ms integer,
    audio_url character varying,
    timing_percentiles character varying[],
    segments_count integer DEFAULT 0
);


--
-- Name: audio_chapter_audio_files_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.audio_chapter_audio_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audio_chapter_audio_files_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.audio_chapter_audio_files_id_seq OWNED BY quran.audio_chapter_audio_files.id;


--
-- Name: audio_files; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.audio_files (
    id integer NOT NULL,
    verse_id integer,
    url text,
    duration double precision,
    mime_type character varying,
    format character varying,
    is_enabled boolean,
    recitation_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    verse_key character varying,
    chapter_id integer,
    verse_number integer,
    juz_number integer,
    hizb_number integer,
    rub_el_hizb_number integer,
    page_number integer,
    ruku_number integer,
    surah_ruku_number integer,
    manzil_number integer,
    audio_url character varying,
    words_count integer,
    segments_count integer DEFAULT 0,
    bit_rate double precision,
    duration_ms integer,
    meta_data jsonb DEFAULT '{}'::jsonb,
    file_size integer,
    has_repetition boolean DEFAULT false,
    repeated_segments character varying,
    segments jsonb DEFAULT '[]'::jsonb
);


--
-- Name: audio_files_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.audio_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audio_files_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.audio_files_id_seq OWNED BY quran.audio_files.id;


--
-- Name: audio_recitations; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.audio_recitations (
    id bigint NOT NULL,
    name character varying,
    arabic_name character varying,
    relative_path character varying,
    format character varying,
    section_id integer,
    description text,
    files_count integer,
    resource_content_id integer,
    recitation_style_id integer,
    reciter_id integer,
    approved boolean,
    home integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    priority integer,
    segments_count integer,
    files_size double precision,
    qirat_type_id integer,
    segment_locked boolean DEFAULT false,
    riwayah_id integer
);


--
-- Name: audio_recitations_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.audio_recitations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audio_recitations_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.audio_recitations_id_seq OWNED BY quran.audio_recitations.id;


--
-- Name: audio_related_recitations; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.audio_related_recitations (
    id bigint NOT NULL,
    audio_recitation_id integer,
    related_audio_recitation_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: audio_related_recitations_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.audio_related_recitations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audio_related_recitations_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.audio_related_recitations_id_seq OWNED BY quran.audio_related_recitations.id;


--
-- Name: audio_sections; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.audio_sections (
    id bigint NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: audio_sections_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.audio_sections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audio_sections_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.audio_sections_id_seq OWNED BY quran.audio_sections.id;


--
-- Name: audio_segments; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.audio_segments (
    id bigint NOT NULL,
    audio_file_id bigint,
    audio_recitation_id bigint,
    chapter_id bigint,
    verse_id bigint,
    verse_key character varying,
    verse_number integer,
    timestamp_from integer,
    timestamp_to integer,
    timestamp_median integer,
    segments jsonb DEFAULT '[]'::jsonb,
    duration integer,
    duration_ms integer,
    percentile double precision,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    silent_duration integer,
    relative_segments jsonb DEFAULT '[]'::jsonb,
    relative_silent_duration integer,
    repeated_segments character varying,
    has_repetition boolean DEFAULT false,
    segments_count integer DEFAULT 0,
    letter_segments jsonb
);


--
-- Name: audio_segments_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.audio_segments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audio_segments_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.audio_segments_id_seq OWNED BY quran.audio_segments.id;


--
-- Name: authors; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.authors (
    id integer NOT NULL,
    name character varying,
    url character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    resource_contents_count integer DEFAULT 0
);


--
-- Name: authors_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.authors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: authors_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.authors_id_seq OWNED BY quran.authors.id;


--
-- Name: ayah; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.ayah (
    ayah_index integer NOT NULL,
    surah_id integer,
    ayah_num integer,
    page_num integer,
    juz_num integer,
    hizb_num integer,
    rub_num integer,
    text text,
    ayah_key text NOT NULL,
    sajdah text
);


--
-- Name: ayah_texts; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.ayah_texts (
    script_id integer NOT NULL,
    ayah_id integer NOT NULL,
    text text NOT NULL
);


--
-- Name: ayah_themes; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.ayah_themes (
    id bigint NOT NULL,
    chapter_id integer,
    verse_number_from integer,
    verse_number_to integer,
    verse_key_from character varying,
    verse_key_to character varying,
    verse_id_from integer,
    verse_id_to integer,
    verses_count integer,
    theme character varying,
    keywords jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    book_id integer
);


--
-- Name: ayah_themes_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.ayah_themes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ayah_themes_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.ayah_themes_id_seq OWNED BY quran.ayah_themes.id;


--
-- Name: books; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.books (
    id bigint NOT NULL,
    resource_content_id integer,
    author_id integer,
    name character varying,
    publisher character varying,
    country character varying,
    published_year integer,
    volumes_count integer,
    isbn character varying,
    source_url character varying,
    notes text,
    meta_data jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: books_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.books_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: books_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.books_id_seq OWNED BY quran.books.id;


--
-- Name: chapter_infos; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.chapter_infos (
    id integer NOT NULL,
    chapter_id integer,
    text text,
    source character varying,
    short_text text,
    language_id integer,
    resource_content_id integer,
    language_name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: chapter_infos_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.chapter_infos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chapter_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.chapter_infos_id_seq OWNED BY quran.chapter_infos.id;


--
-- Name: chapters; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.chapters (
    id integer NOT NULL,
    bismillah_pre boolean,
    revelation_order integer,
    revelation_place character varying,
    name_complex character varying,
    name_arabic character varying,
    name_simple character varying,
    verses_count integer,
    chapter_number integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    rukus_count integer,
    hizbs_count integer,
    rub_el_hizbs_count integer,
    v1_chapter_glyph_code character varying,
    v4_chapter_glyph_code character varying,
    color_header_chapter_glyph_code character varying,
    v2_chapter_glyph_code character varying,
    pages jsonb DEFAULT '[]'::jsonb
);


--
-- Name: chapters_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.chapters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chapters_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.chapters_id_seq OWNED BY quran.chapters.id;


--
-- Name: char_type; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.char_type (
    char_type_id integer NOT NULL,
    name text NOT NULL,
    description text,
    parent_id integer
);


--
-- Name: char_type_char_type_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.char_type_char_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: char_type_char_type_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.char_type_char_type_id_seq OWNED BY quran.char_type.char_type_id;


--
-- Name: char_types; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.char_types (
    id integer NOT NULL,
    name character varying,
    parent_id integer,
    description text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: char_types_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.char_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: char_types_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.char_types_id_seq OWNED BY quran.char_types.id;


--
-- Name: corpus_word_forms; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.corpus_word_forms (
    id bigint NOT NULL,
    word_id bigint,
    name character varying,
    arabic character varying,
    arabic_simple character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: corpus_word_forms_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.corpus_word_forms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: corpus_word_forms_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.corpus_word_forms_id_seq OWNED BY quran.corpus_word_forms.id;


--
-- Name: corpus_word_grammars; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.corpus_word_grammars (
    id bigint NOT NULL,
    word_id bigint,
    "position" integer,
    text character varying,
    type character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: corpus_word_grammars_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.corpus_word_grammars_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: corpus_word_grammars_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.corpus_word_grammars_id_seq OWNED BY quran.corpus_word_grammars.id;


--
-- Name: counting_systems; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.counting_systems (
    id bigint NOT NULL,
    slug character varying NOT NULL,
    name_ar character varying NOT NULL,
    name_en character varying NOT NULL,
    total_ayahs integer,
    is_reference boolean DEFAULT false NOT NULL,
    description_ar text,
    description_en text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: counting_systems_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.counting_systems_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: counting_systems_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.counting_systems_id_seq OWNED BY quran.counting_systems.id;


--
-- Name: data_sources; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.data_sources (
    id integer NOT NULL,
    name character varying,
    url character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    resource_count integer DEFAULT 0,
    description text
);


--
-- Name: data_sources_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.data_sources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: data_sources_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.data_sources_id_seq OWNED BY quran.data_sources.id;


--
-- Name: dictionary_root_definitions; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.dictionary_root_definitions (
    id bigint NOT NULL,
    definition_type integer,
    description text,
    word_root_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: dictionary_root_definitions_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.dictionary_root_definitions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dictionary_root_definitions_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.dictionary_root_definitions_id_seq OWNED BY quran.dictionary_root_definitions.id;


--
-- Name: dictionary_root_examples; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.dictionary_root_examples (
    id bigint NOT NULL,
    word_arabic character varying,
    word_translation character varying,
    segment_arabic character varying,
    segment_translation character varying,
    segment_first_word_id integer,
    segment_last_word_id integer,
    segment_first_word_timestamp integer,
    segment_last_word_timestamp integer,
    word_id integer,
    word_root_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    verse_id integer
);


--
-- Name: dictionary_root_examples_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.dictionary_root_examples_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dictionary_root_examples_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.dictionary_root_examples_id_seq OWNED BY quran.dictionary_root_examples.id;


--
-- Name: dictionary_word_roots; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.dictionary_word_roots (
    id bigint NOT NULL,
    frequency integer,
    root_number integer,
    english_trilateral character varying,
    arabic_trilateral character varying,
    cover_url character varying,
    description text,
    root_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: dictionary_word_roots_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.dictionary_word_roots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dictionary_word_roots_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.dictionary_word_roots_id_seq OWNED BY quran.dictionary_word_roots.id;


--
-- Name: feedbacks; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.feedbacks (
    id bigint NOT NULL,
    name character varying,
    email character varying,
    url character varying,
    message text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: feedbacks_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.feedbacks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: feedbacks_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.feedbacks_id_seq OWNED BY quran.feedbacks.id;


--
-- Name: foot_notes; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.foot_notes (
    id integer NOT NULL,
    translation_id integer,
    text text,
    language_id integer,
    language_name character varying,
    resource_content_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: foot_notes_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.foot_notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: foot_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.foot_notes_id_seq OWNED BY quran.foot_notes.id;


--
-- Name: hizbs; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.hizbs (
    id bigint NOT NULL,
    hizb_number integer,
    verses_count integer,
    verse_mapping jsonb,
    first_verse_id integer,
    last_verse_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: hizbs_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.hizbs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hizbs_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.hizbs_id_seq OWNED BY quran.hizbs.id;


--
-- Name: images; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.images (
    id integer NOT NULL,
    verse_id integer,
    resource_content_id integer,
    width integer,
    url character varying,
    alt text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: images_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: images_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.images_id_seq OWNED BY quran.images.id;


--
-- Name: juzs; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.juzs (
    id integer NOT NULL,
    juz_number integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    verse_mapping json,
    first_verse_id integer,
    last_verse_id integer,
    verses_count integer
);


--
-- Name: juzs_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.juzs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: juzs_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.juzs_id_seq OWNED BY quran.juzs.id;


--
-- Name: languages; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.languages (
    id integer NOT NULL,
    name character varying,
    iso_code character varying,
    native_name character varying,
    direction character varying,
    es_analyzer_default character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    translations_count integer,
    es_indexes jsonb DEFAULT '[]'::jsonb
);


--
-- Name: languages_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.languages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: languages_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.languages_id_seq OWNED BY quran.languages.id;


--
-- Name: lemma; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.lemma (
    lemma_id integer NOT NULL,
    value character varying(50) NOT NULL,
    clean character varying(50) NOT NULL
);


--
-- Name: lemma_lemma_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.lemma_lemma_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: lemma_lemma_id_seq1; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.lemma_lemma_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: lemma_lemma_id_seq1; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.lemma_lemma_id_seq1 OWNED BY quran.lemma.lemma_id;


--
-- Name: lemmas; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.lemmas (
    id integer NOT NULL,
    text_madani character varying,
    text_clean character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    words_count integer,
    uniq_words_count integer,
    en_translations jsonb DEFAULT '[]'::jsonb NOT NULL
);


--
-- Name: lemmas_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.lemmas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: lemmas_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.lemmas_id_seq OWNED BY quran.lemmas.id;


--
-- Name: manzils; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.manzils (
    id bigint NOT NULL,
    manzil_number integer,
    verses_count integer,
    verse_mapping json,
    first_verse_id integer,
    last_verse_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: manzils_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.manzils_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: manzils_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.manzils_id_seq OWNED BY quran.manzils.id;


--
-- Name: media_contents; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.media_contents (
    id integer NOT NULL,
    resource_type character varying,
    resource_id integer,
    url text,
    duration character varying,
    embed_text text,
    provider character varying,
    language_id integer,
    language_name character varying,
    author_name character varying,
    resource_content_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: media_contents_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.media_contents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: media_contents_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.media_contents_id_seq OWNED BY quran.media_contents.id;


--
-- Name: morphology_dependency_graph_node_edges; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.morphology_dependency_graph_node_edges (
    id bigint NOT NULL,
    source_id integer,
    target_id integer,
    relation character varying,
    type integer DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: morphology_dependency_graph_node_edges_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.morphology_dependency_graph_node_edges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: morphology_dependency_graph_node_edges_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.morphology_dependency_graph_node_edges_id_seq OWNED BY quran.morphology_dependency_graph_node_edges.id;


--
-- Name: morphology_dependency_graph_nodes; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.morphology_dependency_graph_nodes (
    id bigint NOT NULL,
    graph_id bigint,
    resource_type character varying,
    resource_id bigint,
    segment_id integer,
    pos character varying,
    type integer,
    value character varying,
    number integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: morphology_dependency_graph_nodes_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.morphology_dependency_graph_nodes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: morphology_dependency_graph_nodes_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.morphology_dependency_graph_nodes_id_seq OWNED BY quran.morphology_dependency_graph_nodes.id;


--
-- Name: morphology_dependency_graphs; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.morphology_dependency_graphs (
    id bigint NOT NULL,
    chapter_number integer NOT NULL,
    verse_number integer NOT NULL,
    graph_number integer DEFAULT 1 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    verse_id integer,
    review_status integer
);


--
-- Name: morphology_dependency_graphs_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.morphology_dependency_graphs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: morphology_dependency_graphs_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.morphology_dependency_graphs_id_seq OWNED BY quran.morphology_dependency_graphs.id;


--
-- Name: morphology_derived_words; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.morphology_derived_words (
    id bigint NOT NULL,
    verse_id bigint,
    word_id bigint,
    derived_word_id bigint,
    word_verb_from_id bigint,
    form_name character varying,
    en_transliteration character varying,
    en_translation character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: morphology_derived_words_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.morphology_derived_words_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: morphology_derived_words_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.morphology_derived_words_id_seq OWNED BY quran.morphology_derived_words.id;


--
-- Name: morphology_dictionary_term_translations; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.morphology_dictionary_term_translations (
    id bigint NOT NULL,
    term_id bigint NOT NULL,
    locale character varying NOT NULL,
    title character varying,
    definition text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: morphology_dictionary_term_translations_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.morphology_dictionary_term_translations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: morphology_dictionary_term_translations_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.morphology_dictionary_term_translations_id_seq OWNED BY quran.morphology_dictionary_term_translations.id;


--
-- Name: morphology_dictionary_terms; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.morphology_dictionary_terms (
    id bigint NOT NULL,
    category character varying,
    key character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: morphology_dictionary_terms_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.morphology_dictionary_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: morphology_dictionary_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.morphology_dictionary_terms_id_seq OWNED BY quran.morphology_dictionary_terms.id;


--
-- Name: morphology_grammar_concepts; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.morphology_grammar_concepts (
    id bigint NOT NULL,
    english character varying,
    arabic character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: morphology_grammar_concepts_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.morphology_grammar_concepts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: morphology_grammar_concepts_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.morphology_grammar_concepts_id_seq OWNED BY quran.morphology_grammar_concepts.id;


--
-- Name: morphology_grammar_patterns; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.morphology_grammar_patterns (
    id bigint NOT NULL,
    english character varying,
    arabic character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: morphology_grammar_patterns_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.morphology_grammar_patterns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: morphology_grammar_patterns_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.morphology_grammar_patterns_id_seq OWNED BY quran.morphology_grammar_patterns.id;


--
-- Name: morphology_grammar_term_translations; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.morphology_grammar_term_translations (
    id bigint NOT NULL,
    grammar_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    title character varying,
    description text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: morphology_grammar_term_translations_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.morphology_grammar_term_translations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: morphology_grammar_term_translations_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.morphology_grammar_term_translations_id_seq OWNED BY quran.morphology_grammar_term_translations.id;


--
-- Name: morphology_grammar_terms; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.morphology_grammar_terms (
    id bigint NOT NULL,
    category character varying,
    term character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    arabic character varying,
    english character varying,
    term_type integer DEFAULT 1,
    corpus_link character varying
);


--
-- Name: morphology_grammar_terms_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.morphology_grammar_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: morphology_grammar_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.morphology_grammar_terms_id_seq OWNED BY quran.morphology_grammar_terms.id;


--
-- Name: morphology_sentences; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.morphology_sentences (
    id bigint NOT NULL,
    sentence_number integer NOT NULL,
    chapter_id integer,
    first_verse_id integer,
    last_verse_id integer,
    verses_count integer DEFAULT 0,
    tokens_count integer DEFAULT 0,
    words_count integer DEFAULT 0,
    text_uthmani text,
    text_qpc_hafs text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    text_digital_khatt text
);


--
-- Name: morphology_sentences_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.morphology_sentences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: morphology_sentences_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.morphology_sentences_id_seq OWNED BY quran.morphology_sentences.id;


--
-- Name: morphology_word_grammar_concepts; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.morphology_word_grammar_concepts (
    id bigint NOT NULL,
    word_id bigint,
    grammar_concept_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: morphology_word_grammar_concepts_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.morphology_word_grammar_concepts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: morphology_word_grammar_concepts_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.morphology_word_grammar_concepts_id_seq OWNED BY quran.morphology_word_grammar_concepts.id;


--
-- Name: morphology_word_segments; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.morphology_word_segments (
    id bigint NOT NULL,
    word_id bigint,
    root_id bigint,
    topic_id bigint,
    lemma_id bigint,
    grammar_concept_id bigint,
    grammar_role_id bigint,
    grammar_sub_role_id bigint,
    grammar_term_id bigint,
    grammar_term_key character varying,
    grammar_term_name character varying,
    part_of_speech_key character varying,
    part_of_speech_name character varying,
    "position" integer,
    text_uthmani character varying,
    grammar_term_desc_english character varying,
    grammar_term_desc_arabic character varying,
    pos_tags character varying,
    root_name character varying,
    lemma_name character varying,
    verb_form character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    hidden boolean,
    segment_type character varying,
    person_type character varying,
    voice_type character varying,
    gender_type character varying,
    number_type character varying,
    aspect_type character varying,
    mood_type character varying,
    derivation_type character varying,
    state_type character varying,
    case_type character varying,
    pronoun_type character varying,
    special_type character varying,
    text_qpc_hafs character varying
);


--
-- Name: morphology_word_segments_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.morphology_word_segments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: morphology_word_segments_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.morphology_word_segments_id_seq OWNED BY quran.morphology_word_segments.id;


--
-- Name: morphology_word_tokens; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.morphology_word_tokens (
    id bigint NOT NULL,
    sentence_id integer,
    word_id integer,
    morphology_word_id integer,
    root_id integer,
    lemma_id integer,
    token_type integer DEFAULT 0 NOT NULL,
    location character varying,
    chapter_number integer,
    verse_number integer,
    word_number integer,
    position_in_word integer,
    position_in_sentence integer,
    word_position_in_sentence integer,
    text_uthmani character varying,
    text_qpc_hafs character varying,
    text_imlaai character varying,
    phonetic character varying,
    translation_en character varying,
    pos_key character varying,
    segment_type character varying,
    lemma_name character varying,
    root_name character varying,
    verb_form character varying,
    verb_aspect character varying,
    verb_mood character varying,
    verb_voice character varying,
    nominal_case character varying,
    nominal_state character varying,
    derived_noun_type character varying,
    special_group character varying,
    prefix_type character varying,
    suffix_type character varying,
    pgn character varying,
    person character varying,
    gender character varying,
    number character varying,
    features character varying,
    rel_label character varying,
    rel_governor character varying,
    ref_token_position integer,
    head_token_id integer,
    dependent_is_phrase boolean DEFAULT false,
    head_is_phrase boolean DEFAULT false,
    is_constituent integer,
    constituent_span_start integer,
    constituent_span_end integer,
    constituent_text character varying,
    constituent_label character varying,
    source_meta jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    text_digital_khatt character varying
);


--
-- Name: morphology_word_tokens_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.morphology_word_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: morphology_word_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.morphology_word_tokens_id_seq OWNED BY quran.morphology_word_tokens.id;


--
-- Name: morphology_word_verb_forms; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.morphology_word_verb_forms (
    id bigint NOT NULL,
    word_id bigint,
    name character varying,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: morphology_word_verb_forms_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.morphology_word_verb_forms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: morphology_word_verb_forms_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.morphology_word_verb_forms_id_seq OWNED BY quran.morphology_word_verb_forms.id;


--
-- Name: morphology_words; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.morphology_words (
    id bigint NOT NULL,
    word_id bigint,
    verse_id bigint,
    grammar_pattern_id bigint,
    grammar_base_pattern_id bigint,
    words_count_for_root integer,
    words_count_for_lemma integer,
    words_count_for_stem integer,
    location character varying,
    description text,
    "case" character varying,
    case_reason character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: morphology_words_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.morphology_words_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: morphology_words_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.morphology_words_id_seq OWNED BY quran.morphology_words.id;


--
-- Name: mushaf_juzs; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.mushaf_juzs (
    id bigint NOT NULL,
    mushaf_type integer,
    mushaf_id integer,
    juz_id integer,
    verse_mapping jsonb,
    juz_number integer,
    verses_count integer,
    first_verse_id integer,
    last_verse_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: mushaf_juzs_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.mushaf_juzs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mushaf_juzs_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.mushaf_juzs_id_seq OWNED BY quran.mushaf_juzs.id;


--
-- Name: mushaf_pages; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.mushaf_pages (
    id bigint NOT NULL,
    page_number integer,
    verse_mapping json,
    first_verse_id integer,
    last_verse_id integer,
    verses_count integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    mushaf_id integer,
    first_word_id integer,
    last_word_id integer,
    lines_count integer,
    text text
);


--
-- Name: mushaf_pages_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.mushaf_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mushaf_pages_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.mushaf_pages_id_seq OWNED BY quran.mushaf_pages.id;


--
-- Name: mushaf_words; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.mushaf_words (
    id bigint NOT NULL,
    mushaf_id integer,
    word_id integer,
    verse_id integer,
    text text,
    char_type_id integer,
    char_type_name character varying,
    line_number integer,
    page_number integer,
    position_in_verse integer,
    position_in_line integer,
    position_in_page integer,
    css_style character varying,
    css_class character varying
);


--
-- Name: mushaf_words_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.mushaf_words_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mushaf_words_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.mushaf_words_id_seq OWNED BY quran.mushaf_words.id;


--
-- Name: mushafs; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.mushafs (
    id bigint NOT NULL,
    name character varying NOT NULL,
    description text,
    lines_per_page integer,
    is_default boolean DEFAULT false,
    default_font_name character varying,
    pages_count integer,
    qirat_type_id integer,
    enabled boolean,
    resource_content_id integer,
    riwayah_id integer
);


--
-- Name: mushafs_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.mushafs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mushafs_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.mushafs_id_seq OWNED BY quran.mushafs.id;


--
-- Name: mushas_pages; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.mushas_pages (
    id bigint NOT NULL,
    page_number integer,
    verse_mapping json,
    first_verse_id integer,
    last_verse_id integer,
    verses_count integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: mushas_pages_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.mushas_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mushas_pages_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.mushas_pages_id_seq OWNED BY quran.mushas_pages.id;


--
-- Name: navigation_search_records; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.navigation_search_records (
    id bigint NOT NULL,
    result_type character varying,
    searchable_record_type character varying,
    searchable_record_id bigint,
    name character varying,
    key character varying,
    text character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: navigation_search_records_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.navigation_search_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: navigation_search_records_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.navigation_search_records_id_seq OWNED BY quran.navigation_search_records.id;


--
-- Name: qiraat; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.qiraat (
    id bigint NOT NULL,
    slug character varying NOT NULL,
    name_ar character varying NOT NULL,
    name_en character varying NOT NULL,
    counting_system_id integer,
    "position" integer,
    description text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: qiraat_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.qiraat_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: qiraat_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.qiraat_id_seq OWNED BY quran.qiraat.id;


--
-- Name: riwayat; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.riwayat (
    id bigint NOT NULL,
    name character varying,
    description text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    recitations_count integer DEFAULT 0,
    slug character varying,
    qiraah_id integer,
    name_ar character varying,
    name_en character varying,
    enabled boolean DEFAULT false NOT NULL,
    default_numbering_id integer,
    meta_data jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: qirat_types; Type: VIEW; Schema: quran; Owner: -
--

CREATE VIEW quran.qirat_types AS
 SELECT riwayat.id,
    riwayat.name,
    riwayat.description,
    riwayat.created_at,
    riwayat.updated_at,
    riwayat.recitations_count,
    riwayat.slug,
    riwayat.qiraah_id,
    riwayat.name_ar,
    riwayat.name_en,
    riwayat.enabled,
    riwayat.default_numbering_id,
    riwayat.meta_data
   FROM quran.riwayat;


--
-- Name: quran_script_by_verses; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.quran_script_by_verses (
    id bigint NOT NULL,
    text character varying,
    qirat_id integer,
    resource_content_id integer,
    key character varying,
    verse_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    chapter_id integer,
    verse_number integer
);


--
-- Name: quran_script_by_verses_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.quran_script_by_verses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quran_script_by_verses_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.quran_script_by_verses_id_seq OWNED BY quran.quran_script_by_verses.id;


--
-- Name: quran_script_by_words; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.quran_script_by_words (
    id bigint NOT NULL,
    text character varying,
    qirat_id character varying,
    resource_content_id character varying,
    key character varying,
    word_id character varying,
    verse_id character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    chapter_id integer,
    verse_number integer,
    word_number integer
);


--
-- Name: quran_script_by_words_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.quran_script_by_words_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quran_script_by_words_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.quran_script_by_words_id_seq OWNED BY quran.quran_script_by_words.id;


--
-- Name: quran_scripts; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.quran_scripts (
    id bigint NOT NULL,
    text character varying,
    resource_content_id integer,
    occurrence_count character varying,
    script_name character varying,
    qirat_name character varying,
    record_type character varying,
    record_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: quran_scripts_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.quran_scripts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quran_scripts_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.quran_scripts_id_seq OWNED BY quran.quran_scripts.id;


--
-- Name: radio_station_audio_files; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.radio_station_audio_files (
    id bigint NOT NULL,
    radio_station_id integer,
    chapter_audio_file_id integer,
    chapter_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: radio_station_audio_files_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.radio_station_audio_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: radio_station_audio_files_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.radio_station_audio_files_id_seq OWNED BY quran.radio_station_audio_files.id;


--
-- Name: radio_stations; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.radio_stations (
    id bigint NOT NULL,
    name character varying,
    cover_image character varying,
    profile_picture character varying,
    description text,
    audio_recitation_id integer,
    priority integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    parent_id integer
);


--
-- Name: radio_stations_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.radio_stations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: radio_stations_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.radio_stations_id_seq OWNED BY quran.radio_stations.id;


--
-- Name: raw_data_ayah_records; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.raw_data_ayah_records (
    id bigint NOT NULL,
    verse_id integer,
    text text,
    text_cleaned text,
    processed boolean DEFAULT false,
    raw_resource_id integer,
    content_css_class character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: raw_data_ayah_records_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.raw_data_ayah_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: raw_data_ayah_records_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.raw_data_ayah_records_id_seq OWNED BY quran.raw_data_ayah_records.id;


--
-- Name: raw_data_resources; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.raw_data_resources (
    id bigint NOT NULL,
    name character varying,
    key character varying,
    sub_type character varying,
    language_id integer,
    lang_iso character varying,
    records_count integer DEFAULT 0,
    description text,
    resource_content_id integer,
    processed boolean DEFAULT false,
    content_css_class character varying,
    meta_data jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: raw_data_resources_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.raw_data_resources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: raw_data_resources_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.raw_data_resources_id_seq OWNED BY quran.raw_data_resources.id;


--
-- Name: recitation_styles; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.recitation_styles (
    id integer NOT NULL,
    name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    arabic character varying,
    slug character varying,
    description text,
    recitations_count integer DEFAULT 0
);


--
-- Name: recitation_styles_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.recitation_styles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recitation_styles_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.recitation_styles_id_seq OWNED BY quran.recitation_styles.id;


--
-- Name: recitations; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.recitations (
    id integer NOT NULL,
    reciter_id integer,
    resource_content_id integer,
    recitation_style_id integer,
    reciter_name character varying,
    style character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    qirat_type_id integer,
    segment_locked boolean DEFAULT true,
    files_count integer,
    segments_count integer DEFAULT 0,
    relative_path character varying,
    name character varying,
    approved boolean DEFAULT true,
    description text,
    gapless_recitation_id integer,
    riwayah_id integer
);


--
-- Name: recitations_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.recitations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recitations_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.recitations_id_seq OWNED BY quran.recitations.id;


--
-- Name: reciters; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.reciters (
    id integer NOT NULL,
    name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    recitations_count integer DEFAULT 0,
    profile_picture character varying,
    bio text,
    cover_image character varying
);


--
-- Name: reciters_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.reciters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reciters_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.reciters_id_seq OWNED BY quran.reciters.id;


--
-- Name: related_topics; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.related_topics (
    id bigint NOT NULL,
    topic_id integer,
    related_topic_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: related_topics_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.related_topics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: related_topics_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.related_topics_id_seq OWNED BY quran.related_topics.id;


--
-- Name: resource_content_stats; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.resource_content_stats (
    id integer NOT NULL,
    resource_content_id integer,
    download_count integer,
    platform character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: resource_content_stats_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.resource_content_stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: resource_content_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.resource_content_stats_id_seq OWNED BY quran.resource_content_stats.id;


--
-- Name: resource_contents; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.resource_contents (
    id integer NOT NULL,
    approved boolean,
    author_id integer,
    data_source_id integer,
    author_name character varying,
    resource_type_name character varying,
    sub_type character varying,
    name character varying,
    description text,
    cardinality_type character varying,
    language_id integer,
    language_name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    slug character varying,
    mobile_translation_id integer,
    priority integer,
    resource_info text,
    resource_id character varying,
    meta_data jsonb DEFAULT '{}'::jsonb,
    resource_type character varying,
    sqlite_db character varying,
    sqlite_db_generated_at timestamp without time zone,
    records_count integer DEFAULT 0
);


--
-- Name: resource_contents_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.resource_contents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: resource_contents_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.resource_contents_id_seq OWNED BY quran.resource_contents.id;


--
-- Name: resource_tags; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.resource_tags (
    id bigint NOT NULL,
    tag_id integer,
    resource_id integer,
    resource_type character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: resource_tags_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.resource_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: resource_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.resource_tags_id_seq OWNED BY quran.resource_tags.id;


--
-- Name: riwayat_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.riwayat_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: riwayat_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.riwayat_id_seq OWNED BY quran.riwayat.id;


--
-- Name: root; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.root (
    root_id integer NOT NULL,
    value character varying(50) NOT NULL
);


--
-- Name: root_details; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.root_details (
    id bigint NOT NULL,
    token_id integer,
    root_id integer,
    language_id integer,
    resource_content_id integer,
    text text,
    meta_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: root_details_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.root_details_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: root_details_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.root_details_id_seq OWNED BY quran.root_details.id;


--
-- Name: root_root_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.root_root_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: root_root_id_seq1; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.root_root_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: root_root_id_seq1; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.root_root_id_seq1 OWNED BY quran.root.root_id;


--
-- Name: roots; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.roots (
    id integer NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    words_count integer,
    uniq_words_count integer,
    text_clean character varying,
    text_uthmani character varying,
    english_trilateral character varying,
    arabic_trilateral character varying,
    en_translations jsonb,
    ur_translations jsonb,
    dictionary_image_path character varying
);


--
-- Name: roots_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.roots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roots_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.roots_id_seq OWNED BY quran.roots.id;


--
-- Name: rub_el_hizbs; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.rub_el_hizbs (
    id bigint NOT NULL,
    rub_el_hizb_number integer,
    verses_count integer,
    verse_mapping json,
    first_verse_id integer,
    last_verse_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: rub_el_hizbs_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.rub_el_hizbs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rub_el_hizbs_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.rub_el_hizbs_id_seq OWNED BY quran.rub_el_hizbs.id;


--
-- Name: rukus; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.rukus (
    id bigint NOT NULL,
    ruku_number integer,
    surah_ruku_number integer,
    verse_mapping json,
    verses_count integer,
    first_verse_id integer,
    last_verse_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: rukus_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.rukus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rukus_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.rukus_id_seq OWNED BY quran.rukus.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: scripts; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.scripts (
    id bigint NOT NULL,
    slug character varying NOT NULL,
    name character varying NOT NULL,
    riwayah_id integer,
    kind character varying DEFAULT 'unicode'::character varying NOT NULL,
    storage character varying DEFAULT 'rows'::character varying NOT NULL,
    column_name character varying,
    font_family character varying,
    font_css_class character varying,
    font_file_url character varying,
    source_package character varying,
    source_sha256 character varying,
    text_sha256 character varying,
    release_year integer,
    licence character varying,
    word_resource_content_id integer,
    ayah_resource_content_id integer,
    enabled boolean DEFAULT true NOT NULL,
    meta_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: scripts_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.scripts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scripts_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.scripts_id_seq OWNED BY quran.scripts.id;


--
-- Name: slugs; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.slugs (
    id bigint NOT NULL,
    chapter_id bigint,
    slug character varying,
    locale character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    is_default boolean DEFAULT false,
    name character varying,
    language_priority integer,
    language_id integer
);


--
-- Name: slugs_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.slugs_id_seq OWNED BY quran.slugs.id;


--
-- Name: stem; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.stem (
    stem_id integer NOT NULL,
    value character varying(50) NOT NULL,
    clean character varying(50) NOT NULL
);


--
-- Name: stem_stem_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.stem_stem_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stem_stem_id_seq1; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.stem_stem_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stem_stem_id_seq1; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.stem_stem_id_seq1 OWNED BY quran.stem.stem_id;


--
-- Name: stems; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.stems (
    id integer NOT NULL,
    text_madani character varying,
    text_clean character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    words_count integer,
    uniq_words_count integer
);


--
-- Name: stems_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.stems_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stems_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.stems_id_seq OWNED BY quran.stems.id;


--
-- Name: surah; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.surah (
    surah_id integer NOT NULL,
    ayat integer NOT NULL,
    bismillah_pre boolean NOT NULL,
    revelation_order integer NOT NULL,
    revelation_place text NOT NULL,
    page integer[] NOT NULL,
    name_complex text NOT NULL,
    name_simple text NOT NULL,
    name_english text NOT NULL,
    name_arabic text NOT NULL
);


--
-- Name: tafsirs; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.tafsirs (
    id integer NOT NULL,
    verse_id integer,
    language_id integer,
    text text,
    language_name character varying,
    resource_content_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    resource_name character varying,
    verse_key character varying,
    chapter_id integer,
    verse_number integer,
    juz_number integer,
    hizb_number integer,
    rub_el_hizb_number integer,
    page_number integer,
    group_verse_key_from character varying,
    group_verse_key_to character varying,
    group_verses_count integer,
    group_tafsir_id integer,
    start_verse_id integer,
    end_verse_id integer,
    ruku_number integer,
    surah_ruku_number integer,
    manzil_number integer,
    archived boolean DEFAULT false
);


--
-- Name: tafsirs_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.tafsirs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tafsirs_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.tafsirs_id_seq OWNED BY quran.tafsirs.id;


--
-- Name: tags; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.tags (
    id bigint NOT NULL,
    name character varying,
    description character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.tags_id_seq OWNED BY quran.tags.id;


--
-- Name: tajweed_words; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.tajweed_words (
    id bigint NOT NULL,
    mushaf_id bigint NOT NULL,
    word_id bigint NOT NULL,
    verse_id bigint NOT NULL,
    letters jsonb DEFAULT '[]'::jsonb,
    text character varying,
    location character varying,
    "position" integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: tajweed_words_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.tajweed_words_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tajweed_words_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.tajweed_words_id_seq OWNED BY quran.tajweed_words.id;


--
-- Name: text; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.text (
    resource_id integer NOT NULL,
    ayah_key text NOT NULL,
    text text NOT NULL
);


--
-- Name: token; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.token (
    token_id integer NOT NULL,
    value character varying(50) NOT NULL,
    clean character varying(50) NOT NULL
);


--
-- Name: word; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.word (
    word_id integer NOT NULL,
    ayah_key text NOT NULL,
    "position" integer NOT NULL,
    token_id integer NOT NULL,
    translation character varying,
    transliteration character varying
);


--
-- Name: word_font; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.word_font (
    resource_id integer NOT NULL,
    ayah_key text NOT NULL,
    "position" integer NOT NULL,
    word_id integer,
    page_num integer NOT NULL,
    line_num integer NOT NULL,
    code_dec integer NOT NULL,
    code_hex text NOT NULL,
    char_type_id integer NOT NULL
);


--
-- Name: text_font; Type: VIEW; Schema: quran; Owner: -
--

CREATE VIEW quran.text_font AS
 SELECT concat_ws(':'::text, '1', s.surah_id, s.ayah_num) AS id,
    concat_ws(':'::text, s.surah_id, s.ayah_num) AS ayah_key,
    s.surah_id,
    s.ayah_num,
    true AS is_hidden,
    string_agg(s.lhs, ' '::text ORDER BY s."position") AS text
   FROM ( SELECT ayah.surah_id,
            ayah.ayah_num,
            (w.word_id)::text AS lhs,
            c."position"
           FROM (((((content.resource
             JOIN quran.word_font c USING (resource_id))
             JOIN quran.ayah USING (ayah_key))
             JOIN quran.char_type ct ON (((ct.char_type_id = c.char_type_id) AND (ct.name = 'word'::text))))
             JOIN quran.word w USING (word_id))
             JOIN quran.token t USING (token_id))
          WHERE (resource.resource_id = 1)
          ORDER BY ayah.surah_id, ayah.ayah_num, c."position") s
  GROUP BY s.surah_id, s.ayah_num
  ORDER BY s.surah_id, s.ayah_num;


--
-- Name: text_lemma; Type: VIEW; Schema: quran; Owner: -
--

CREATE VIEW quran.text_lemma AS
SELECT
    NULL::text AS id,
    NULL::text AS ayah_key,
    NULL::integer AS surah_id,
    NULL::integer AS ayah_num,
    NULL::boolean AS is_hidden,
    NULL::text AS text;


--
-- Name: text_root; Type: VIEW; Schema: quran; Owner: -
--

CREATE VIEW quran.text_root AS
SELECT
    NULL::text AS id,
    NULL::text AS ayah_key,
    NULL::integer AS surah_id,
    NULL::integer AS ayah_num,
    NULL::boolean AS is_hidden,
    NULL::text AS text;


--
-- Name: text_stem; Type: VIEW; Schema: quran; Owner: -
--

CREATE VIEW quran.text_stem AS
SELECT
    NULL::text AS id,
    NULL::text AS ayah_key,
    NULL::integer AS surah_id,
    NULL::integer AS ayah_num,
    NULL::boolean AS is_hidden,
    NULL::text AS text;


--
-- Name: text_token; Type: VIEW; Schema: quran; Owner: -
--

CREATE VIEW quran.text_token AS
SELECT
    NULL::text AS id,
    NULL::text AS ayah_key,
    NULL::integer AS surah_id,
    NULL::integer AS ayah_num,
    NULL::boolean AS is_hidden,
    NULL::text AS text;


--
-- Name: token_token_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.token_token_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: token_token_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.token_token_id_seq OWNED BY quran.token.token_id;


--
-- Name: tokens; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.tokens (
    id integer NOT NULL,
    text_uthmani character varying,
    text_imlaei_simple character varying,
    text_indopak character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    text_imlaei character varying,
    text_uthmani_tajweed character varying,
    text text,
    resource_content_id integer,
    record_id integer,
    record_type character varying,
    uniq_token_count integer
);


--
-- Name: tokens_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.tokens_id_seq OWNED BY quran.tokens.id;


--
-- Name: topics; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.topics (
    id integer NOT NULL,
    name character varying,
    parent_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    wikipedia_link character varying,
    arabic_name character varying,
    ontology boolean,
    thematic boolean,
    depth integer DEFAULT 0,
    ayah_range character varying,
    relatd_topics_count integer DEFAULT 0,
    children_count integer DEFAULT 0,
    description text,
    ontology_parent_id integer,
    thematic_parent_id integer,
    resource_content_id integer
);


--
-- Name: topics_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.topics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topics_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.topics_id_seq OWNED BY quran.topics.id;


--
-- Name: translated_names; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.translated_names (
    id integer NOT NULL,
    resource_type character varying,
    resource_id integer,
    language_id integer,
    name character varying,
    language_name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    language_priority integer
);


--
-- Name: translated_names_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.translated_names_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: translated_names_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.translated_names_id_seq OWNED BY quran.translated_names.id;


--
-- Name: translation_translation_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.translation_translation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: word_translation; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.word_translation (
    translation_id integer NOT NULL,
    word_id integer NOT NULL,
    language_code text NOT NULL,
    value text NOT NULL
);


--
-- Name: translation_translation_id_seq1; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.translation_translation_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: translation_translation_id_seq1; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.translation_translation_id_seq1 OWNED BY quran.word_translation.translation_id;


--
-- Name: translations; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.translations (
    id integer NOT NULL,
    language_id integer,
    text text,
    resource_content_id integer,
    verse_id integer,
    language_name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    resource_name character varying,
    priority integer,
    verse_key character varying,
    chapter_id integer,
    verse_number integer,
    juz_number integer,
    hizb_number integer,
    rub_el_hizb_number integer,
    page_number integer,
    ruku_number integer,
    surah_ruku_number integer,
    manzil_number integer,
    footnotes_count integer DEFAULT 0
);


--
-- Name: translations_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.translations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: translations_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.translations_id_seq OWNED BY quran.translations.id;


--
-- Name: transliterations; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.transliterations (
    id integer NOT NULL,
    resource_type character varying,
    resource_id integer,
    language_id integer,
    text text,
    language_name character varying,
    resource_content_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: transliterations_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.transliterations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transliterations_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.transliterations_id_seq OWNED BY quran.transliterations.id;


--
-- Name: verse_lemmas; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.verse_lemmas (
    id integer NOT NULL,
    text_madani character varying,
    text_clean character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: verse_lemmas_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.verse_lemmas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: verse_lemmas_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.verse_lemmas_id_seq OWNED BY quran.verse_lemmas.id;


--
-- Name: verse_pages; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.verse_pages (
    id bigint NOT NULL,
    verse_id integer,
    page_id integer,
    page_number integer,
    mushaf_id integer
);


--
-- Name: verse_pages_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.verse_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: verse_pages_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.verse_pages_id_seq OWNED BY quran.verse_pages.id;


--
-- Name: verse_roots; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.verse_roots (
    id integer NOT NULL,
    value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: verse_roots_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.verse_roots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: verse_roots_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.verse_roots_id_seq OWNED BY quran.verse_roots.id;


--
-- Name: verse_stems; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.verse_stems (
    id integer NOT NULL,
    text_madani character varying,
    text_clean character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: verse_stems_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.verse_stems_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: verse_stems_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.verse_stems_id_seq OWNED BY quran.verse_stems.id;


--
-- Name: verse_topics; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.verse_topics (
    id bigint NOT NULL,
    topic_id integer,
    verse_id integer,
    topic_words jsonb DEFAULT '[]'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    ontology boolean DEFAULT false,
    thematic boolean DEFAULT false
);


--
-- Name: verse_topics_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.verse_topics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: verse_topics_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.verse_topics_id_seq OWNED BY quran.verse_topics.id;


--
-- Name: verses; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.verses (
    id integer NOT NULL,
    chapter_id integer,
    verse_number integer,
    verse_index integer,
    verse_key character varying,
    text_uthmani character varying,
    text_indopak character varying,
    text_imlaei_simple character varying,
    juz_number integer,
    hizb_number integer,
    rub_el_hizb_number integer,
    sajdah_type character varying,
    sajdah_number integer,
    page_number integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    image_url text,
    image_width integer,
    verse_root_id integer,
    verse_lemma_id integer,
    verse_stem_id integer,
    text_imlaei character varying,
    text_uthmani_simple character varying,
    text_uthmani_tajweed text,
    code_v1 character varying,
    code_v2 character varying,
    v2_page integer,
    text_qpc_hafs character varying,
    words_count integer,
    text_indopak_nastaleeq character varying,
    pause_words_count integer DEFAULT 0,
    mushaf_pages_mapping jsonb DEFAULT '{}'::jsonb,
    text_qpc_nastaleeq character varying,
    ruku_number integer,
    surah_ruku_number integer,
    manzil_number integer,
    text_qpc_nastaleeq_hafs character varying,
    mushaf_juzs_mapping jsonb DEFAULT '{}'::jsonb,
    text_digital_khatt character varying,
    text_digital_khatt_v1 character varying,
    text_qpc_hafs_tajweed character varying,
    text_digital_khatt_indopak character varying,
    text_indonesian_sign_language character varying,
    text_indopak_misbah character varying
);


--
-- Name: verses_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.verses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: verses_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.verses_id_seq OWNED BY quran.verses.id;


--
-- Name: view; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.view (
    view_id integer NOT NULL
);


--
-- Name: view_view_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.view_view_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: view_view_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.view_view_id_seq OWNED BY quran.view.view_id;


--
-- Name: word_corpuses; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.word_corpuses (
    id integer NOT NULL,
    word_id integer,
    location character varying,
    description text,
    image_src character varying,
    segments json,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    segments_data jsonb
);


--
-- Name: word_corpuses_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.word_corpuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: word_corpuses_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.word_corpuses_id_seq OWNED BY quran.word_corpuses.id;


--
-- Name: word_lemma; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.word_lemma (
    word_id integer NOT NULL,
    lemma_id integer NOT NULL,
    "position" integer DEFAULT 1 NOT NULL
);


--
-- Name: word_mistakes; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.word_mistakes (
    id bigint NOT NULL,
    word_id integer NOT NULL,
    mistake_count integer DEFAULT 0 NOT NULL,
    frequency double precision,
    char_start integer,
    char_end integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    received_text character varying
);


--
-- Name: word_mistakes_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.word_mistakes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: word_mistakes_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.word_mistakes_id_seq OWNED BY quran.word_mistakes.id;


--
-- Name: word_root; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.word_root (
    word_id integer NOT NULL,
    root_id integer NOT NULL,
    "position" integer DEFAULT 1 NOT NULL
);


--
-- Name: word_stem; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.word_stem (
    word_id integer NOT NULL,
    stem_id integer NOT NULL,
    "position" integer DEFAULT 1 NOT NULL
);


--
-- Name: word_texts; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.word_texts (
    script_id integer NOT NULL,
    word_id integer NOT NULL,
    text text NOT NULL,
    text_simple text,
    marks jsonb DEFAULT '[]'::jsonb NOT NULL
);


--
-- Name: word_translations; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.word_translations (
    id bigint NOT NULL,
    word_id integer,
    text character varying,
    language_name character varying,
    language_id integer,
    resource_content_id integer,
    priority integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    group_text character varying,
    group_word_id integer
);


--
-- Name: word_translations_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.word_translations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: word_translations_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.word_translations_id_seq OWNED BY quran.word_translations.id;


--
-- Name: word_transliteration; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.word_transliteration (
    transliteration_id integer NOT NULL,
    word_id integer,
    language_code character varying,
    value character varying
);


--
-- Name: word_transliteration_transliteration_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.word_transliteration_transliteration_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: word_transliteration_transliteration_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.word_transliteration_transliteration_id_seq OWNED BY quran.word_transliteration.transliteration_id;


--
-- Name: word_word_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.word_word_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: word_word_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.word_word_id_seq OWNED BY quran.word.word_id;


--
-- Name: words; Type: TABLE; Schema: quran; Owner: -
--

CREATE TABLE quran.words (
    id integer NOT NULL,
    verse_id integer,
    chapter_id integer,
    "position" integer,
    text_uthmani character varying,
    text_indopak character varying,
    text_imlaei_simple character varying,
    verse_key character varying,
    page_number integer,
    class_name character varying,
    line_number integer,
    code_dec integer,
    code_hex character varying,
    code_hex_v3 character varying,
    code_dec_v3 integer,
    char_type_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    pause_name character varying,
    audio_url character varying,
    image_blob text,
    image_url character varying,
    token_id integer,
    topic_id integer,
    location character varying,
    char_type_name character varying,
    text_imlaei character varying,
    text_uthmani_simple character varying,
    text_uthmani_tajweed character varying,
    en_transliteration character varying,
    code_v1 character varying,
    code_v2 character varying,
    v2_page integer,
    line_v2 integer,
    text_qpc_hafs character varying,
    text_indopak_nastaleeq character varying,
    text_qpc_nastaleeq character varying,
    text_qpc_nastaleeq_hafs character varying,
    text_digital_khatt character varying,
    word_index integer,
    meta_data jsonb DEFAULT '{}'::jsonb,
    text_digital_khatt_v1 character varying,
    text_qpc_hafs_tajweed character varying,
    text_digital_khatt_indopak character varying,
    sequence_number integer,
    root_id integer,
    lemma_id integer,
    stem_id integer,
    text_indonesian_sign_language character varying,
    text_indopak_misbah character varying,
    number integer,
    number_last integer,
    hafs_reads boolean DEFAULT true NOT NULL,
    sub_position integer DEFAULT 0 NOT NULL
);


--
-- Name: words_id_seq; Type: SEQUENCE; Schema: quran; Owner: -
--

CREATE SEQUENCE quran.words_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: words_id_seq; Type: SEQUENCE OWNED BY; Schema: quran; Owner: -
--

ALTER SEQUENCE quran.words_id_seq OWNED BY quran.words.id;


--
-- Name: file file_id; Type: DEFAULT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.file ALTER COLUMN file_id SET DEFAULT nextval('audio._file_file_id_seq'::regclass);


--
-- Name: recitation recitation_id; Type: DEFAULT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.recitation ALTER COLUMN recitation_id SET DEFAULT nextval('audio.recitation_recitation_id_seq'::regclass);


--
-- Name: reciter reciter_id; Type: DEFAULT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.reciter ALTER COLUMN reciter_id SET DEFAULT nextval('audio._reciter_reciter_id_seq'::regclass);


--
-- Name: style style_id; Type: DEFAULT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.style ALTER COLUMN style_id SET DEFAULT nextval('audio._style_style_id_seq'::regclass);


--
-- Name: author author_id; Type: DEFAULT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.author ALTER COLUMN author_id SET DEFAULT nextval('content._author_author_id_seq'::regclass);


--
-- Name: surah_infos id; Type: DEFAULT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.surah_infos ALTER COLUMN id SET DEFAULT nextval('content.surah_infos_id_seq'::regclass);


--
-- Name: tafsir tafsir_id; Type: DEFAULT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.tafsir ALTER COLUMN tafsir_id SET DEFAULT nextval('content._tafsir_tafsir_id_seq'::regclass);


--
-- Name: content resource_id; Type: DEFAULT; Schema: media; Owner: -
--

ALTER TABLE ONLY media.content ALTER COLUMN resource_id SET DEFAULT nextval('media.content_resource_id_seq'::regclass);


--
-- Name: resource resource_id; Type: DEFAULT; Schema: media; Owner: -
--

ALTER TABLE ONLY media.resource ALTER COLUMN resource_id SET DEFAULT nextval('media.resource_resource_id_seq'::regclass);


--
-- Name: api_client_request_stats id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.api_client_request_stats ALTER COLUMN id SET DEFAULT nextval('quran.api_client_request_stats_id_seq'::regclass);


--
-- Name: api_clients id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.api_clients ALTER COLUMN id SET DEFAULT nextval('quran.api_clients_id_seq'::regclass);


--
-- Name: arabic_transliterations id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.arabic_transliterations ALTER COLUMN id SET DEFAULT nextval('quran.arabic_transliterations_id_seq'::regclass);


--
-- Name: audio_change_logs id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.audio_change_logs ALTER COLUMN id SET DEFAULT nextval('quran.audio_change_logs_id_seq'::regclass);


--
-- Name: audio_chapter_audio_files id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.audio_chapter_audio_files ALTER COLUMN id SET DEFAULT nextval('quran.audio_chapter_audio_files_id_seq'::regclass);


--
-- Name: audio_files id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.audio_files ALTER COLUMN id SET DEFAULT nextval('quran.audio_files_id_seq'::regclass);


--
-- Name: audio_recitations id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.audio_recitations ALTER COLUMN id SET DEFAULT nextval('quran.audio_recitations_id_seq'::regclass);


--
-- Name: audio_related_recitations id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.audio_related_recitations ALTER COLUMN id SET DEFAULT nextval('quran.audio_related_recitations_id_seq'::regclass);


--
-- Name: audio_sections id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.audio_sections ALTER COLUMN id SET DEFAULT nextval('quran.audio_sections_id_seq'::regclass);


--
-- Name: audio_segments id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.audio_segments ALTER COLUMN id SET DEFAULT nextval('quran.audio_segments_id_seq'::regclass);


--
-- Name: authors id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.authors ALTER COLUMN id SET DEFAULT nextval('quran.authors_id_seq'::regclass);


--
-- Name: ayah_themes id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.ayah_themes ALTER COLUMN id SET DEFAULT nextval('quran.ayah_themes_id_seq'::regclass);


--
-- Name: books id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.books ALTER COLUMN id SET DEFAULT nextval('quran.books_id_seq'::regclass);


--
-- Name: chapter_infos id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.chapter_infos ALTER COLUMN id SET DEFAULT nextval('quran.chapter_infos_id_seq'::regclass);


--
-- Name: chapters id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.chapters ALTER COLUMN id SET DEFAULT nextval('quran.chapters_id_seq'::regclass);


--
-- Name: char_type char_type_id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.char_type ALTER COLUMN char_type_id SET DEFAULT nextval('quran.char_type_char_type_id_seq'::regclass);


--
-- Name: char_types id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.char_types ALTER COLUMN id SET DEFAULT nextval('quran.char_types_id_seq'::regclass);


--
-- Name: corpus_word_forms id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.corpus_word_forms ALTER COLUMN id SET DEFAULT nextval('quran.corpus_word_forms_id_seq'::regclass);


--
-- Name: corpus_word_grammars id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.corpus_word_grammars ALTER COLUMN id SET DEFAULT nextval('quran.corpus_word_grammars_id_seq'::regclass);


--
-- Name: counting_systems id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.counting_systems ALTER COLUMN id SET DEFAULT nextval('quran.counting_systems_id_seq'::regclass);


--
-- Name: data_sources id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.data_sources ALTER COLUMN id SET DEFAULT nextval('quran.data_sources_id_seq'::regclass);


--
-- Name: dictionary_root_definitions id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.dictionary_root_definitions ALTER COLUMN id SET DEFAULT nextval('quran.dictionary_root_definitions_id_seq'::regclass);


--
-- Name: dictionary_root_examples id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.dictionary_root_examples ALTER COLUMN id SET DEFAULT nextval('quran.dictionary_root_examples_id_seq'::regclass);


--
-- Name: dictionary_word_roots id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.dictionary_word_roots ALTER COLUMN id SET DEFAULT nextval('quran.dictionary_word_roots_id_seq'::regclass);


--
-- Name: feedbacks id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.feedbacks ALTER COLUMN id SET DEFAULT nextval('quran.feedbacks_id_seq'::regclass);


--
-- Name: foot_notes id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.foot_notes ALTER COLUMN id SET DEFAULT nextval('quran.foot_notes_id_seq'::regclass);


--
-- Name: hizbs id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.hizbs ALTER COLUMN id SET DEFAULT nextval('quran.hizbs_id_seq'::regclass);


--
-- Name: images id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.images ALTER COLUMN id SET DEFAULT nextval('quran.images_id_seq'::regclass);


--
-- Name: juzs id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.juzs ALTER COLUMN id SET DEFAULT nextval('quran.juzs_id_seq'::regclass);


--
-- Name: languages id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.languages ALTER COLUMN id SET DEFAULT nextval('quran.languages_id_seq'::regclass);


--
-- Name: lemma lemma_id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.lemma ALTER COLUMN lemma_id SET DEFAULT nextval('quran.lemma_lemma_id_seq1'::regclass);


--
-- Name: lemmas id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.lemmas ALTER COLUMN id SET DEFAULT nextval('quran.lemmas_id_seq'::regclass);


--
-- Name: manzils id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.manzils ALTER COLUMN id SET DEFAULT nextval('quran.manzils_id_seq'::regclass);


--
-- Name: media_contents id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.media_contents ALTER COLUMN id SET DEFAULT nextval('quran.media_contents_id_seq'::regclass);


--
-- Name: morphology_dependency_graph_node_edges id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_dependency_graph_node_edges ALTER COLUMN id SET DEFAULT nextval('quran.morphology_dependency_graph_node_edges_id_seq'::regclass);


--
-- Name: morphology_dependency_graph_nodes id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_dependency_graph_nodes ALTER COLUMN id SET DEFAULT nextval('quran.morphology_dependency_graph_nodes_id_seq'::regclass);


--
-- Name: morphology_dependency_graphs id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_dependency_graphs ALTER COLUMN id SET DEFAULT nextval('quran.morphology_dependency_graphs_id_seq'::regclass);


--
-- Name: morphology_derived_words id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_derived_words ALTER COLUMN id SET DEFAULT nextval('quran.morphology_derived_words_id_seq'::regclass);


--
-- Name: morphology_dictionary_term_translations id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_dictionary_term_translations ALTER COLUMN id SET DEFAULT nextval('quran.morphology_dictionary_term_translations_id_seq'::regclass);


--
-- Name: morphology_dictionary_terms id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_dictionary_terms ALTER COLUMN id SET DEFAULT nextval('quran.morphology_dictionary_terms_id_seq'::regclass);


--
-- Name: morphology_grammar_concepts id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_grammar_concepts ALTER COLUMN id SET DEFAULT nextval('quran.morphology_grammar_concepts_id_seq'::regclass);


--
-- Name: morphology_grammar_patterns id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_grammar_patterns ALTER COLUMN id SET DEFAULT nextval('quran.morphology_grammar_patterns_id_seq'::regclass);


--
-- Name: morphology_grammar_term_translations id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_grammar_term_translations ALTER COLUMN id SET DEFAULT nextval('quran.morphology_grammar_term_translations_id_seq'::regclass);


--
-- Name: morphology_grammar_terms id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_grammar_terms ALTER COLUMN id SET DEFAULT nextval('quran.morphology_grammar_terms_id_seq'::regclass);


--
-- Name: morphology_sentences id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_sentences ALTER COLUMN id SET DEFAULT nextval('quran.morphology_sentences_id_seq'::regclass);


--
-- Name: morphology_word_grammar_concepts id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_word_grammar_concepts ALTER COLUMN id SET DEFAULT nextval('quran.morphology_word_grammar_concepts_id_seq'::regclass);


--
-- Name: morphology_word_segments id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_word_segments ALTER COLUMN id SET DEFAULT nextval('quran.morphology_word_segments_id_seq'::regclass);


--
-- Name: morphology_word_tokens id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_word_tokens ALTER COLUMN id SET DEFAULT nextval('quran.morphology_word_tokens_id_seq'::regclass);


--
-- Name: morphology_word_verb_forms id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_word_verb_forms ALTER COLUMN id SET DEFAULT nextval('quran.morphology_word_verb_forms_id_seq'::regclass);


--
-- Name: morphology_words id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_words ALTER COLUMN id SET DEFAULT nextval('quran.morphology_words_id_seq'::regclass);


--
-- Name: mushaf_juzs id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.mushaf_juzs ALTER COLUMN id SET DEFAULT nextval('quran.mushaf_juzs_id_seq'::regclass);


--
-- Name: mushaf_pages id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.mushaf_pages ALTER COLUMN id SET DEFAULT nextval('quran.mushaf_pages_id_seq'::regclass);


--
-- Name: mushaf_words id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.mushaf_words ALTER COLUMN id SET DEFAULT nextval('quran.mushaf_words_id_seq'::regclass);


--
-- Name: mushafs id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.mushafs ALTER COLUMN id SET DEFAULT nextval('quran.mushafs_id_seq'::regclass);


--
-- Name: mushas_pages id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.mushas_pages ALTER COLUMN id SET DEFAULT nextval('quran.mushas_pages_id_seq'::regclass);


--
-- Name: navigation_search_records id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.navigation_search_records ALTER COLUMN id SET DEFAULT nextval('quran.navigation_search_records_id_seq'::regclass);


--
-- Name: qiraat id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.qiraat ALTER COLUMN id SET DEFAULT nextval('quran.qiraat_id_seq'::regclass);


--
-- Name: quran_script_by_verses id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.quran_script_by_verses ALTER COLUMN id SET DEFAULT nextval('quran.quran_script_by_verses_id_seq'::regclass);


--
-- Name: quran_script_by_words id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.quran_script_by_words ALTER COLUMN id SET DEFAULT nextval('quran.quran_script_by_words_id_seq'::regclass);


--
-- Name: quran_scripts id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.quran_scripts ALTER COLUMN id SET DEFAULT nextval('quran.quran_scripts_id_seq'::regclass);


--
-- Name: radio_station_audio_files id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.radio_station_audio_files ALTER COLUMN id SET DEFAULT nextval('quran.radio_station_audio_files_id_seq'::regclass);


--
-- Name: radio_stations id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.radio_stations ALTER COLUMN id SET DEFAULT nextval('quran.radio_stations_id_seq'::regclass);


--
-- Name: raw_data_ayah_records id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.raw_data_ayah_records ALTER COLUMN id SET DEFAULT nextval('quran.raw_data_ayah_records_id_seq'::regclass);


--
-- Name: raw_data_resources id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.raw_data_resources ALTER COLUMN id SET DEFAULT nextval('quran.raw_data_resources_id_seq'::regclass);


--
-- Name: recitation_styles id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.recitation_styles ALTER COLUMN id SET DEFAULT nextval('quran.recitation_styles_id_seq'::regclass);


--
-- Name: recitations id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.recitations ALTER COLUMN id SET DEFAULT nextval('quran.recitations_id_seq'::regclass);


--
-- Name: reciters id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.reciters ALTER COLUMN id SET DEFAULT nextval('quran.reciters_id_seq'::regclass);


--
-- Name: related_topics id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.related_topics ALTER COLUMN id SET DEFAULT nextval('quran.related_topics_id_seq'::regclass);


--
-- Name: resource_content_stats id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.resource_content_stats ALTER COLUMN id SET DEFAULT nextval('quran.resource_content_stats_id_seq'::regclass);


--
-- Name: resource_contents id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.resource_contents ALTER COLUMN id SET DEFAULT nextval('quran.resource_contents_id_seq'::regclass);


--
-- Name: resource_tags id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.resource_tags ALTER COLUMN id SET DEFAULT nextval('quran.resource_tags_id_seq'::regclass);


--
-- Name: riwayat id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.riwayat ALTER COLUMN id SET DEFAULT nextval('quran.riwayat_id_seq'::regclass);


--
-- Name: root root_id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.root ALTER COLUMN root_id SET DEFAULT nextval('quran.root_root_id_seq1'::regclass);


--
-- Name: root_details id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.root_details ALTER COLUMN id SET DEFAULT nextval('quran.root_details_id_seq'::regclass);


--
-- Name: roots id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.roots ALTER COLUMN id SET DEFAULT nextval('quran.roots_id_seq'::regclass);


--
-- Name: rub_el_hizbs id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.rub_el_hizbs ALTER COLUMN id SET DEFAULT nextval('quran.rub_el_hizbs_id_seq'::regclass);


--
-- Name: rukus id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.rukus ALTER COLUMN id SET DEFAULT nextval('quran.rukus_id_seq'::regclass);


--
-- Name: scripts id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.scripts ALTER COLUMN id SET DEFAULT nextval('quran.scripts_id_seq'::regclass);


--
-- Name: slugs id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.slugs ALTER COLUMN id SET DEFAULT nextval('quran.slugs_id_seq'::regclass);


--
-- Name: stem stem_id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.stem ALTER COLUMN stem_id SET DEFAULT nextval('quran.stem_stem_id_seq1'::regclass);


--
-- Name: stems id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.stems ALTER COLUMN id SET DEFAULT nextval('quran.stems_id_seq'::regclass);


--
-- Name: tafsirs id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.tafsirs ALTER COLUMN id SET DEFAULT nextval('quran.tafsirs_id_seq'::regclass);


--
-- Name: tags id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.tags ALTER COLUMN id SET DEFAULT nextval('quran.tags_id_seq'::regclass);


--
-- Name: tajweed_words id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.tajweed_words ALTER COLUMN id SET DEFAULT nextval('quran.tajweed_words_id_seq'::regclass);


--
-- Name: token token_id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.token ALTER COLUMN token_id SET DEFAULT nextval('quran.token_token_id_seq'::regclass);


--
-- Name: tokens id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.tokens ALTER COLUMN id SET DEFAULT nextval('quran.tokens_id_seq'::regclass);


--
-- Name: topics id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.topics ALTER COLUMN id SET DEFAULT nextval('quran.topics_id_seq'::regclass);


--
-- Name: translated_names id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.translated_names ALTER COLUMN id SET DEFAULT nextval('quran.translated_names_id_seq'::regclass);


--
-- Name: translations id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.translations ALTER COLUMN id SET DEFAULT nextval('quran.translations_id_seq'::regclass);


--
-- Name: transliterations id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.transliterations ALTER COLUMN id SET DEFAULT nextval('quran.transliterations_id_seq'::regclass);


--
-- Name: verse_lemmas id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.verse_lemmas ALTER COLUMN id SET DEFAULT nextval('quran.verse_lemmas_id_seq'::regclass);


--
-- Name: verse_pages id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.verse_pages ALTER COLUMN id SET DEFAULT nextval('quran.verse_pages_id_seq'::regclass);


--
-- Name: verse_roots id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.verse_roots ALTER COLUMN id SET DEFAULT nextval('quran.verse_roots_id_seq'::regclass);


--
-- Name: verse_stems id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.verse_stems ALTER COLUMN id SET DEFAULT nextval('quran.verse_stems_id_seq'::regclass);


--
-- Name: verse_topics id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.verse_topics ALTER COLUMN id SET DEFAULT nextval('quran.verse_topics_id_seq'::regclass);


--
-- Name: verses id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.verses ALTER COLUMN id SET DEFAULT nextval('quran.verses_id_seq'::regclass);


--
-- Name: view view_id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.view ALTER COLUMN view_id SET DEFAULT nextval('quran.view_view_id_seq'::regclass);


--
-- Name: word word_id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word ALTER COLUMN word_id SET DEFAULT nextval('quran.word_word_id_seq'::regclass);


--
-- Name: word_corpuses id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_corpuses ALTER COLUMN id SET DEFAULT nextval('quran.word_corpuses_id_seq'::regclass);


--
-- Name: word_mistakes id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_mistakes ALTER COLUMN id SET DEFAULT nextval('quran.word_mistakes_id_seq'::regclass);


--
-- Name: word_translation translation_id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_translation ALTER COLUMN translation_id SET DEFAULT nextval('quran.translation_translation_id_seq1'::regclass);


--
-- Name: word_translations id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_translations ALTER COLUMN id SET DEFAULT nextval('quran.word_translations_id_seq'::regclass);


--
-- Name: word_transliteration transliteration_id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_transliteration ALTER COLUMN transliteration_id SET DEFAULT nextval('quran.word_transliteration_transliteration_id_seq'::regclass);


--
-- Name: words id; Type: DEFAULT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.words ALTER COLUMN id SET DEFAULT nextval('quran.words_id_seq'::regclass);


--
-- Name: file _file_pkey; Type: CONSTRAINT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.file
    ADD CONSTRAINT _file_pkey PRIMARY KEY (file_id);


--
-- Name: file _file_recitation_id_ayah_key_format_key; Type: CONSTRAINT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.file
    ADD CONSTRAINT _file_recitation_id_ayah_key_format_key UNIQUE (recitation_id, ayah_key, format);


--
-- Name: reciter _reciter_arabic_key; Type: CONSTRAINT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.reciter
    ADD CONSTRAINT _reciter_arabic_key UNIQUE (arabic);


--
-- Name: reciter _reciter_english_key; Type: CONSTRAINT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.reciter
    ADD CONSTRAINT _reciter_english_key UNIQUE (english);


--
-- Name: reciter _reciter_path_key; Type: CONSTRAINT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.reciter
    ADD CONSTRAINT _reciter_path_key UNIQUE (path);


--
-- Name: reciter _reciter_pkey; Type: CONSTRAINT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.reciter
    ADD CONSTRAINT _reciter_pkey PRIMARY KEY (reciter_id);


--
-- Name: reciter _reciter_slug_key; Type: CONSTRAINT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.reciter
    ADD CONSTRAINT _reciter_slug_key UNIQUE (slug);


--
-- Name: style _style_arabic_key; Type: CONSTRAINT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.style
    ADD CONSTRAINT _style_arabic_key UNIQUE (arabic);


--
-- Name: style _style_english_key; Type: CONSTRAINT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.style
    ADD CONSTRAINT _style_english_key UNIQUE (english);


--
-- Name: style _style_path_key; Type: CONSTRAINT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.style
    ADD CONSTRAINT _style_path_key UNIQUE (path);


--
-- Name: style _style_pkey; Type: CONSTRAINT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.style
    ADD CONSTRAINT _style_pkey PRIMARY KEY (style_id);


--
-- Name: style _style_slug_key; Type: CONSTRAINT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.style
    ADD CONSTRAINT _style_slug_key UNIQUE (slug);


--
-- Name: recitation recitation_pkey; Type: CONSTRAINT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.recitation
    ADD CONSTRAINT recitation_pkey PRIMARY KEY (recitation_id);


--
-- Name: recitation recitation_reciter_id_style_id_key; Type: CONSTRAINT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.recitation
    ADD CONSTRAINT recitation_reciter_id_style_id_key UNIQUE (reciter_id, style_id);


--
-- Name: author _author_pkey; Type: CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.author
    ADD CONSTRAINT _author_pkey PRIMARY KEY (author_id);


--
-- Name: tafsir_ayah _tafsir_ayah_pkey; Type: CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.tafsir_ayah
    ADD CONSTRAINT _tafsir_ayah_pkey PRIMARY KEY (tafsir_id, ayah_key);


--
-- Name: tafsir _tafsir_pkey; Type: CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.tafsir
    ADD CONSTRAINT _tafsir_pkey PRIMARY KEY (tafsir_id);


--
-- Name: translation _translation_pkey; Type: CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.translation
    ADD CONSTRAINT _translation_pkey PRIMARY KEY (resource_id, ayah_key);


--
-- Name: transliteration _transliteration_pkey; Type: CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.transliteration
    ADD CONSTRAINT _transliteration_pkey PRIMARY KEY (resource_id, ayah_key);


--
-- Name: resource_api_version resource_api_version_pkey; Type: CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.resource_api_version
    ADD CONSTRAINT resource_api_version_pkey PRIMARY KEY (resource_id);


--
-- Name: resource resource_pkey; Type: CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.resource
    ADD CONSTRAINT resource_pkey PRIMARY KEY (resource_id);


--
-- Name: resource resource_type_sub_type_language_code_slug_key; Type: CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.resource
    ADD CONSTRAINT resource_type_sub_type_language_code_slug_key UNIQUE (type, sub_type, language_code, slug);


--
-- Name: source source_pkey; Type: CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.source
    ADD CONSTRAINT source_pkey PRIMARY KEY (source_id);


--
-- Name: surah_infos surah_infos_pkey; Type: CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.surah_infos
    ADD CONSTRAINT surah_infos_pkey PRIMARY KEY (id);


--
-- Name: language language_pkey; Type: CONSTRAINT; Schema: i18n; Owner: -
--

ALTER TABLE ONLY i18n.language
    ADD CONSTRAINT language_pkey PRIMARY KEY (language_code);


--
-- Name: resource resource_pkey; Type: CONSTRAINT; Schema: media; Owner: -
--

ALTER TABLE ONLY media.resource
    ADD CONSTRAINT resource_pkey PRIMARY KEY (resource_id);


--
-- Name: text _text_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.text
    ADD CONSTRAINT _text_pkey PRIMARY KEY (resource_id, ayah_key);


--
-- Name: api_client_request_stats api_client_request_stats_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.api_client_request_stats
    ADD CONSTRAINT api_client_request_stats_pkey PRIMARY KEY (id);


--
-- Name: api_clients api_clients_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.api_clients
    ADD CONSTRAINT api_clients_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: arabic_transliterations arabic_transliterations_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.arabic_transliterations
    ADD CONSTRAINT arabic_transliterations_pkey PRIMARY KEY (id);


--
-- Name: audio_change_logs audio_change_logs_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.audio_change_logs
    ADD CONSTRAINT audio_change_logs_pkey PRIMARY KEY (id);


--
-- Name: audio_chapter_audio_files audio_chapter_audio_files_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.audio_chapter_audio_files
    ADD CONSTRAINT audio_chapter_audio_files_pkey PRIMARY KEY (id);


--
-- Name: audio_files audio_files_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.audio_files
    ADD CONSTRAINT audio_files_pkey PRIMARY KEY (id);


--
-- Name: audio_recitations audio_recitations_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.audio_recitations
    ADD CONSTRAINT audio_recitations_pkey PRIMARY KEY (id);


--
-- Name: audio_related_recitations audio_related_recitations_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.audio_related_recitations
    ADD CONSTRAINT audio_related_recitations_pkey PRIMARY KEY (id);


--
-- Name: audio_sections audio_sections_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.audio_sections
    ADD CONSTRAINT audio_sections_pkey PRIMARY KEY (id);


--
-- Name: audio_segments audio_segments_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.audio_segments
    ADD CONSTRAINT audio_segments_pkey PRIMARY KEY (id);


--
-- Name: authors authors_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.authors
    ADD CONSTRAINT authors_pkey PRIMARY KEY (id);


--
-- Name: ayah ayah_index_key; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.ayah
    ADD CONSTRAINT ayah_index_key UNIQUE (ayah_index);


--
-- Name: ayah ayah_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.ayah
    ADD CONSTRAINT ayah_pkey PRIMARY KEY (ayah_key);


--
-- Name: ayah_texts ayah_texts_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.ayah_texts
    ADD CONSTRAINT ayah_texts_pkey PRIMARY KEY (script_id, ayah_id);


--
-- Name: ayah_themes ayah_themes_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.ayah_themes
    ADD CONSTRAINT ayah_themes_pkey PRIMARY KEY (id);


--
-- Name: books books_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.books
    ADD CONSTRAINT books_pkey PRIMARY KEY (id);


--
-- Name: chapter_infos chapter_infos_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.chapter_infos
    ADD CONSTRAINT chapter_infos_pkey PRIMARY KEY (id);


--
-- Name: chapters chapters_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.chapters
    ADD CONSTRAINT chapters_pkey PRIMARY KEY (id);


--
-- Name: char_type char_type_name_parent_id_key; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.char_type
    ADD CONSTRAINT char_type_name_parent_id_key UNIQUE (name, parent_id);


--
-- Name: char_type char_type_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.char_type
    ADD CONSTRAINT char_type_pkey PRIMARY KEY (char_type_id);


--
-- Name: char_types char_types_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.char_types
    ADD CONSTRAINT char_types_pkey PRIMARY KEY (id);


--
-- Name: corpus_word_forms corpus_word_forms_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.corpus_word_forms
    ADD CONSTRAINT corpus_word_forms_pkey PRIMARY KEY (id);


--
-- Name: corpus_word_grammars corpus_word_grammars_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.corpus_word_grammars
    ADD CONSTRAINT corpus_word_grammars_pkey PRIMARY KEY (id);


--
-- Name: counting_systems counting_systems_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.counting_systems
    ADD CONSTRAINT counting_systems_pkey PRIMARY KEY (id);


--
-- Name: data_sources data_sources_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.data_sources
    ADD CONSTRAINT data_sources_pkey PRIMARY KEY (id);


--
-- Name: dictionary_root_definitions dictionary_root_definitions_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.dictionary_root_definitions
    ADD CONSTRAINT dictionary_root_definitions_pkey PRIMARY KEY (id);


--
-- Name: dictionary_root_examples dictionary_root_examples_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.dictionary_root_examples
    ADD CONSTRAINT dictionary_root_examples_pkey PRIMARY KEY (id);


--
-- Name: dictionary_word_roots dictionary_word_roots_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.dictionary_word_roots
    ADD CONSTRAINT dictionary_word_roots_pkey PRIMARY KEY (id);


--
-- Name: feedbacks feedbacks_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.feedbacks
    ADD CONSTRAINT feedbacks_pkey PRIMARY KEY (id);


--
-- Name: foot_notes foot_notes_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.foot_notes
    ADD CONSTRAINT foot_notes_pkey PRIMARY KEY (id);


--
-- Name: hizbs hizbs_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.hizbs
    ADD CONSTRAINT hizbs_pkey PRIMARY KEY (id);


--
-- Name: images images_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.images
    ADD CONSTRAINT images_pkey PRIMARY KEY (id);


--
-- Name: juzs juzs_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.juzs
    ADD CONSTRAINT juzs_pkey PRIMARY KEY (id);


--
-- Name: languages languages_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.languages
    ADD CONSTRAINT languages_pkey PRIMARY KEY (id);


--
-- Name: lemma lemma_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.lemma
    ADD CONSTRAINT lemma_pkey PRIMARY KEY (lemma_id);


--
-- Name: lemma lemma_value_key; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.lemma
    ADD CONSTRAINT lemma_value_key UNIQUE (value);


--
-- Name: lemmas lemmas_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.lemmas
    ADD CONSTRAINT lemmas_pkey PRIMARY KEY (id);


--
-- Name: manzils manzils_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.manzils
    ADD CONSTRAINT manzils_pkey PRIMARY KEY (id);


--
-- Name: media_contents media_contents_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.media_contents
    ADD CONSTRAINT media_contents_pkey PRIMARY KEY (id);


--
-- Name: morphology_dependency_graph_node_edges morphology_dependency_graph_node_edges_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_dependency_graph_node_edges
    ADD CONSTRAINT morphology_dependency_graph_node_edges_pkey PRIMARY KEY (id);


--
-- Name: morphology_dependency_graph_nodes morphology_dependency_graph_nodes_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_dependency_graph_nodes
    ADD CONSTRAINT morphology_dependency_graph_nodes_pkey PRIMARY KEY (id);


--
-- Name: morphology_dependency_graphs morphology_dependency_graphs_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_dependency_graphs
    ADD CONSTRAINT morphology_dependency_graphs_pkey PRIMARY KEY (id);


--
-- Name: morphology_derived_words morphology_derived_words_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_derived_words
    ADD CONSTRAINT morphology_derived_words_pkey PRIMARY KEY (id);


--
-- Name: morphology_dictionary_term_translations morphology_dictionary_term_translations_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_dictionary_term_translations
    ADD CONSTRAINT morphology_dictionary_term_translations_pkey PRIMARY KEY (id);


--
-- Name: morphology_dictionary_terms morphology_dictionary_terms_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_dictionary_terms
    ADD CONSTRAINT morphology_dictionary_terms_pkey PRIMARY KEY (id);


--
-- Name: morphology_grammar_concepts morphology_grammar_concepts_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_grammar_concepts
    ADD CONSTRAINT morphology_grammar_concepts_pkey PRIMARY KEY (id);


--
-- Name: morphology_grammar_patterns morphology_grammar_patterns_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_grammar_patterns
    ADD CONSTRAINT morphology_grammar_patterns_pkey PRIMARY KEY (id);


--
-- Name: morphology_grammar_term_translations morphology_grammar_term_translations_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_grammar_term_translations
    ADD CONSTRAINT morphology_grammar_term_translations_pkey PRIMARY KEY (id);


--
-- Name: morphology_grammar_terms morphology_grammar_terms_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_grammar_terms
    ADD CONSTRAINT morphology_grammar_terms_pkey PRIMARY KEY (id);


--
-- Name: morphology_sentences morphology_sentences_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_sentences
    ADD CONSTRAINT morphology_sentences_pkey PRIMARY KEY (id);


--
-- Name: morphology_word_grammar_concepts morphology_word_grammar_concepts_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_word_grammar_concepts
    ADD CONSTRAINT morphology_word_grammar_concepts_pkey PRIMARY KEY (id);


--
-- Name: morphology_word_segments morphology_word_segments_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_word_segments
    ADD CONSTRAINT morphology_word_segments_pkey PRIMARY KEY (id);


--
-- Name: morphology_word_tokens morphology_word_tokens_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_word_tokens
    ADD CONSTRAINT morphology_word_tokens_pkey PRIMARY KEY (id);


--
-- Name: morphology_word_verb_forms morphology_word_verb_forms_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_word_verb_forms
    ADD CONSTRAINT morphology_word_verb_forms_pkey PRIMARY KEY (id);


--
-- Name: morphology_words morphology_words_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_words
    ADD CONSTRAINT morphology_words_pkey PRIMARY KEY (id);


--
-- Name: mushaf_juzs mushaf_juzs_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.mushaf_juzs
    ADD CONSTRAINT mushaf_juzs_pkey PRIMARY KEY (id);


--
-- Name: mushaf_pages mushaf_pages_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.mushaf_pages
    ADD CONSTRAINT mushaf_pages_pkey PRIMARY KEY (id);


--
-- Name: mushaf_words mushaf_words_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.mushaf_words
    ADD CONSTRAINT mushaf_words_pkey PRIMARY KEY (id);


--
-- Name: mushafs mushafs_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.mushafs
    ADD CONSTRAINT mushafs_pkey PRIMARY KEY (id);


--
-- Name: mushas_pages mushas_pages_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.mushas_pages
    ADD CONSTRAINT mushas_pages_pkey PRIMARY KEY (id);


--
-- Name: navigation_search_records navigation_search_records_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.navigation_search_records
    ADD CONSTRAINT navigation_search_records_pkey PRIMARY KEY (id);


--
-- Name: qiraat qiraat_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.qiraat
    ADD CONSTRAINT qiraat_pkey PRIMARY KEY (id);


--
-- Name: quran_script_by_verses quran_script_by_verses_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.quran_script_by_verses
    ADD CONSTRAINT quran_script_by_verses_pkey PRIMARY KEY (id);


--
-- Name: quran_script_by_words quran_script_by_words_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.quran_script_by_words
    ADD CONSTRAINT quran_script_by_words_pkey PRIMARY KEY (id);


--
-- Name: quran_scripts quran_scripts_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.quran_scripts
    ADD CONSTRAINT quran_scripts_pkey PRIMARY KEY (id);


--
-- Name: radio_station_audio_files radio_station_audio_files_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.radio_station_audio_files
    ADD CONSTRAINT radio_station_audio_files_pkey PRIMARY KEY (id);


--
-- Name: radio_stations radio_stations_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.radio_stations
    ADD CONSTRAINT radio_stations_pkey PRIMARY KEY (id);


--
-- Name: raw_data_ayah_records raw_data_ayah_records_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.raw_data_ayah_records
    ADD CONSTRAINT raw_data_ayah_records_pkey PRIMARY KEY (id);


--
-- Name: raw_data_resources raw_data_resources_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.raw_data_resources
    ADD CONSTRAINT raw_data_resources_pkey PRIMARY KEY (id);


--
-- Name: recitation_styles recitation_styles_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.recitation_styles
    ADD CONSTRAINT recitation_styles_pkey PRIMARY KEY (id);


--
-- Name: recitations recitations_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.recitations
    ADD CONSTRAINT recitations_pkey PRIMARY KEY (id);


--
-- Name: reciters reciters_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.reciters
    ADD CONSTRAINT reciters_pkey PRIMARY KEY (id);


--
-- Name: related_topics related_topics_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.related_topics
    ADD CONSTRAINT related_topics_pkey PRIMARY KEY (id);


--
-- Name: resource_content_stats resource_content_stats_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.resource_content_stats
    ADD CONSTRAINT resource_content_stats_pkey PRIMARY KEY (id);


--
-- Name: resource_contents resource_contents_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.resource_contents
    ADD CONSTRAINT resource_contents_pkey PRIMARY KEY (id);


--
-- Name: resource_tags resource_tags_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.resource_tags
    ADD CONSTRAINT resource_tags_pkey PRIMARY KEY (id);


--
-- Name: riwayat riwayat_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.riwayat
    ADD CONSTRAINT riwayat_pkey PRIMARY KEY (id);


--
-- Name: root_details root_details_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.root_details
    ADD CONSTRAINT root_details_pkey PRIMARY KEY (id);


--
-- Name: root root_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.root
    ADD CONSTRAINT root_pkey PRIMARY KEY (root_id);


--
-- Name: root root_value_key; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.root
    ADD CONSTRAINT root_value_key UNIQUE (value);


--
-- Name: roots roots_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.roots
    ADD CONSTRAINT roots_pkey PRIMARY KEY (id);


--
-- Name: rub_el_hizbs rub_el_hizbs_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.rub_el_hizbs
    ADD CONSTRAINT rub_el_hizbs_pkey PRIMARY KEY (id);


--
-- Name: rukus rukus_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.rukus
    ADD CONSTRAINT rukus_pkey PRIMARY KEY (id);


--
-- Name: scripts scripts_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.scripts
    ADD CONSTRAINT scripts_pkey PRIMARY KEY (id);


--
-- Name: slugs slugs_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.slugs
    ADD CONSTRAINT slugs_pkey PRIMARY KEY (id);


--
-- Name: stem stem_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.stem
    ADD CONSTRAINT stem_pkey PRIMARY KEY (stem_id);


--
-- Name: stem stem_value_key; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.stem
    ADD CONSTRAINT stem_value_key UNIQUE (value);


--
-- Name: stems stems_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.stems
    ADD CONSTRAINT stems_pkey PRIMARY KEY (id);


--
-- Name: ayah surah_ayah_key; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.ayah
    ADD CONSTRAINT surah_ayah_key UNIQUE (surah_id, ayah_num);


--
-- Name: surah surah_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.surah
    ADD CONSTRAINT surah_pkey PRIMARY KEY (surah_id);


--
-- Name: tafsirs tafsirs_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.tafsirs
    ADD CONSTRAINT tafsirs_pkey PRIMARY KEY (id);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: tajweed_words tajweed_words_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.tajweed_words
    ADD CONSTRAINT tajweed_words_pkey PRIMARY KEY (id);


--
-- Name: token token_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.token
    ADD CONSTRAINT token_pkey PRIMARY KEY (token_id);


--
-- Name: token token_value_key; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.token
    ADD CONSTRAINT token_value_key UNIQUE (value);


--
-- Name: tokens tokens_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.tokens
    ADD CONSTRAINT tokens_pkey PRIMARY KEY (id);


--
-- Name: topics topics_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.topics
    ADD CONSTRAINT topics_pkey PRIMARY KEY (id);


--
-- Name: translated_names translated_names_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.translated_names
    ADD CONSTRAINT translated_names_pkey PRIMARY KEY (id);


--
-- Name: word_translation translation_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_translation
    ADD CONSTRAINT translation_pkey PRIMARY KEY (translation_id);


--
-- Name: word_translation translation_word_id_language_code_key; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_translation
    ADD CONSTRAINT translation_word_id_language_code_key UNIQUE (word_id, language_code);


--
-- Name: translations translations_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.translations
    ADD CONSTRAINT translations_pkey PRIMARY KEY (id);


--
-- Name: transliterations transliterations_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.transliterations
    ADD CONSTRAINT transliterations_pkey PRIMARY KEY (id);


--
-- Name: verse_lemmas verse_lemmas_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.verse_lemmas
    ADD CONSTRAINT verse_lemmas_pkey PRIMARY KEY (id);


--
-- Name: verse_pages verse_pages_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.verse_pages
    ADD CONSTRAINT verse_pages_pkey PRIMARY KEY (id);


--
-- Name: verse_roots verse_roots_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.verse_roots
    ADD CONSTRAINT verse_roots_pkey PRIMARY KEY (id);


--
-- Name: verse_stems verse_stems_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.verse_stems
    ADD CONSTRAINT verse_stems_pkey PRIMARY KEY (id);


--
-- Name: verse_topics verse_topics_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.verse_topics
    ADD CONSTRAINT verse_topics_pkey PRIMARY KEY (id);


--
-- Name: verses verses_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.verses
    ADD CONSTRAINT verses_pkey PRIMARY KEY (id);


--
-- Name: view view_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.view
    ADD CONSTRAINT view_pkey PRIMARY KEY (view_id);


--
-- Name: word word_ayah_key_position_key; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word
    ADD CONSTRAINT word_ayah_key_position_key UNIQUE (ayah_key, "position");


--
-- Name: word_corpuses word_corpuses_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_corpuses
    ADD CONSTRAINT word_corpuses_pkey PRIMARY KEY (id);


--
-- Name: word_font word_font_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_font
    ADD CONSTRAINT word_font_pkey PRIMARY KEY (resource_id, ayah_key, "position");


--
-- Name: word_lemma word_lemma_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_lemma
    ADD CONSTRAINT word_lemma_pkey PRIMARY KEY (word_id, lemma_id, "position");


--
-- Name: word_mistakes word_mistakes_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_mistakes
    ADD CONSTRAINT word_mistakes_pkey PRIMARY KEY (id);


--
-- Name: word word_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word
    ADD CONSTRAINT word_pkey PRIMARY KEY (word_id);


--
-- Name: word_root word_root_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_root
    ADD CONSTRAINT word_root_pkey PRIMARY KEY (word_id, root_id, "position");


--
-- Name: word_stem word_stem_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_stem
    ADD CONSTRAINT word_stem_pkey PRIMARY KEY (word_id, stem_id, "position");


--
-- Name: word_texts word_texts_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_texts
    ADD CONSTRAINT word_texts_pkey PRIMARY KEY (script_id, word_id);


--
-- Name: word_translations word_translations_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_translations
    ADD CONSTRAINT word_translations_pkey PRIMARY KEY (id);


--
-- Name: word_transliteration word_transliteration_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_transliteration
    ADD CONSTRAINT word_transliteration_pkey PRIMARY KEY (transliteration_id);


--
-- Name: words words_pkey; Type: CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.words
    ADD CONSTRAINT words_pkey PRIMARY KEY (id);


--
-- Name: index_audio.file_on_ayah_key; Type: INDEX; Schema: audio; Owner: -
--

CREATE INDEX "index_audio.file_on_ayah_key" ON audio.file USING btree (ayah_key);


--
-- Name: index_content.surah_infos_on_surah_id; Type: INDEX; Schema: content; Owner: -
--

CREATE INDEX "index_content.surah_infos_on_surah_id" ON content.surah_infos USING btree (surah_id);


--
-- Name: index_content.translation_on_ayah_key; Type: INDEX; Schema: content; Owner: -
--

CREATE INDEX "index_content.translation_on_ayah_key" ON content.translation USING btree (ayah_key);


--
-- Name: tafsir_resource_id_md5_idx; Type: INDEX; Schema: content; Owner: -
--

CREATE UNIQUE INDEX tafsir_resource_id_md5_idx ON content.tafsir USING btree (resource_id, md5(text));


--
-- Name: index_media.content_on_ayah_key; Type: INDEX; Schema: media; Owner: -
--

CREATE INDEX "index_media.content_on_ayah_key" ON media.content USING btree (ayah_key);


--
-- Name: index_media.content_on_resource_id; Type: INDEX; Schema: media; Owner: -
--

CREATE INDEX "index_media.content_on_resource_id" ON media.content USING btree (resource_id);


--
-- Name: ayah_surah_id_idx; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX ayah_surah_id_idx ON quran.ayah USING btree (surah_id);


--
-- Name: idx_on_chapter_number_verse_number_c8025f0b6e; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX idx_on_chapter_number_verse_number_c8025f0b6e ON quran.morphology_word_tokens USING btree (chapter_number, verse_number);


--
-- Name: idx_on_sentence_id_position_in_sentence_54027ba1ac; Type: INDEX; Schema: quran; Owner: -
--

CREATE UNIQUE INDEX idx_on_sentence_id_position_in_sentence_54027ba1ac ON quran.morphology_word_tokens USING btree (sentence_id, position_in_sentence);


--
-- Name: index_api_client_request_stats_on_api_client_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_api_client_request_stats_on_api_client_id ON quran.api_client_request_stats USING btree (api_client_id);


--
-- Name: index_api_client_request_stats_on_date; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_api_client_request_stats_on_date ON quran.api_client_request_stats USING btree (date);


--
-- Name: index_api_clients_on_active; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_api_clients_on_active ON quran.api_clients USING btree (active);


--
-- Name: index_api_clients_on_api_key; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_api_clients_on_api_key ON quran.api_clients USING btree (api_key);


--
-- Name: index_arabic_transliterations_on_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_arabic_transliterations_on_verse_id ON quran.arabic_transliterations USING btree (verse_id);


--
-- Name: index_arabic_transliterations_on_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_arabic_transliterations_on_word_id ON quran.arabic_transliterations USING btree (word_id);


--
-- Name: index_audio_chapter_audio_files_on_audio_recitation_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_chapter_audio_files_on_audio_recitation_id ON quran.audio_chapter_audio_files USING btree (audio_recitation_id);


--
-- Name: index_audio_chapter_audio_files_on_chapter_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_chapter_audio_files_on_chapter_id ON quran.audio_chapter_audio_files USING btree (chapter_id);


--
-- Name: index_audio_chapter_audio_files_on_format; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_chapter_audio_files_on_format ON quran.audio_chapter_audio_files USING btree (format);


--
-- Name: index_audio_chapter_audio_files_on_resource_content_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_chapter_audio_files_on_resource_content_id ON quran.audio_chapter_audio_files USING btree (resource_content_id);


--
-- Name: index_audio_files_on_chapter_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_files_on_chapter_id ON quran.audio_files USING btree (chapter_id);


--
-- Name: index_audio_files_on_chapter_id_and_verse_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_files_on_chapter_id_and_verse_number ON quran.audio_files USING btree (chapter_id, verse_number);


--
-- Name: index_audio_files_on_has_repetition; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_files_on_has_repetition ON quran.audio_files USING btree (has_repetition);


--
-- Name: index_audio_files_on_hizb_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_files_on_hizb_number ON quran.audio_files USING btree (hizb_number);


--
-- Name: index_audio_files_on_is_enabled; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_files_on_is_enabled ON quran.audio_files USING btree (is_enabled);


--
-- Name: index_audio_files_on_juz_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_files_on_juz_number ON quran.audio_files USING btree (juz_number);


--
-- Name: index_audio_files_on_manzil_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_files_on_manzil_number ON quran.audio_files USING btree (manzil_number);


--
-- Name: index_audio_files_on_page_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_files_on_page_number ON quran.audio_files USING btree (page_number);


--
-- Name: index_audio_files_on_recitation_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_files_on_recitation_id ON quran.audio_files USING btree (recitation_id);


--
-- Name: index_audio_files_on_rub_el_hizb_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_files_on_rub_el_hizb_number ON quran.audio_files USING btree (rub_el_hizb_number);


--
-- Name: index_audio_files_on_ruku_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_files_on_ruku_number ON quran.audio_files USING btree (ruku_number);


--
-- Name: index_audio_files_on_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_files_on_verse_id ON quran.audio_files USING btree (verse_id);


--
-- Name: index_audio_files_on_verse_key; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_files_on_verse_key ON quran.audio_files USING btree (verse_key);


--
-- Name: index_audio_recitations_on_approved; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_recitations_on_approved ON quran.audio_recitations USING btree (approved);


--
-- Name: index_audio_recitations_on_name; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_recitations_on_name ON quran.audio_recitations USING btree (name);


--
-- Name: index_audio_recitations_on_priority; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_recitations_on_priority ON quran.audio_recitations USING btree (priority);


--
-- Name: index_audio_recitations_on_recitation_style_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_recitations_on_recitation_style_id ON quran.audio_recitations USING btree (recitation_style_id);


--
-- Name: index_audio_recitations_on_reciter_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_recitations_on_reciter_id ON quran.audio_recitations USING btree (reciter_id);


--
-- Name: index_audio_recitations_on_relative_path; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_recitations_on_relative_path ON quran.audio_recitations USING btree (relative_path);


--
-- Name: index_audio_recitations_on_resource_content_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_recitations_on_resource_content_id ON quran.audio_recitations USING btree (resource_content_id);


--
-- Name: index_audio_recitations_on_riwayah_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_recitations_on_riwayah_id ON quran.audio_recitations USING btree (riwayah_id);


--
-- Name: index_audio_recitations_on_section_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_recitations_on_section_id ON quran.audio_recitations USING btree (section_id);


--
-- Name: index_audio_related_recitation; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_related_recitation ON quran.audio_related_recitations USING btree (audio_recitation_id, related_audio_recitation_id);


--
-- Name: index_audio_segments_on_audio_file_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_segments_on_audio_file_id ON quran.audio_segments USING btree (audio_file_id);


--
-- Name: index_audio_segments_on_audio_file_id_and_verse_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE UNIQUE INDEX index_audio_segments_on_audio_file_id_and_verse_number ON quran.audio_segments USING btree (audio_file_id, verse_number);


--
-- Name: index_audio_segments_on_audio_recitation_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_segments_on_audio_recitation_id ON quran.audio_segments USING btree (audio_recitation_id);


--
-- Name: index_audio_segments_on_chapter_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_segments_on_chapter_id ON quran.audio_segments USING btree (chapter_id);


--
-- Name: index_audio_segments_on_has_repetition; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_segments_on_has_repetition ON quran.audio_segments USING btree (has_repetition);


--
-- Name: index_audio_segments_on_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_segments_on_verse_id ON quran.audio_segments USING btree (verse_id);


--
-- Name: index_audio_segments_on_verse_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_audio_segments_on_verse_number ON quran.audio_segments USING btree (verse_number);


--
-- Name: index_ayah_themes_on_chapter_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_ayah_themes_on_chapter_id ON quran.ayah_themes USING btree (chapter_id);


--
-- Name: index_ayah_themes_on_verse_id_from; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_ayah_themes_on_verse_id_from ON quran.ayah_themes USING btree (verse_id_from);


--
-- Name: index_ayah_themes_on_verse_id_to; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_ayah_themes_on_verse_id_to ON quran.ayah_themes USING btree (verse_id_to);


--
-- Name: index_ayah_themes_on_verse_number_from; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_ayah_themes_on_verse_number_from ON quran.ayah_themes USING btree (verse_number_from);


--
-- Name: index_ayah_themes_on_verse_number_to; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_ayah_themes_on_verse_number_to ON quran.ayah_themes USING btree (verse_number_to);


--
-- Name: index_books_on_author_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_books_on_author_id ON quran.books USING btree (author_id);


--
-- Name: index_books_on_resource_content_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_books_on_resource_content_id ON quran.books USING btree (resource_content_id);


--
-- Name: index_chapter_infos_on_chapter_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_chapter_infos_on_chapter_id ON quran.chapter_infos USING btree (chapter_id);


--
-- Name: index_chapter_infos_on_language_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_chapter_infos_on_language_id ON quran.chapter_infos USING btree (language_id);


--
-- Name: index_chapter_infos_on_resource_content_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_chapter_infos_on_resource_content_id ON quran.chapter_infos USING btree (resource_content_id);


--
-- Name: index_chapters_on_chapter_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_chapters_on_chapter_number ON quran.chapters USING btree (chapter_number);


--
-- Name: index_char_types_on_parent_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_char_types_on_parent_id ON quran.char_types USING btree (parent_id);


--
-- Name: index_corpus_word_forms_on_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_corpus_word_forms_on_word_id ON quran.corpus_word_forms USING btree (word_id);


--
-- Name: index_corpus_word_grammars_on_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_corpus_word_grammars_on_word_id ON quran.corpus_word_grammars USING btree (word_id);


--
-- Name: index_corpus_word_grammars_on_word_id_and_position; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_corpus_word_grammars_on_word_id_and_position ON quran.corpus_word_grammars USING btree (word_id, "position");


--
-- Name: index_counting_systems_on_slug; Type: INDEX; Schema: quran; Owner: -
--

CREATE UNIQUE INDEX index_counting_systems_on_slug ON quran.counting_systems USING btree (slug);


--
-- Name: index_dict_word_definition; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_dict_word_definition ON quran.dictionary_root_definitions USING btree (word_root_id);


--
-- Name: index_dictionary_root_examples_on_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_dictionary_root_examples_on_verse_id ON quran.dictionary_root_examples USING btree (verse_id);


--
-- Name: index_dictionary_root_examples_on_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_dictionary_root_examples_on_word_id ON quran.dictionary_root_examples USING btree (word_id);


--
-- Name: index_dictionary_word_roots_on_arabic_trilateral; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_dictionary_word_roots_on_arabic_trilateral ON quran.dictionary_word_roots USING btree (arabic_trilateral);


--
-- Name: index_dictionary_word_roots_on_english_trilateral; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_dictionary_word_roots_on_english_trilateral ON quran.dictionary_word_roots USING btree (english_trilateral);


--
-- Name: index_dictionary_word_roots_on_root_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_dictionary_word_roots_on_root_id ON quran.dictionary_word_roots USING btree (root_id);


--
-- Name: index_dictionary_word_roots_on_root_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_dictionary_word_roots_on_root_number ON quran.dictionary_word_roots USING btree (root_number);


--
-- Name: index_foot_notes_on_language_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_foot_notes_on_language_id ON quran.foot_notes USING btree (language_id);


--
-- Name: index_foot_notes_on_resource_content_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_foot_notes_on_resource_content_id ON quran.foot_notes USING btree (resource_content_id);


--
-- Name: index_foot_notes_on_translation_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_foot_notes_on_translation_id ON quran.foot_notes USING btree (translation_id);


--
-- Name: index_hizbs_on_first_verse_id_and_last_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_hizbs_on_first_verse_id_and_last_verse_id ON quran.hizbs USING btree (first_verse_id, last_verse_id);


--
-- Name: index_hizbs_on_hizb_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_hizbs_on_hizb_number ON quran.hizbs USING btree (hizb_number);


--
-- Name: index_images_on_resource_content_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_images_on_resource_content_id ON quran.images USING btree (resource_content_id);


--
-- Name: index_images_on_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_images_on_verse_id ON quran.images USING btree (verse_id);


--
-- Name: index_juzs_on_first_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_juzs_on_first_verse_id ON quran.juzs USING btree (first_verse_id);


--
-- Name: index_juzs_on_juz_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_juzs_on_juz_number ON quran.juzs USING btree (juz_number);


--
-- Name: index_juzs_on_last_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_juzs_on_last_verse_id ON quran.juzs USING btree (last_verse_id);


--
-- Name: index_languages_on_iso_code; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_languages_on_iso_code ON quran.languages USING btree (iso_code);


--
-- Name: index_languages_on_translations_count; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_languages_on_translations_count ON quran.languages USING btree (translations_count);


--
-- Name: index_manzils_on_first_verse_id_and_last_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_manzils_on_first_verse_id_and_last_verse_id ON quran.manzils USING btree (first_verse_id, last_verse_id);


--
-- Name: index_manzils_on_manzil_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_manzils_on_manzil_number ON quran.manzils USING btree (manzil_number);


--
-- Name: index_media_contents_on_language_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_media_contents_on_language_id ON quran.media_contents USING btree (language_id);


--
-- Name: index_media_contents_on_resource_content_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_media_contents_on_resource_content_id ON quran.media_contents USING btree (resource_content_id);


--
-- Name: index_media_contents_on_resource_type_and_resource_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_media_contents_on_resource_type_and_resource_id ON quran.media_contents USING btree (resource_type, resource_id);


--
-- Name: index_morph_dict_term_translations_on_term_and_locale; Type: INDEX; Schema: quran; Owner: -
--

CREATE UNIQUE INDEX index_morph_dict_term_translations_on_term_and_locale ON quran.morphology_dictionary_term_translations USING btree (term_id, locale);


--
-- Name: index_morph_grammar_term_translations_on_term_and_locale; Type: INDEX; Schema: quran; Owner: -
--

CREATE UNIQUE INDEX index_morph_grammar_term_translations_on_term_and_locale ON quran.morphology_grammar_term_translations USING btree (grammar_term_id, locale);


--
-- Name: index_morphology_dependency_graph_node_edges_on_relation; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_dependency_graph_node_edges_on_relation ON quran.morphology_dependency_graph_node_edges USING btree (relation);


--
-- Name: index_morphology_dependency_graph_node_edges_on_source_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_dependency_graph_node_edges_on_source_id ON quran.morphology_dependency_graph_node_edges USING btree (source_id);


--
-- Name: index_morphology_dependency_graph_node_edges_on_target_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_dependency_graph_node_edges_on_target_id ON quran.morphology_dependency_graph_node_edges USING btree (target_id);


--
-- Name: index_morphology_dependency_graph_node_edges_on_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_dependency_graph_node_edges_on_type ON quran.morphology_dependency_graph_node_edges USING btree (type);


--
-- Name: index_morphology_dependency_graph_nodes_on_graph_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_dependency_graph_nodes_on_graph_id ON quran.morphology_dependency_graph_nodes USING btree (graph_id);


--
-- Name: index_morphology_dependency_graph_nodes_on_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_dependency_graph_nodes_on_type ON quran.morphology_dependency_graph_nodes USING btree (type);


--
-- Name: index_morphology_dependency_graphs_on_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_dependency_graphs_on_verse_id ON quran.morphology_dependency_graphs USING btree (verse_id);


--
-- Name: index_morphology_dependency_graphs_on_verse_id_and_graph_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_dependency_graphs_on_verse_id_and_graph_number ON quran.morphology_dependency_graphs USING btree (verse_id, graph_number);


--
-- Name: index_morphology_derived_words_on_derived_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_derived_words_on_derived_word_id ON quran.morphology_derived_words USING btree (derived_word_id);


--
-- Name: index_morphology_derived_words_on_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_derived_words_on_verse_id ON quran.morphology_derived_words USING btree (verse_id);


--
-- Name: index_morphology_derived_words_on_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_derived_words_on_word_id ON quran.morphology_derived_words USING btree (word_id);


--
-- Name: index_morphology_derived_words_on_word_verb_from_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_derived_words_on_word_verb_from_id ON quran.morphology_derived_words USING btree (word_verb_from_id);


--
-- Name: index_morphology_dictionary_term_translations_on_term_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_dictionary_term_translations_on_term_id ON quran.morphology_dictionary_term_translations USING btree (term_id);


--
-- Name: index_morphology_dictionary_terms_on_key; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_dictionary_terms_on_key ON quran.morphology_dictionary_terms USING btree (key);


--
-- Name: index_morphology_grammar_concepts_on_arabic; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_grammar_concepts_on_arabic ON quran.morphology_grammar_concepts USING btree (arabic);


--
-- Name: index_morphology_grammar_concepts_on_english; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_grammar_concepts_on_english ON quran.morphology_grammar_concepts USING btree (english);


--
-- Name: index_morphology_grammar_patterns_on_arabic; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_grammar_patterns_on_arabic ON quran.morphology_grammar_patterns USING btree (arabic);


--
-- Name: index_morphology_grammar_patterns_on_english; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_grammar_patterns_on_english ON quran.morphology_grammar_patterns USING btree (english);


--
-- Name: index_morphology_grammar_term_translations_on_grammar_term_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_grammar_term_translations_on_grammar_term_id ON quran.morphology_grammar_term_translations USING btree (grammar_term_id);


--
-- Name: index_morphology_grammar_terms_on_category; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_grammar_terms_on_category ON quran.morphology_grammar_terms USING btree (category);


--
-- Name: index_morphology_grammar_terms_on_term; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_grammar_terms_on_term ON quran.morphology_grammar_terms USING btree (term);


--
-- Name: index_morphology_graph_nodes_on_resource; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_graph_nodes_on_resource ON quran.morphology_dependency_graph_nodes USING btree (resource_type, resource_id);


--
-- Name: index_morphology_graphs_on_chapter_verse_graph; Type: INDEX; Schema: quran; Owner: -
--

CREATE UNIQUE INDEX index_morphology_graphs_on_chapter_verse_graph ON quran.morphology_dependency_graphs USING btree (chapter_number, verse_number, graph_number);


--
-- Name: index_morphology_graphs_on_chapter_verse_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_graphs_on_chapter_verse_number ON quran.morphology_dependency_graphs USING btree (chapter_number, verse_number);


--
-- Name: index_morphology_sentences_on_chapter_id_and_first_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_sentences_on_chapter_id_and_first_verse_id ON quran.morphology_sentences USING btree (chapter_id, first_verse_id);


--
-- Name: index_morphology_sentences_on_sentence_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE UNIQUE INDEX index_morphology_sentences_on_sentence_number ON quran.morphology_sentences USING btree (sentence_number);


--
-- Name: index_morphology_word_grammar_concepts_on_grammar_concept_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_grammar_concepts_on_grammar_concept_id ON quran.morphology_word_grammar_concepts USING btree (grammar_concept_id);


--
-- Name: index_morphology_word_grammar_concepts_on_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_grammar_concepts_on_word_id ON quran.morphology_word_grammar_concepts USING btree (word_id);


--
-- Name: index_morphology_word_segments_on_aspect_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_aspect_type ON quran.morphology_word_segments USING btree (aspect_type);


--
-- Name: index_morphology_word_segments_on_case_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_case_type ON quran.morphology_word_segments USING btree (case_type);


--
-- Name: index_morphology_word_segments_on_derivation_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_derivation_type ON quran.morphology_word_segments USING btree (derivation_type);


--
-- Name: index_morphology_word_segments_on_gender_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_gender_type ON quran.morphology_word_segments USING btree (gender_type);


--
-- Name: index_morphology_word_segments_on_grammar_concept_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_grammar_concept_id ON quran.morphology_word_segments USING btree (grammar_concept_id);


--
-- Name: index_morphology_word_segments_on_grammar_role_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_grammar_role_id ON quran.morphology_word_segments USING btree (grammar_role_id);


--
-- Name: index_morphology_word_segments_on_grammar_sub_role_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_grammar_sub_role_id ON quran.morphology_word_segments USING btree (grammar_sub_role_id);


--
-- Name: index_morphology_word_segments_on_grammar_term_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_grammar_term_id ON quran.morphology_word_segments USING btree (grammar_term_id);


--
-- Name: index_morphology_word_segments_on_lemma_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_lemma_id ON quran.morphology_word_segments USING btree (lemma_id);


--
-- Name: index_morphology_word_segments_on_mood_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_mood_type ON quran.morphology_word_segments USING btree (mood_type);


--
-- Name: index_morphology_word_segments_on_number_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_number_type ON quran.morphology_word_segments USING btree (number_type);


--
-- Name: index_morphology_word_segments_on_part_of_speech_key; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_part_of_speech_key ON quran.morphology_word_segments USING btree (part_of_speech_key);


--
-- Name: index_morphology_word_segments_on_person_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_person_type ON quran.morphology_word_segments USING btree (person_type);


--
-- Name: index_morphology_word_segments_on_pos_tags; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_pos_tags ON quran.morphology_word_segments USING btree (pos_tags);


--
-- Name: index_morphology_word_segments_on_position; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_position ON quran.morphology_word_segments USING btree ("position");


--
-- Name: index_morphology_word_segments_on_pronoun_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_pronoun_type ON quran.morphology_word_segments USING btree (pronoun_type);


--
-- Name: index_morphology_word_segments_on_root_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_root_id ON quran.morphology_word_segments USING btree (root_id);


--
-- Name: index_morphology_word_segments_on_segment_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_segment_type ON quran.morphology_word_segments USING btree (segment_type);


--
-- Name: index_morphology_word_segments_on_special_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_special_type ON quran.morphology_word_segments USING btree (special_type);


--
-- Name: index_morphology_word_segments_on_state_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_state_type ON quran.morphology_word_segments USING btree (state_type);


--
-- Name: index_morphology_word_segments_on_text_qpc_hafs; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_text_qpc_hafs ON quran.morphology_word_segments USING btree (text_qpc_hafs);


--
-- Name: index_morphology_word_segments_on_topic_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_topic_id ON quran.morphology_word_segments USING btree (topic_id);


--
-- Name: index_morphology_word_segments_on_voice_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_voice_type ON quran.morphology_word_segments USING btree (voice_type);


--
-- Name: index_morphology_word_segments_on_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_segments_on_word_id ON quran.morphology_word_segments USING btree (word_id);


--
-- Name: index_morphology_word_tokens_on_head_token_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_tokens_on_head_token_id ON quran.morphology_word_tokens USING btree (head_token_id);


--
-- Name: index_morphology_word_tokens_on_lemma_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_tokens_on_lemma_id ON quran.morphology_word_tokens USING btree (lemma_id);


--
-- Name: index_morphology_word_tokens_on_location; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_tokens_on_location ON quran.morphology_word_tokens USING btree (location);


--
-- Name: index_morphology_word_tokens_on_morphology_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_tokens_on_morphology_word_id ON quran.morphology_word_tokens USING btree (morphology_word_id);


--
-- Name: index_morphology_word_tokens_on_pos_key; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_tokens_on_pos_key ON quran.morphology_word_tokens USING btree (pos_key);


--
-- Name: index_morphology_word_tokens_on_rel_label; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_tokens_on_rel_label ON quran.morphology_word_tokens USING btree (rel_label);


--
-- Name: index_morphology_word_tokens_on_root_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_tokens_on_root_id ON quran.morphology_word_tokens USING btree (root_id);


--
-- Name: index_morphology_word_tokens_on_segment_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_tokens_on_segment_type ON quran.morphology_word_tokens USING btree (segment_type);


--
-- Name: index_morphology_word_tokens_on_token_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_tokens_on_token_type ON quran.morphology_word_tokens USING btree (token_type);


--
-- Name: index_morphology_word_tokens_on_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_tokens_on_word_id ON quran.morphology_word_tokens USING btree (word_id);


--
-- Name: index_morphology_word_verb_forms_on_name; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_verb_forms_on_name ON quran.morphology_word_verb_forms USING btree (name);


--
-- Name: index_morphology_word_verb_forms_on_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_word_verb_forms_on_word_id ON quran.morphology_word_verb_forms USING btree (word_id);


--
-- Name: index_morphology_words_on_grammar_base_pattern_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_words_on_grammar_base_pattern_id ON quran.morphology_words USING btree (grammar_base_pattern_id);


--
-- Name: index_morphology_words_on_grammar_pattern_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_words_on_grammar_pattern_id ON quran.morphology_words USING btree (grammar_pattern_id);


--
-- Name: index_morphology_words_on_location; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_words_on_location ON quran.morphology_words USING btree (location);


--
-- Name: index_morphology_words_on_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_words_on_verse_id ON quran.morphology_words USING btree (verse_id);


--
-- Name: index_morphology_words_on_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_morphology_words_on_word_id ON quran.morphology_words USING btree (word_id);


--
-- Name: index_mushaf_juzs_on_first_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_mushaf_juzs_on_first_verse_id ON quran.mushaf_juzs USING btree (first_verse_id);


--
-- Name: index_mushaf_juzs_on_juz_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_mushaf_juzs_on_juz_id ON quran.mushaf_juzs USING btree (juz_id);


--
-- Name: index_mushaf_juzs_on_juz_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_mushaf_juzs_on_juz_number ON quran.mushaf_juzs USING btree (juz_number);


--
-- Name: index_mushaf_juzs_on_last_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_mushaf_juzs_on_last_verse_id ON quran.mushaf_juzs USING btree (last_verse_id);


--
-- Name: index_mushaf_juzs_on_mushaf_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_mushaf_juzs_on_mushaf_id ON quran.mushaf_juzs USING btree (mushaf_id);


--
-- Name: index_mushaf_juzs_on_mushaf_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_mushaf_juzs_on_mushaf_type ON quran.mushaf_juzs USING btree (mushaf_type);


--
-- Name: index_mushaf_pages_on_lines_count; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_mushaf_pages_on_lines_count ON quran.mushaf_pages USING btree (lines_count);


--
-- Name: index_mushaf_pages_on_mushaf_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_mushaf_pages_on_mushaf_id ON quran.mushaf_pages USING btree (mushaf_id);


--
-- Name: index_mushaf_pages_on_page_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_mushaf_pages_on_page_number ON quran.mushaf_pages USING btree (page_number);


--
-- Name: index_mushaf_words_on_mushaf_id_and_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_mushaf_words_on_mushaf_id_and_word_id ON quran.mushaf_words USING btree (mushaf_id, word_id);


--
-- Name: index_mushafs_on_enabled; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_mushafs_on_enabled ON quran.mushafs USING btree (enabled);


--
-- Name: index_mushafs_on_is_default; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_mushafs_on_is_default ON quran.mushafs USING btree (is_default);


--
-- Name: index_mushafs_on_qirat_type_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_mushafs_on_qirat_type_id ON quran.mushafs USING btree (qirat_type_id);


--
-- Name: index_mushafs_on_riwayah_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_mushafs_on_riwayah_id ON quran.mushafs USING btree (riwayah_id);


--
-- Name: index_mushas_pages_on_page_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_mushas_pages_on_page_number ON quran.mushas_pages USING btree (page_number);


--
-- Name: index_navigation_search_records_on_result_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_navigation_search_records_on_result_type ON quran.navigation_search_records USING btree (result_type);


--
-- Name: index_navigation_search_records_on_searchable_record; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_navigation_search_records_on_searchable_record ON quran.navigation_search_records USING btree (searchable_record_type, searchable_record_id);


--
-- Name: index_navigation_search_records_on_text; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_navigation_search_records_on_text ON quran.navigation_search_records USING btree (text);


--
-- Name: index_on_audio_segments_median_time; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_on_audio_segments_median_time ON quran.audio_segments USING btree (audio_recitation_id, chapter_id, verse_id, timestamp_median);


--
-- Name: index_on_dict_word_example_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_on_dict_word_example_id ON quran.dictionary_root_examples USING btree (word_root_id);


--
-- Name: index_on_mushad_word_position; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_on_mushad_word_position ON quran.mushaf_words USING btree (mushaf_id, verse_id, position_in_verse);


--
-- Name: index_on_mushaf_word_position; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_on_mushaf_word_position ON quran.mushaf_words USING btree (mushaf_id, verse_id, position_in_page);


--
-- Name: index_on_radio_audio_files; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_on_radio_audio_files ON quran.radio_station_audio_files USING btree (radio_station_id, chapter_audio_file_id, chapter_id);


--
-- Name: index_on_resource_tag; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_on_resource_tag ON quran.resource_tags USING btree (tag_id, resource_id, resource_type);


--
-- Name: index_qiraat_on_counting_system_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_qiraat_on_counting_system_id ON quran.qiraat USING btree (counting_system_id);


--
-- Name: index_qiraat_on_slug; Type: INDEX; Schema: quran; Owner: -
--

CREATE UNIQUE INDEX index_qiraat_on_slug ON quran.qiraat USING btree (slug);


--
-- Name: index_quran.ayah_on_ayah_key; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX "index_quran.ayah_on_ayah_key" ON quran.ayah USING btree (ayah_key);


--
-- Name: index_quran.word_font_on_ayah_key; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX "index_quran.word_font_on_ayah_key" ON quran.word_font USING btree (ayah_key);


--
-- Name: index_quran.word_transliteration_on_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX "index_quran.word_transliteration_on_word_id" ON quran.word_transliteration USING btree (word_id);


--
-- Name: index_quran_script_by_verses_on_chapter_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_quran_script_by_verses_on_chapter_id ON quran.quran_script_by_verses USING btree (chapter_id);


--
-- Name: index_quran_script_by_verses_on_key; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_quran_script_by_verses_on_key ON quran.quran_script_by_verses USING btree (key);


--
-- Name: index_quran_script_by_verses_on_qirat_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_quran_script_by_verses_on_qirat_id ON quran.quran_script_by_verses USING btree (qirat_id);


--
-- Name: index_quran_script_by_verses_on_resource_content_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_quran_script_by_verses_on_resource_content_id ON quran.quran_script_by_verses USING btree (resource_content_id);


--
-- Name: index_quran_script_by_verses_on_text; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_quran_script_by_verses_on_text ON quran.quran_script_by_verses USING btree (text);


--
-- Name: index_quran_script_by_verses_on_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_quran_script_by_verses_on_verse_id ON quran.quran_script_by_verses USING btree (verse_id);


--
-- Name: index_quran_script_by_verses_on_verse_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_quran_script_by_verses_on_verse_number ON quran.quran_script_by_verses USING btree (verse_number);


--
-- Name: index_quran_script_by_words_on_chapter_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_quran_script_by_words_on_chapter_id ON quran.quran_script_by_words USING btree (chapter_id);


--
-- Name: index_quran_script_by_words_on_key; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_quran_script_by_words_on_key ON quran.quran_script_by_words USING btree (key);


--
-- Name: index_quran_script_by_words_on_qirat_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_quran_script_by_words_on_qirat_id ON quran.quran_script_by_words USING btree (qirat_id);


--
-- Name: index_quran_script_by_words_on_resource_content_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_quran_script_by_words_on_resource_content_id ON quran.quran_script_by_words USING btree (resource_content_id);


--
-- Name: index_quran_script_by_words_on_text; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_quran_script_by_words_on_text ON quran.quran_script_by_words USING btree (text);


--
-- Name: index_quran_script_by_words_on_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_quran_script_by_words_on_verse_id ON quran.quran_script_by_words USING btree (verse_id);


--
-- Name: index_quran_script_by_words_on_verse_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_quran_script_by_words_on_verse_number ON quran.quran_script_by_words USING btree (verse_number);


--
-- Name: index_quran_script_by_words_on_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_quran_script_by_words_on_word_id ON quran.quran_script_by_words USING btree (word_id);


--
-- Name: index_quran_script_by_words_on_word_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_quran_script_by_words_on_word_number ON quran.quran_script_by_words USING btree (word_number);


--
-- Name: index_quran_scripts_on_record; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_quran_scripts_on_record ON quran.quran_scripts USING btree (record_type, record_id);


--
-- Name: index_quran_scripts_on_resource_content_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_quran_scripts_on_resource_content_id ON quran.quran_scripts USING btree (resource_content_id);


--
-- Name: index_radio_stations_on_audio_recitation_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_radio_stations_on_audio_recitation_id ON quran.radio_stations USING btree (audio_recitation_id);


--
-- Name: index_radio_stations_on_parent_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_radio_stations_on_parent_id ON quran.radio_stations USING btree (parent_id);


--
-- Name: index_radio_stations_on_priority; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_radio_stations_on_priority ON quran.radio_stations USING btree (priority);


--
-- Name: index_raw_data_ayah_records_on_raw_resource_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_raw_data_ayah_records_on_raw_resource_id ON quran.raw_data_ayah_records USING btree (raw_resource_id);


--
-- Name: index_raw_data_ayah_records_on_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_raw_data_ayah_records_on_verse_id ON quran.raw_data_ayah_records USING btree (verse_id);


--
-- Name: index_raw_data_resources_on_key; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_raw_data_resources_on_key ON quran.raw_data_resources USING btree (key);


--
-- Name: index_raw_data_resources_on_sub_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_raw_data_resources_on_sub_type ON quran.raw_data_resources USING btree (sub_type);


--
-- Name: index_recitation_styles_on_slug; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_recitation_styles_on_slug ON quran.recitation_styles USING btree (slug);


--
-- Name: index_recitations_on_gapless_recitation_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE UNIQUE INDEX index_recitations_on_gapless_recitation_id ON quran.recitations USING btree (gapless_recitation_id);


--
-- Name: index_recitations_on_qirat_type_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_recitations_on_qirat_type_id ON quran.recitations USING btree (qirat_type_id);


--
-- Name: index_recitations_on_recitation_style_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_recitations_on_recitation_style_id ON quran.recitations USING btree (recitation_style_id);


--
-- Name: index_recitations_on_reciter_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_recitations_on_reciter_id ON quran.recitations USING btree (reciter_id);


--
-- Name: index_recitations_on_resource_content_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_recitations_on_resource_content_id ON quran.recitations USING btree (resource_content_id);


--
-- Name: index_recitations_on_riwayah_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_recitations_on_riwayah_id ON quran.recitations USING btree (riwayah_id);


--
-- Name: index_related_topics_on_topic_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_related_topics_on_topic_id ON quran.related_topics USING btree (topic_id);


--
-- Name: index_resource_content_stats_on_platform; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_resource_content_stats_on_platform ON quran.resource_content_stats USING btree (platform);


--
-- Name: index_resource_content_stats_on_resource_content_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_resource_content_stats_on_resource_content_id ON quran.resource_content_stats USING btree (resource_content_id);


--
-- Name: index_resource_contents_on_approved; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_resource_contents_on_approved ON quran.resource_contents USING btree (approved);


--
-- Name: index_resource_contents_on_author_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_resource_contents_on_author_id ON quran.resource_contents USING btree (author_id);


--
-- Name: index_resource_contents_on_cardinality_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_resource_contents_on_cardinality_type ON quran.resource_contents USING btree (cardinality_type);


--
-- Name: index_resource_contents_on_data_source_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_resource_contents_on_data_source_id ON quran.resource_contents USING btree (data_source_id);


--
-- Name: index_resource_contents_on_language_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_resource_contents_on_language_id ON quran.resource_contents USING btree (language_id);


--
-- Name: index_resource_contents_on_meta_data; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_resource_contents_on_meta_data ON quran.resource_contents USING gin (meta_data);


--
-- Name: index_resource_contents_on_mobile_translation_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_resource_contents_on_mobile_translation_id ON quran.resource_contents USING btree (mobile_translation_id);


--
-- Name: index_resource_contents_on_priority; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_resource_contents_on_priority ON quran.resource_contents USING btree (priority);


--
-- Name: index_resource_contents_on_resource_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_resource_contents_on_resource_id ON quran.resource_contents USING btree (resource_id);


--
-- Name: index_resource_contents_on_resource_type_name; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_resource_contents_on_resource_type_name ON quran.resource_contents USING btree (resource_type_name);


--
-- Name: index_resource_contents_on_slug; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_resource_contents_on_slug ON quran.resource_contents USING btree (slug);


--
-- Name: index_resource_contents_on_sub_type; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_resource_contents_on_sub_type ON quran.resource_contents USING btree (sub_type);


--
-- Name: index_riwayat_on_enabled; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_riwayat_on_enabled ON quran.riwayat USING btree (enabled);


--
-- Name: index_riwayat_on_qiraah_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_riwayat_on_qiraah_id ON quran.riwayat USING btree (qiraah_id);


--
-- Name: index_riwayat_on_slug; Type: INDEX; Schema: quran; Owner: -
--

CREATE UNIQUE INDEX index_riwayat_on_slug ON quran.riwayat USING btree (slug);


--
-- Name: index_root_details_on_language_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_root_details_on_language_id ON quran.root_details USING btree (language_id);


--
-- Name: index_root_details_on_resource_content_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_root_details_on_resource_content_id ON quran.root_details USING btree (resource_content_id);


--
-- Name: index_root_details_on_root_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_root_details_on_root_id ON quran.root_details USING btree (root_id);


--
-- Name: index_root_details_on_token_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_root_details_on_token_id ON quran.root_details USING btree (token_id);


--
-- Name: index_roots_on_arabic_trilateral; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_roots_on_arabic_trilateral ON quran.roots USING btree (arabic_trilateral);


--
-- Name: index_roots_on_english_trilateral; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_roots_on_english_trilateral ON quran.roots USING btree (english_trilateral);


--
-- Name: index_roots_on_text_clean; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_roots_on_text_clean ON quran.roots USING btree (text_clean);


--
-- Name: index_roots_on_text_uthmani; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_roots_on_text_uthmani ON quran.roots USING btree (text_uthmani);


--
-- Name: index_rub_el_hizbs_on_first_verse_id_and_last_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_rub_el_hizbs_on_first_verse_id_and_last_verse_id ON quran.rub_el_hizbs USING btree (first_verse_id, last_verse_id);


--
-- Name: index_rub_el_hizbs_on_rub_el_hizb_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_rub_el_hizbs_on_rub_el_hizb_number ON quran.rub_el_hizbs USING btree (rub_el_hizb_number);


--
-- Name: index_rukus_on_first_verse_id_and_last_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_rukus_on_first_verse_id_and_last_verse_id ON quran.rukus USING btree (first_verse_id, last_verse_id);


--
-- Name: index_rukus_on_ruku_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_rukus_on_ruku_number ON quran.rukus USING btree (ruku_number);


--
-- Name: index_scripts_on_column_name; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_scripts_on_column_name ON quran.scripts USING btree (column_name);


--
-- Name: index_scripts_on_riwayah_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_scripts_on_riwayah_id ON quran.scripts USING btree (riwayah_id);


--
-- Name: index_scripts_on_slug; Type: INDEX; Schema: quran; Owner: -
--

CREATE UNIQUE INDEX index_scripts_on_slug ON quran.scripts USING btree (slug);


--
-- Name: index_slugs_on_chapter_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_slugs_on_chapter_id ON quran.slugs USING btree (chapter_id);


--
-- Name: index_slugs_on_chapter_id_and_slug; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_slugs_on_chapter_id_and_slug ON quran.slugs USING btree (chapter_id, slug);


--
-- Name: index_slugs_on_is_default; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_slugs_on_is_default ON quran.slugs USING btree (is_default);


--
-- Name: index_slugs_on_language_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_slugs_on_language_id ON quran.slugs USING btree (language_id);


--
-- Name: index_slugs_on_language_priority; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_slugs_on_language_priority ON quran.slugs USING btree (language_priority);


--
-- Name: index_tafsirs_on_chapter_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tafsirs_on_chapter_id ON quran.tafsirs USING btree (chapter_id);


--
-- Name: index_tafsirs_on_chapter_id_and_verse_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tafsirs_on_chapter_id_and_verse_number ON quran.tafsirs USING btree (chapter_id, verse_number);


--
-- Name: index_tafsirs_on_end_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tafsirs_on_end_verse_id ON quran.tafsirs USING btree (end_verse_id);


--
-- Name: index_tafsirs_on_hizb_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tafsirs_on_hizb_number ON quran.tafsirs USING btree (hizb_number);


--
-- Name: index_tafsirs_on_juz_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tafsirs_on_juz_number ON quran.tafsirs USING btree (juz_number);


--
-- Name: index_tafsirs_on_language_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tafsirs_on_language_id ON quran.tafsirs USING btree (language_id);


--
-- Name: index_tafsirs_on_manzil_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tafsirs_on_manzil_number ON quran.tafsirs USING btree (manzil_number);


--
-- Name: index_tafsirs_on_page_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tafsirs_on_page_number ON quran.tafsirs USING btree (page_number);


--
-- Name: index_tafsirs_on_resource_content_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tafsirs_on_resource_content_id ON quran.tafsirs USING btree (resource_content_id);


--
-- Name: index_tafsirs_on_rub_el_hizb_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tafsirs_on_rub_el_hizb_number ON quran.tafsirs USING btree (rub_el_hizb_number);


--
-- Name: index_tafsirs_on_ruku_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tafsirs_on_ruku_number ON quran.tafsirs USING btree (ruku_number);


--
-- Name: index_tafsirs_on_start_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tafsirs_on_start_verse_id ON quran.tafsirs USING btree (start_verse_id);


--
-- Name: index_tafsirs_on_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tafsirs_on_verse_id ON quran.tafsirs USING btree (verse_id);


--
-- Name: index_tafsirs_on_verse_key; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tafsirs_on_verse_key ON quran.tafsirs USING btree (verse_key);


--
-- Name: index_tags_on_name; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tags_on_name ON quran.tags USING btree (name);


--
-- Name: index_tajweed_words_on_location; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tajweed_words_on_location ON quran.tajweed_words USING btree (location);


--
-- Name: index_tajweed_words_on_mushaf_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tajweed_words_on_mushaf_id ON quran.tajweed_words USING btree (mushaf_id);


--
-- Name: index_tajweed_words_on_position; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tajweed_words_on_position ON quran.tajweed_words USING btree ("position");


--
-- Name: index_tajweed_words_on_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tajweed_words_on_verse_id ON quran.tajweed_words USING btree (verse_id);


--
-- Name: index_tajweed_words_on_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tajweed_words_on_word_id ON quran.tajweed_words USING btree (word_id);


--
-- Name: index_tokens_on_record_type_and_record_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tokens_on_record_type_and_record_id ON quran.tokens USING btree (record_type, record_id);


--
-- Name: index_tokens_on_resource_content_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tokens_on_resource_content_id ON quran.tokens USING btree (resource_content_id);


--
-- Name: index_tokens_on_text; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_tokens_on_text ON quran.tokens USING btree (text);


--
-- Name: index_topics_on_depth; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_topics_on_depth ON quran.topics USING btree (depth);


--
-- Name: index_topics_on_name; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_topics_on_name ON quran.topics USING btree (name);


--
-- Name: index_topics_on_ontology; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_topics_on_ontology ON quran.topics USING btree (ontology);


--
-- Name: index_topics_on_ontology_parent_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_topics_on_ontology_parent_id ON quran.topics USING btree (ontology_parent_id);


--
-- Name: index_topics_on_parent_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_topics_on_parent_id ON quran.topics USING btree (parent_id);


--
-- Name: index_topics_on_thematic; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_topics_on_thematic ON quran.topics USING btree (thematic);


--
-- Name: index_topics_on_thematic_parent_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_topics_on_thematic_parent_id ON quran.topics USING btree (thematic_parent_id);


--
-- Name: index_translated_names_on_language_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_translated_names_on_language_id ON quran.translated_names USING btree (language_id);


--
-- Name: index_translated_names_on_language_priority; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_translated_names_on_language_priority ON quran.translated_names USING btree (language_priority);


--
-- Name: index_translated_names_on_resource_type_and_resource_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_translated_names_on_resource_type_and_resource_id ON quran.translated_names USING btree (resource_type, resource_id);


--
-- Name: index_translations_on_chapter_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_translations_on_chapter_id ON quran.translations USING btree (chapter_id);


--
-- Name: index_translations_on_chapter_id_and_verse_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_translations_on_chapter_id_and_verse_number ON quran.translations USING btree (chapter_id, verse_number);


--
-- Name: index_translations_on_footnotes_count; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_translations_on_footnotes_count ON quran.translations USING btree (footnotes_count);


--
-- Name: index_translations_on_hizb_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_translations_on_hizb_number ON quran.translations USING btree (hizb_number);


--
-- Name: index_translations_on_juz_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_translations_on_juz_number ON quran.translations USING btree (juz_number);


--
-- Name: index_translations_on_language_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_translations_on_language_id ON quran.translations USING btree (language_id);


--
-- Name: index_translations_on_manzil_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_translations_on_manzil_number ON quran.translations USING btree (manzil_number);


--
-- Name: index_translations_on_page_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_translations_on_page_number ON quran.translations USING btree (page_number);


--
-- Name: index_translations_on_priority; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_translations_on_priority ON quran.translations USING btree (priority);


--
-- Name: index_translations_on_resource_content_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_translations_on_resource_content_id ON quran.translations USING btree (resource_content_id);


--
-- Name: index_translations_on_rub_el_hizb_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_translations_on_rub_el_hizb_number ON quran.translations USING btree (rub_el_hizb_number);


--
-- Name: index_translations_on_ruku_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_translations_on_ruku_number ON quran.translations USING btree (ruku_number);


--
-- Name: index_translations_on_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_translations_on_verse_id ON quran.translations USING btree (verse_id);


--
-- Name: index_translations_on_verse_key; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_translations_on_verse_key ON quran.translations USING btree (verse_key);


--
-- Name: index_transliterations_on_language_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_transliterations_on_language_id ON quran.transliterations USING btree (language_id);


--
-- Name: index_transliterations_on_resource_content_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_transliterations_on_resource_content_id ON quran.transliterations USING btree (resource_content_id);


--
-- Name: index_transliterations_on_resource_type_and_resource_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_transliterations_on_resource_type_and_resource_id ON quran.transliterations USING btree (resource_type, resource_id);


--
-- Name: index_verse_pages_on_page_number_and_mushaf_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_verse_pages_on_page_number_and_mushaf_id ON quran.verse_pages USING btree (page_number, mushaf_id);


--
-- Name: index_verse_pages_on_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_verse_pages_on_verse_id ON quran.verse_pages USING btree (verse_id);


--
-- Name: index_verse_topics_on_topic_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_verse_topics_on_topic_id ON quran.verse_topics USING btree (topic_id);


--
-- Name: index_verse_topics_on_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_verse_topics_on_verse_id ON quran.verse_topics USING btree (verse_id);


--
-- Name: index_verses_on_chapter_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_verses_on_chapter_id ON quran.verses USING btree (chapter_id);


--
-- Name: index_verses_on_hizb_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_verses_on_hizb_number ON quran.verses USING btree (hizb_number);


--
-- Name: index_verses_on_juz_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_verses_on_juz_number ON quran.verses USING btree (juz_number);


--
-- Name: index_verses_on_manzil_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_verses_on_manzil_number ON quran.verses USING btree (manzil_number);


--
-- Name: index_verses_on_rub_el_hizb_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_verses_on_rub_el_hizb_number ON quran.verses USING btree (rub_el_hizb_number);


--
-- Name: index_verses_on_ruku_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_verses_on_ruku_number ON quran.verses USING btree (ruku_number);


--
-- Name: index_verses_on_verse_index; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_verses_on_verse_index ON quran.verses USING btree (verse_index);


--
-- Name: index_verses_on_verse_key; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_verses_on_verse_key ON quran.verses USING btree (verse_key);


--
-- Name: index_verses_on_verse_lemma_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_verses_on_verse_lemma_id ON quran.verses USING btree (verse_lemma_id);


--
-- Name: index_verses_on_verse_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_verses_on_verse_number ON quran.verses USING btree (verse_number);


--
-- Name: index_verses_on_verse_root_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_verses_on_verse_root_id ON quran.verses USING btree (verse_root_id);


--
-- Name: index_verses_on_verse_stem_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_verses_on_verse_stem_id ON quran.verses USING btree (verse_stem_id);


--
-- Name: index_verses_on_words_count; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_verses_on_words_count ON quran.verses USING btree (words_count);


--
-- Name: index_word_corpuses_on_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_word_corpuses_on_word_id ON quran.word_corpuses USING btree (word_id);


--
-- Name: index_word_mistakes_on_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_word_mistakes_on_word_id ON quran.word_mistakes USING btree (word_id);


--
-- Name: index_word_mistakes_on_word_id_and_char_start_and_char_end; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_word_mistakes_on_word_id_and_char_start_and_char_end ON quran.word_mistakes USING btree (word_id, char_start, char_end);


--
-- Name: index_word_texts_on_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_word_texts_on_word_id ON quran.word_texts USING btree (word_id);


--
-- Name: index_word_translations_on_group_word_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_word_translations_on_group_word_id ON quran.word_translations USING btree (group_word_id);


--
-- Name: index_word_translations_on_priority; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_word_translations_on_priority ON quran.word_translations USING btree (priority);


--
-- Name: index_word_translations_on_word_id_and_language_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_word_translations_on_word_id_and_language_id ON quran.word_translations USING btree (word_id, language_id);


--
-- Name: index_words_on_chapter_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_words_on_chapter_id ON quran.words USING btree (chapter_id);


--
-- Name: index_words_on_char_type_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_words_on_char_type_id ON quran.words USING btree (char_type_id);


--
-- Name: index_words_on_lemma_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_words_on_lemma_id ON quran.words USING btree (lemma_id);


--
-- Name: index_words_on_location; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_words_on_location ON quran.words USING btree (location);


--
-- Name: index_words_on_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE UNIQUE INDEX index_words_on_number ON quran.words USING btree (number) WHERE (number IS NOT NULL);


--
-- Name: index_words_on_position; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_words_on_position ON quran.words USING btree ("position");


--
-- Name: index_words_on_root_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_words_on_root_id ON quran.words USING btree (root_id);


--
-- Name: index_words_on_sequence_number; Type: INDEX; Schema: quran; Owner: -
--

CREATE UNIQUE INDEX index_words_on_sequence_number ON quran.words USING btree (sequence_number);


--
-- Name: index_words_on_stem_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_words_on_stem_id ON quran.words USING btree (stem_id);


--
-- Name: index_words_on_token_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_words_on_token_id ON quran.words USING btree (token_id);


--
-- Name: index_words_on_topic_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_words_on_topic_id ON quran.words USING btree (topic_id);


--
-- Name: index_words_on_verse_id; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_words_on_verse_id ON quran.words USING btree (verse_id);


--
-- Name: index_words_on_verse_key; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_words_on_verse_key ON quran.words USING btree (verse_key);


--
-- Name: index_words_on_word_index; Type: INDEX; Schema: quran; Owner: -
--

CREATE INDEX index_words_on_word_index ON quran.words USING btree (word_index);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: quran; Owner: -
--

CREATE UNIQUE INDEX unique_schema_migrations ON quran.schema_migrations USING btree (version);


--
-- Name: text_lemma _RETURN; Type: RULE; Schema: quran; Owner: -
--

CREATE OR REPLACE VIEW quran.text_lemma AS
 SELECT concat_ws(':'::text, 'quran', 'lemma', 'ayah', a.ayah_key) AS id,
    a.ayah_key,
    a.surah_id,
    a.ayah_num,
    true AS is_hidden,
    string_agg((t.value)::text, ' '::text ORDER BY w."position", j."position") AS text
   FROM (((quran.word w
     JOIN quran.ayah a USING (ayah_key))
     JOIN quran.word_lemma j USING (word_id))
     JOIN quran.lemma t USING (lemma_id))
  GROUP BY a.ayah_key
  ORDER BY a.surah_id, a.ayah_num;


--
-- Name: text_root _RETURN; Type: RULE; Schema: quran; Owner: -
--

CREATE OR REPLACE VIEW quran.text_root AS
 SELECT concat_ws(':'::text, 'quran', 'root', 'ayah', a.ayah_key) AS id,
    a.ayah_key,
    a.surah_id,
    a.ayah_num,
    true AS is_hidden,
    string_agg((t.value)::text, ' '::text ORDER BY w."position", j."position") AS text
   FROM (((quran.word w
     JOIN quran.ayah a USING (ayah_key))
     JOIN quran.word_root j USING (word_id))
     JOIN quran.root t USING (root_id))
  GROUP BY a.ayah_key
  ORDER BY a.surah_id, a.ayah_num;


--
-- Name: text_stem _RETURN; Type: RULE; Schema: quran; Owner: -
--

CREATE OR REPLACE VIEW quran.text_stem AS
 SELECT concat_ws(':'::text, 'quran', 'stem', 'ayah', a.ayah_key) AS id,
    a.ayah_key,
    a.surah_id,
    a.ayah_num,
    true AS is_hidden,
    string_agg((t.value)::text, ' '::text ORDER BY w."position", j."position") AS text
   FROM (((quran.word w
     JOIN quran.ayah a USING (ayah_key))
     JOIN quran.word_stem j USING (word_id))
     JOIN quran.stem t USING (stem_id))
  GROUP BY a.ayah_key
  ORDER BY a.surah_id, a.ayah_num;


--
-- Name: text_token _RETURN; Type: RULE; Schema: quran; Owner: -
--

CREATE OR REPLACE VIEW quran.text_token AS
 SELECT concat_ws(':'::text, 'quran', 'token', 'ayah', a.ayah_key) AS id,
    a.ayah_key,
    a.surah_id,
    a.ayah_num,
    true AS is_hidden,
    string_agg((t.value)::text, ' '::text ORDER BY w."position") AS text
   FROM ((quran.word w
     JOIN quran.ayah a USING (ayah_key))
     JOIN quran.token t USING (token_id))
  GROUP BY a.ayah_key
  ORDER BY a.surah_id, a.ayah_num;


--
-- Name: file _file_ayah_key_fkey; Type: FK CONSTRAINT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.file
    ADD CONSTRAINT _file_ayah_key_fkey FOREIGN KEY (ayah_key) REFERENCES quran.ayah(ayah_key) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: file _file_recitation_id_fkey; Type: FK CONSTRAINT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.file
    ADD CONSTRAINT _file_recitation_id_fkey FOREIGN KEY (recitation_id) REFERENCES audio.recitation(recitation_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: recitation recitation_reciter_id_fkey; Type: FK CONSTRAINT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.recitation
    ADD CONSTRAINT recitation_reciter_id_fkey FOREIGN KEY (reciter_id) REFERENCES audio.reciter(reciter_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: recitation recitation_style_id_fkey; Type: FK CONSTRAINT; Schema: audio; Owner: -
--

ALTER TABLE ONLY audio.recitation
    ADD CONSTRAINT recitation_style_id_fkey FOREIGN KEY (style_id) REFERENCES audio.style(style_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: tafsir_ayah _tafsir_ayah_ayah_key_fkey; Type: FK CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.tafsir_ayah
    ADD CONSTRAINT _tafsir_ayah_ayah_key_fkey FOREIGN KEY (ayah_key) REFERENCES quran.ayah(ayah_key) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: tafsir_ayah _tafsir_ayah_tafsir_id_fkey; Type: FK CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.tafsir_ayah
    ADD CONSTRAINT _tafsir_ayah_tafsir_id_fkey FOREIGN KEY (tafsir_id) REFERENCES content.tafsir(tafsir_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: translation _translation_ayah_key_fkey; Type: FK CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.translation
    ADD CONSTRAINT _translation_ayah_key_fkey FOREIGN KEY (ayah_key) REFERENCES quran.ayah(ayah_key) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: transliteration _transliteration_ayah_key_fkey; Type: FK CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.transliteration
    ADD CONSTRAINT _transliteration_ayah_key_fkey FOREIGN KEY (ayah_key) REFERENCES quran.ayah(ayah_key) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: resource_api_version resource_api_version_resource_id_fkey; Type: FK CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.resource_api_version
    ADD CONSTRAINT resource_api_version_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES content.resource(resource_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: resource resource_author_id_fkey; Type: FK CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.resource
    ADD CONSTRAINT resource_author_id_fkey FOREIGN KEY (author_id) REFERENCES content.author(author_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: resource resource_language_code_fkey; Type: FK CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.resource
    ADD CONSTRAINT resource_language_code_fkey FOREIGN KEY (language_code) REFERENCES i18n.language(language_code) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: resource resource_source_id_fkey; Type: FK CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.resource
    ADD CONSTRAINT resource_source_id_fkey FOREIGN KEY (source_id) REFERENCES content.source(source_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: tafsir tafsir_resource_id_fkey; Type: FK CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.tafsir
    ADD CONSTRAINT tafsir_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES content.resource(resource_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: translation translation_resource_id_fkey; Type: FK CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.translation
    ADD CONSTRAINT translation_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES content.resource(resource_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: transliteration transliteration_resource_id_fkey; Type: FK CONSTRAINT; Schema: content; Owner: -
--

ALTER TABLE ONLY content.transliteration
    ADD CONSTRAINT transliteration_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES content.resource(resource_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ayah ayah_surah_id_fkey; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.ayah
    ADD CONSTRAINT ayah_surah_id_fkey FOREIGN KEY (surah_id) REFERENCES quran.surah(surah_id);


--
-- Name: char_type char_type_parent_id_fkey; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.char_type
    ADD CONSTRAINT char_type_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES quran.char_type(char_type_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: morphology_word_segments fk_rails_18c40a6302; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_word_segments
    ADD CONSTRAINT fk_rails_18c40a6302 FOREIGN KEY (word_id) REFERENCES quran.words(id);


--
-- Name: morphology_word_segments fk_rails_378c14d9b9; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_word_segments
    ADD CONSTRAINT fk_rails_378c14d9b9 FOREIGN KEY (root_id) REFERENCES quran.roots(id);


--
-- Name: morphology_word_segments fk_rails_3887db9336; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_word_segments
    ADD CONSTRAINT fk_rails_3887db9336 FOREIGN KEY (topic_id) REFERENCES quran.topics(id);


--
-- Name: morphology_words fk_rails_3b86d16307; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_words
    ADD CONSTRAINT fk_rails_3b86d16307 FOREIGN KEY (word_id) REFERENCES quran.words(id);


--
-- Name: morphology_dependency_graph_nodes fk_rails_49c7b2470d; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_dependency_graph_nodes
    ADD CONSTRAINT fk_rails_49c7b2470d FOREIGN KEY (graph_id) REFERENCES quran.morphology_dependency_graphs(id);


--
-- Name: morphology_derived_words fk_rails_5e24f5074a; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_derived_words
    ADD CONSTRAINT fk_rails_5e24f5074a FOREIGN KEY (verse_id) REFERENCES quran.verses(id);


--
-- Name: tajweed_words fk_rails_953c2f1752; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.tajweed_words
    ADD CONSTRAINT fk_rails_953c2f1752 FOREIGN KEY (word_id) REFERENCES quran.words(id);


--
-- Name: morphology_word_segments fk_rails_a3cf985389; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_word_segments
    ADD CONSTRAINT fk_rails_a3cf985389 FOREIGN KEY (lemma_id) REFERENCES quran.lemmas(id);


--
-- Name: morphology_derived_words fk_rails_caed5b1f66; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_derived_words
    ADD CONSTRAINT fk_rails_caed5b1f66 FOREIGN KEY (word_id) REFERENCES quran.words(id);


--
-- Name: morphology_word_verb_forms fk_rails_d0db36a532; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_word_verb_forms
    ADD CONSTRAINT fk_rails_d0db36a532 FOREIGN KEY (word_id) REFERENCES quran.words(id);


--
-- Name: tajweed_words fk_rails_deee5c0c72; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.tajweed_words
    ADD CONSTRAINT fk_rails_deee5c0c72 FOREIGN KEY (mushaf_id) REFERENCES quran.mushafs(id);


--
-- Name: morphology_word_grammar_concepts fk_rails_e6806c6821; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_word_grammar_concepts
    ADD CONSTRAINT fk_rails_e6806c6821 FOREIGN KEY (word_id) REFERENCES quran.words(id);


--
-- Name: tajweed_words fk_rails_e71c79c267; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.tajweed_words
    ADD CONSTRAINT fk_rails_e71c79c267 FOREIGN KEY (verse_id) REFERENCES quran.verses(id);


--
-- Name: morphology_words fk_rails_f421a8bac5; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.morphology_words
    ADD CONSTRAINT fk_rails_f421a8bac5 FOREIGN KEY (verse_id) REFERENCES quran.verses(id);


--
-- Name: text text_ayah_key_fkey; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.text
    ADD CONSTRAINT text_ayah_key_fkey FOREIGN KEY (ayah_key) REFERENCES quran.ayah(ayah_key) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: text text_resource_id_fkey; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.text
    ADD CONSTRAINT text_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES content.resource(resource_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: word_translation translation_language_code_fkey; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_translation
    ADD CONSTRAINT translation_language_code_fkey FOREIGN KEY (language_code) REFERENCES i18n.language(language_code) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: word_translation translation_word_id_fkey; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_translation
    ADD CONSTRAINT translation_word_id_fkey FOREIGN KEY (word_id) REFERENCES quran.word(word_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: word word_ayah_key_fkey; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word
    ADD CONSTRAINT word_ayah_key_fkey FOREIGN KEY (ayah_key) REFERENCES quran.ayah(ayah_key) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: word_font word_font_ayah_key_fkey; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_font
    ADD CONSTRAINT word_font_ayah_key_fkey FOREIGN KEY (ayah_key) REFERENCES quran.ayah(ayah_key) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: word_font word_font_char_type_id_fkey; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_font
    ADD CONSTRAINT word_font_char_type_id_fkey FOREIGN KEY (char_type_id) REFERENCES quran.char_type(char_type_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: word_font word_font_resource_id_fkey; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_font
    ADD CONSTRAINT word_font_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES content.resource(resource_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: word_font word_font_word_id_fkey; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_font
    ADD CONSTRAINT word_font_word_id_fkey FOREIGN KEY (word_id) REFERENCES quran.word(word_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: word_lemma word_lemma_lemma_id_fkey; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_lemma
    ADD CONSTRAINT word_lemma_lemma_id_fkey FOREIGN KEY (lemma_id) REFERENCES quran.lemma(lemma_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: word_lemma word_lemma_word_id_fkey; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_lemma
    ADD CONSTRAINT word_lemma_word_id_fkey FOREIGN KEY (word_id) REFERENCES quran.word(word_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: word_root word_root_root_id_fkey; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_root
    ADD CONSTRAINT word_root_root_id_fkey FOREIGN KEY (root_id) REFERENCES quran.root(root_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: word_root word_root_word_id_fkey; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_root
    ADD CONSTRAINT word_root_word_id_fkey FOREIGN KEY (word_id) REFERENCES quran.word(word_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: word_stem word_stem_stem_id_fkey; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_stem
    ADD CONSTRAINT word_stem_stem_id_fkey FOREIGN KEY (stem_id) REFERENCES quran.stem(stem_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: word_stem word_stem_word_id_fkey; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word_stem
    ADD CONSTRAINT word_stem_word_id_fkey FOREIGN KEY (word_id) REFERENCES quran.word(word_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: word word_token_id_fkey; Type: FK CONSTRAINT; Schema: quran; Owner: -
--

ALTER TABLE ONLY quran.word
    ADD CONSTRAINT word_token_id_fkey FOREIGN KEY (token_id) REFERENCES quran.token(token_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

