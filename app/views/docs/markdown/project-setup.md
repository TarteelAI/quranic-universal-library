# Project Setup

Get the QUL application running locally so you can develop and test code changes.

> This page is a starting point. If you hit a gap, please improve it via a pull request — see [Contribution Workflow](contributing.md).

## Requirements

- Ruby `3.3.3` (see `.ruby-version`)
- PostgreSQL
- Redis (used by Sidekiq for background jobs)
- Node.js and Yarn (for asset compilation)

## Clone and Install

```bash
git clone https://github.com/TarteelAI/quranic-universal-library.git
cd quranic-universal-library
bin/setup
```

`bin/setup` installs Ruby and JavaScript dependencies, prepares the database, and runs initial setup steps.

## Run the App

```bash
bin/dev
```

This boots the Rails server together with the asset watchers. The app is then available at [http://localhost:3000](http://localhost:3000), and the admin interface is built with Active Admin.

## Next Steps

- Read the [Contribution Workflow](contributing.md) before opening a pull request.
- Review the [Best Practices](best-practices.md) for keeping changes focused.
