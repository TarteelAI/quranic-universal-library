# AI Agents (MCP)

AI assistants such as Claude can look up QUL resources directly through the [Model Context Protocol](https://modelcontextprotocol.io) (MCP). The assistant then quotes ayahs, translations and tafsir from QUL instead of recalling them from memory, and names the source.

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

## Example Prompts

- "Show 2:255 in Uthmani script with the Saheeh International translation."
- "Compare three English translations of 112:1."
- "What does Ibn Kathir say about 24:35? Read the whole tafsir before summarizing."
- "Give me the word-by-word meaning of Al-Fatihah with transliteration."
- "Get Mishary Alafasy's audio for Surah Yasin and the start time of each ayah."

## Licensing

The assistant fetches data through the API rather than bundling datasets. If you build something that stores or redistributes what it fetches, check each resource's license on the [Resources](https://qul.tarteel.ai/resources) page first, as you would for a download.

## Issues

Report problems with the MCP server on its [issue tracker](https://github.com/kzroo/qul-mcp/issues). Report problems with the data itself on the [QUL issue tracker](https://github.com/TarteelAI/quranic-universal-library/issues), as described in [Contributing](contributing.md).
