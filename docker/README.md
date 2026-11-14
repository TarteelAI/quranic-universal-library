# QUL docker deployment

build the image:
```
docker build -t quranic-universal-library .
```
run it:

```
docker run --rm -it -p 3000:3000 --env RAILS_MASTER_KEY=<content of config/master.key> quranic-universal-library
```

## Services in the image

runit services under `/sbin/my_init`: nginx with Passenger (the Rails app), redis, memcached,
Sidekiq (`docker/sidekiq.run`) and the Inertia SSR server (`docker/inertia-ssr.run`).

The SSR server is Node (`node public/vite-ssr/ssr.mjs`, built by `assets:precompile`) on
`127.0.0.1:13714` (loopback only), running as the `app` user. Its log is `log/inertia-ssr.log`. Rails asks it to
render each Inertia page (`config/initializers/inertia_rails.rb`). When it is down or takes more
than 2 seconds, the page renders in the browser and Rails logs
`[inertia-rails] SSR render failed`. Restarting it does not need a Passenger restart:

```
sv status inertia-ssr
sv restart inertia-ssr      # also: sv stop / sv start
```

nginx serves `/assets/` (Sprockets) and `/vite/` (Vite) with a one-year expiry and gzip, and
does not serve `/vite-ssr/`.

## Build notes

- `assets:precompile` builds the old pipeline (esbuild, Sass, Tailwind 3, Sprockets) and then
  Vite: the client build into `public/vite` and the SSR build into `public/vite-ssr`.
- JavaScript dependencies install once, in `yarn install --frozen-lockfile`. Each precompile
  also runs `yarn install` twice (jsbundling and cssbundling); both report "Already
  up-to-date". vite_ruby's own install is off (`Rakefile`).
- The second `assets:precompile` writes no files (checked in sprint 001, story 001-03): one run
  from a clean tree gives the same asset files. It stays until someone removes it on purpose.
- The image has Node 24 from NodeSource; the SSR service uses that Node.

## Running the image locally

Run it against clones of the snapshot databases only (`bin/snapshot-clones development`, see
`AGENTS.md`), never the snapshot itself or production. Never start Sidekiq or set SMTP
variables: mount an empty `down` file into the Sidekiq service so runit does not start it.

The image does not need the master key. `config/secrets.yml` reads `SECRET_KEY_BASE` in
production, and the database settings come from environment variables.

Build for `linux/amd64`, as production does. `Gemfile.lock` lists `x86_64-linux` but not
`aarch64-linux`, so an arm64 build installs `tailwindcss-rails` without its binary and
`assets:precompile` fails. Do not add a platform to the lockfile.

```
docker build --platform linux/amd64 -t qul:local .

mkdir -p ~/qul-image && touch ~/qul-image/sidekiq-down
cat > ~/qul-image/image.env <<'ENV'
SECRET_KEY_BASE=<any long random hex string, e.g. from `openssl rand -hex 64`>
QUL_CMS_CONTENT_DB_NAME=qul_cms_content_dev
QUL_CMS_CONTENT_DB_HOST=host.docker.internal
QUL_CMS_CONTENT_DB_PORT=<port>
QUL_CMS_CONTENT_DB_USERNAME=<user>
QUL_CMS_CONTENT_DB_PASSWORD=<password>
QUL_CMS_CONTENT_DB_SSLMODE=disable
QUL_QURAN_CONTENT_DB_NAME=qul_quran_content_dev
QUL_QURAN_CONTENT_DB_HOST=host.docker.internal
QUL_QURAN_CONTENT_DB_PORT=<port>
QUL_QURAN_CONTENT_DB_USERNAME=<user>
QUL_QURAN_CONTENT_DB_PASSWORD=<password>
QUL_QURAN_CONTENT_DB_SSLMODE=disable
CDN_HOST=https://static-cdn.tarteel.ai
QUL_INERTIA_SAMPLE_PAGE=true
ENV

docker run -d --platform linux/amd64 --name qul-image -p 3000:3000 --env-file ~/qul-image/image.env \
  -v ~/qul-image/sidekiq-down:/etc/service/sidekiq/down:ro qul:local

docker exec qul-image sv status sidekiq inertia-ssr nginx   # sidekiq: down
curl -s http://localhost:3000/__dev/inertia_sample          # server-rendered HTML
docker rm -f qul-image
```

`QUL_INERTIA_SAMPLE_PAGE=true` adds the Inertia sample page (`/__dev/inertia_sample`), which
production does not have otherwise. Use `localhost`, not `127.0.0.1`
(`config/initializers/hosts.rb`). Keep the env file outside the checkout: the build context
includes most of the working tree.
