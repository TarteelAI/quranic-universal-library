import { useId } from 'react'

import { cn } from '@/lib/utils'
import type { CatalogFormatSchema } from '@/types/serializers'

// One table or file of a download as its format doc describes it (Catalog::FormatDoc), from the
// v7 SchemaTable (ds/src/components/qul/data.tsx): its columns or fields, with the type column
// only when the doc names types.
export function SchemaTable({ schema, className }: { schema: CatalogFormatSchema; className?: string }) {
  const typed = schema.columns.some((column) => column.type)
  const captionId = useId()

  return (
    <figure
      aria-labelledby={schema.name ? captionId : undefined}
      className={cn('overflow-hidden rounded-xl bg-card shadow-xs', className)}
    >
      {schema.name && (
        <figcaption id={captionId} className="border-b bg-surface px-5 py-3 text-sm font-medium">
          {schema.name}
        </figcaption>
      )}
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b text-left text-xs text-muted-foreground">
              <th className="px-5 py-2 font-normal">Column</th>
              {typed && <th className="px-5 py-2 font-normal">Type</th>}
              <th className="px-5 py-2 font-normal">Description</th>
            </tr>
          </thead>
          <tbody>
            {schema.columns.map((column, index) => (
              <tr key={index} className="border-b last:border-0">
                <td className="px-5 py-2.5 align-top font-mono text-[13px] font-medium">{column.name}</td>
                {typed && (
                  <td className="px-5 py-2.5 align-top font-mono text-[12px] whitespace-nowrap text-muted-foreground">
                    {column.type}
                  </td>
                )}
                <td className="px-5 py-2.5 align-top text-muted-foreground">{column.description}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </figure>
  )
}
