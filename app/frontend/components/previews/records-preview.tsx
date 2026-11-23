import type { PreviewsRecord, PreviewsRecords } from '@/types/serializers'

import { PreviewToolbar, StepButtons, SurahSelect, type PreviewNavigation } from './navigation'

function Record({ record, preview }: { record: PreviewsRecord; preview: PreviewsRecords }) {
  const { locale } = preview
  return (
    <li className="flex flex-col gap-2 rounded-xl border bg-card p-4" data-record={record.key}>
      <span className="text-sm font-medium">{record.label}</span>
      {record.arabic && (
        <p dir="rtl" lang="ar" className="font-arabic text-2xl leading-loose">
          {record.arabic}
        </p>
      )}
      {record.text && (
        <p lang={locale.code} dir={locale.direction} className="text-sm">
          {record.text}
        </p>
      )}
      {record.html && (
        // Sanitized on the server (Previews.sanitize).
        <div
          lang={locale.code}
          dir={locale.direction}
          className="preview-html text-sm leading-relaxed"
          dangerouslySetInnerHTML={{ __html: record.html }}
        />
      )}
      {record.truncated && (
        <p className="text-sm text-muted-foreground">
          This record is long, so the preview shows its start. Download the resource to read all of it.
        </p>
      )}
      {record.tags.length > 0 && (
        <ul className="flex flex-wrap gap-1.5">
          {record.tags.map((tag) => (
            <li key={tag} dir="auto" className="rounded-full bg-muted px-2.5 py-0.5 text-xs">
              {tag}
            </li>
          ))}
        </ul>
      )}
    </li>
  )
}

// A resource shown as a sample of its records: the first few of the download, or of the chosen
// surah for the resources that go surah by surah.
export function RecordsPreview({ preview, navigation }: { preview: PreviewsRecords; navigation: PreviewNavigation }) {
  const { surah, records } = preview
  const { navigate } = navigation
  return (
    <div className="flex flex-col gap-4" data-testid="records-preview" data-surah={surah?.number ?? ''}>
      {surah && (
        <PreviewToolbar loading={navigation.loading}>
          <SurahSelect
            surah={surah.number}
            surahs={preview.surahs}
            onSelect={(number) => navigate({ surah: number })}
          />
          <StepButtons
            label="surah"
            previous={surah.number > 1 ? () => navigate({ surah: surah.number - 1 }) : null}
            next={surah.number < preview.surahs.length ? () => navigate({ surah: surah.number + 1 }) : null}
          />
        </PreviewToolbar>
      )}
      <p className="text-sm text-muted-foreground">
        {records.length === 0
          ? `No records${surah ? ` for Surah ${surah.name}` : ''} in this resource.`
          : `A sample of ${records.length === 1 ? 'one record' : `the first ${records.length} records`}${surah ? ` for Surah ${surah.name}` : ''}, at most ${preview.limit}. Download the resource for all of them.`}
      </p>
      <ol className="flex flex-col gap-3" aria-busy={navigation.loading}>
        {records.map((record) => (
          <Record key={record.key} record={record} preview={preview} />
        ))}
      </ol>
    </div>
  )
}
