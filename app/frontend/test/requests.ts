import type { RequestsListItem, RequestsRequestsIndex } from '@/types/serializers'

function request(id: number, fields: Partial<RequestsListItem> = {}): RequestsListItem {
  return {
    id,
    title: `Request ${id}`,
    description: 'For a study app.',
    type: 'Tafsir',
    language: null,
    status: 'open',
    statusLabel: 'Open',
    votes: 0,
    voted: false,
    date: '13 November 2026',
    ...fields,
  }
}

// Shaped like Requests::RequestsIndexResource: page 2 of 3, by votes.
export const requestsPageProps: RequestsRequestsIndex = {
  sort: 'votes',
  page: 2,
  pages: 3,
  total: 45,
  requests: [
    request(7, { title: 'Tafsir Ahsanul Bayan', language: 'Bengali', votes: 12, voted: true }),
    request(3, {
      title: 'Hausa translation',
      type: 'Translation',
      status: 'planned',
      statusLabel: 'Planned',
      votes: 1,
    }),
  ],
}
