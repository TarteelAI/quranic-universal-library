import { ArrowUpRightIcon } from 'lucide-react'
import { Fragment } from 'react'

import { Container, SiteShell } from '@/components/layout'
import { PageHeader } from '@/components/qul/page-header'
import { Button } from '@/components/ui/button'
import type { ContentCreditsEntity, ContentPagesCredits } from '@/types/serializers'

const REPO_URL = 'https://github.com/TarteelAI/quranic-universal-library'
const ISSUES_URL = `${REPO_URL}/issues/new/choose`

function Entity({ entity }: { entity: ContentCreditsEntity }) {
  if (!entity.url) return <strong className="font-medium text-foreground">{entity.name}</strong>
  return (
    <a href={entity.url} className="font-medium text-foreground underline underline-offset-4">
      {entity.name}
    </a>
  )
}

// "A", "A and B", "A, B and C"
function Entities({ entities }: { entities: ContentCreditsEntity[] }) {
  return entities.map((entity, index) => (
    <Fragment key={entity.name}>
      {index > 0 && (index === entities.length - 1 ? ' and ' : ', ')}
      <Entity entity={entity} />
    </Fragment>
  ))
}

// /credits: the organizations (Contributor.published), the people and projects thanked by name
// and the code contributors of the GitHub repository. Descriptions of organizations are editor
// HTML the server reduced to prose.
export default function CreditsPage({ organizations, acknowledgements, codeContributors }: ContentPagesCredits) {
  return (
    <SiteShell>
      <Container className="pt-12 pb-16">
        <PageHeader
          title="Credits"
          description="Most QUL resources were made or collected by the community, not by Tarteel. We thank every project and person whose work is in QUL. Please remember them in your prayers."
          actions={
            <Button variant="outline" asChild>
              <a href={ISSUES_URL}>Contribute</a>
            </Button>
          }
        />

        {organizations.length > 0 && (
          <section className="mt-12" aria-labelledby="credits-organizations">
            <h2 id="credits-organizations" className="headline text-2xl">
              Organizations
            </h2>
            <ul className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {organizations.map((organization) => (
                <li key={organization.name} className="flex flex-col gap-3 rounded-xl border bg-card p-5">
                  <div className="flex items-center gap-3">
                    {organization.logoUrl && (
                      <img
                        src={organization.logoUrl}
                        alt=""
                        className="size-12 shrink-0 rounded-full border bg-white object-contain"
                      />
                    )}
                    <h3 className="font-medium tracking-tight">
                      {organization.url ? (
                        <a href={organization.url} className="hover:underline">
                          {organization.name}
                        </a>
                      ) : (
                        organization.name
                      )}
                    </h3>
                  </div>
                  <div
                    className="flex flex-col gap-2 text-sm text-muted-foreground [&_a]:underline"
                    dangerouslySetInnerHTML={{ __html: organization.description }}
                  />
                </li>
              ))}
            </ul>
          </section>
        )}

        <section className="mt-12" aria-labelledby="credits-people">
          <h2 id="credits-people" className="headline text-2xl">
            People and projects
          </h2>
          <p className="mt-2 max-w-2xl text-sm text-muted-foreground">
            As far as we know them, and respecting those who asked for privacy, we thank:
          </p>
          <ul className="mt-6 grid gap-x-8 gap-y-4 md:grid-cols-2">
            {acknowledgements.map((item) => (
              <li key={item.entities.map((entity) => entity.name).join()} className="text-muted-foreground">
                <Entities entities={item.entities} /> {item.description}
              </li>
            ))}
          </ul>
        </section>

        {codeContributors.length > 0 && (
          <section className="mt-12" aria-labelledby="credits-code">
            <h2 id="credits-code" className="headline text-2xl">
              Code contributors
            </h2>
            <p className="mt-2 text-sm text-muted-foreground">The people who sent code to the QUL repository.</p>
            <ul className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
              {codeContributors.map((contributor) => (
                <li key={contributor.login}>
                  <a
                    href={contributor.url}
                    className="flex items-center gap-3 rounded-xl border bg-card p-3 hover:bg-accent"
                  >
                    <img src={contributor.avatarUrl} alt="" className="size-10 shrink-0 rounded-full" />
                    <span className="min-w-0">
                      <span className="block truncate text-sm font-medium">{contributor.login}</span>
                      <span className="block text-xs text-muted-foreground">
                        {contributor.contributions} {contributor.contributions === 1 ? 'contribution' : 'contributions'}
                      </span>
                    </span>
                  </a>
                </li>
              ))}
            </ul>
            <a
              href={`${REPO_URL}/graphs/contributors`}
              className="mt-4 inline-flex items-center gap-1 text-sm text-muted-foreground underline underline-offset-4 hover:text-foreground"
            >
              All contributors on GitHub <ArrowUpRightIcon aria-hidden className="size-3.5" />
            </a>
          </section>
        )}
      </Container>
    </SiteShell>
  )
}
