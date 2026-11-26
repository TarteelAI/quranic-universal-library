# AI Agents (MCP)

AI assistants such as Claude can use QUL resources directly through the [Model Context Protocol](https://modelcontextprotocol.io) (MCP). This helps with two things:

- **Building apps with Islamic content.** A coding agent can look up the real resource IDs, scripts, response shapes and audio sources while it writes your app, instead of guessing them or inventing placeholder text.
- **Answering questions.** The assistant quotes ayahs, translations and tafsir from QUL instead of recalling them from memory, and names the source.

> **Community-maintained.** [qul-mcp](https://github.com/kzroo/qul-mcp) is an open-source MCP server built by a QUL user, not by Tarteel. It reads the same endpoints the QUL website uses, which are still in design (see [API](api.md)), so its tools may change as the API does.

## What the Assistant Can Do

- Read any ayah or passage in 14 script variants (Uthmani, IndoPak, QPC Hafs, Digital Khatt, and more).
- Attach translations, or compare many translations of one ayah.
- Read tafsir. Long tafsir is returned in full, split into numbered parts, never truncated.
- Get word-by-word meanings and transliteration.
- Find translation, tafsir and recitation IDs by language or name.
- Get recitation audio links per surah or per ayah, and the timing of each ayah inside a surah recording.

It is read-only and needs no API key.

## Setup

Requires Node.js 20 or later.

```bash
git clone https://github.com/kzroo/qul-mcp.git
cd qul-mcp
npm install
```

### Claude Code

```bash
claude mcp add qul -- node /absolute/path/to/qul-mcp/dist/index.js
```

The repository also includes a skill (`skills/qul`) that tells Claude when to use these tools, to quote Quran text exactly as returned, and to attribute every translation and tafsir. Install it with:

```bash
cp -r skills/qul ~/.claude/skills/
```

### Other MCP Clients

Add the server to your client's MCP configuration:

```json
{
  "mcpServers": {
    "qul": {
      "command": "node",
      "args": ["/absolute/path/to/qul-mcp/dist/index.js"]
    }
  }
}
```

To point it at a local QUL instance (see [Project Setup](project-setup.md)), set `QUL_API_BASE_URL=http://localhost:3000/api/v1`.

## Building Apps

With the server connected, a coding agent can work out what your app needs from QUL as it builds:

- Pick resources by language and author, with real IDs, for example the Urdu translations or the tafsirs available in Indonesian.
- See the exact data each script, translation and word-by-word field returns, including right-to-left text and footnote markup, before writing code against it.
- Find recitations that have ayah timings, for audio players that highlight each ayah as it is recited.
- Fill screens and tests with real Quran text from QUL rather than placeholder text.

For production, decide where your app gets its data. Download the datasets your app needs from the [Resources](https://qul.tarteel.ai/resources) page and bundle or host them (see [Downloading & Using Data](downloading-data.md)), or call the API with caching, keeping in mind that it is still in design.

Example prompts:

- "Build a React Native ayah-of-the-day widget showing the Arabic in Uthmani script with the Saheeh International translation."
- "Add a word-by-word view to my Next.js Quran reader with English meanings and transliteration."
- "Build a recitation player for Surah Al-Mulk that highlights each ayah as Mishary Alafasy recites it."
- "Add a screen that shows the Tafsir Ibn Kathir entry for whichever ayah the user taps, with the full text."

## Example Questions

- "Show 2:255 in Uthmani script with the Saheeh International translation."
- "Compare three English translations of 112:1."
- "What does Ibn Kathir say about 24:35? Read the whole tafsir before summarizing."
- "Give me the word-by-word meaning of Al-Fatihah with transliteration."
- "Get Mishary Alafasy's audio for Surah Yasin and the start time of each ayah."

## Licensing

Translations, tafsirs and recitations each have their own license. Before an app stores, bundles or redistributes any of them, check that resource's license on the [Resources](https://qul.tarteel.ai/resources) page, just as you would for a download.

## Issues

Report problems with the MCP server on its [issue tracker](https://github.com/kzroo/qul-mcp/issues). Report problems with the data itself on the [QUL issue tracker](https://github.com/TarteelAI/quranic-universal-library/issues), as described in [Contributing](contributing.md).
