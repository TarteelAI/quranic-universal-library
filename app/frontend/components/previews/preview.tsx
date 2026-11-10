import type { CatalogResourcesShow } from '@/types/serializers'

import { FontPreview } from './font-preview'
import { MushafPageView } from './mushaf-page'
import type { PreviewNavigation } from './navigation'
import { ScriptPreview } from './script-preview'

function NoPreview({ title, reason }: { title: string; reason: string }) {
  return (
    <div
      className="flex min-h-48 flex-col items-center justify-center gap-1 rounded-xl border border-dashed p-8 text-center"
      data-testid="no-preview"
    >
      <p className="font-medium">{title}</p>
      <p className="text-sm text-muted-foreground">{reason}</p>
    </div>
  )
}

// The Preview tab's content for whatever kind of preview the server sent (Previews.for).
export function Preview({
  preview,
  navigation,
}: {
  preview: CatalogResourcesShow['preview']
  navigation: PreviewNavigation
}) {
  switch (preview?.kind) {
    case 'layout':
      return <MushafPageView page={preview.page} navigation={navigation} />
    case 'font':
      return <FontPreview preview={preview} navigation={navigation} />
    case 'script':
      return <ScriptPreview preview={preview} navigation={navigation} />
    case 'unavailable':
      return <NoPreview title="No preview for this resource" reason={preview.reason} />
    default:
      return (
        <NoPreview
          title="No preview for this resource yet"
          reason="Download a file, or read the Data tab to see what it holds."
        />
      )
  }
}
