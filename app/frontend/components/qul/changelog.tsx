import type { ContentChangelogResourceLink } from '@/types/serializers'

// The entry's resource: a plain link to its detail page (another page group), or its name alone
// while the resource is not published.
export function ChangelogResource({ resource }: { resource: ContentChangelogResourceLink }) {
  return resource.path ? (
    <a href={resource.path} className="font-medium text-foreground underline underline-offset-4 hover:text-primary">
      {resource.name}
    </a>
  ) : (
    <span className="font-medium text-foreground">{resource.name}</span>
  )
}
