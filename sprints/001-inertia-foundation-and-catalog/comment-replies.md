# Replies to the v7 design comments (drafts, not posted)

Drafts for the seven design review comments on prototype v7 (team drop). A person reads and
approves each one before it is posted. The URLs show the change once the PR is deployed with
`QUL_PAGE_GROUPS=home,catalog,apps`; locally they work on `http://localhost:3000` with the same
setting.

## #11 — a way to submit an app

Done. The apps directory and the home page have a "Submit your app" button. It opens a GitHub
issue form (`app_submission.yml`) that asks for the app's name, link, platforms and the QUL
resources it uses. Accepted apps are added to `config/apps.yml`, so each submission has a public review trail.

See it: https://qul.tarteel.ai/apps

## #20 — select several script families at once

Done. The script family filter on the catalog takes several values at once (for example Madani
and IndoPak). Each value has its own count, and the selection is kept in the URL, so the view
can be shared.

See it: https://qul.tarteel.ai/resources?script[]=madani&script[]=indopak

## #21 — search as an icon in the header

Done. The header search field is now an icon. It opens the spotlight, which searches resources
from every new page. ⌘K (Mac) or Ctrl K opens it too.

See it: the header on https://qul.tarteel.ai/resources

## #22 — theme toggle in the footer

Done. The light and dark toggle is in the footer. The theme follows the system setting until a
choice is made, remembers the choice, and does not flash on load.

See it: the footer on https://qul.tarteel.ai/resources

## #23 — a short hero on phones

Done. On phones the hero text sits over the graphic, as on the current site, so the hero stays
short.

See it: https://qul.tarteel.ai/ at phone width

## #24 — logo as the icon only

Done. The header logo is the QUL icon only.

See it: the header on https://qul.tarteel.ai/resources

## #25 — contributor tools in the header menu

Done. The contributor tools list is back in the header's Contribute menu.

See it: the Contribute menu on https://qul.tarteel.ai/resources
