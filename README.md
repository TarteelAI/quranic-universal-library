<p align="center">
  <a href="https://qul.tarteel.ai">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://repository-images.githubusercontent.com/813405111/c7e7447e-a3c4-4b15-9646-65b07b817817">
      <img src="https://repository-images.githubusercontent.com/813405111/c7e7447e-a3c4-4b15-9646-65b07b817817">
    </picture>
    <h1 align="center">Quranic Universal Library (QUL)</h1>
  </a>
</p>

<p align="center">
  <a aria-label="Tarteel logo" href="https://tarteel.ai">
    <picture>
      <source height="24" media="(prefers-color-scheme: dark)" srcset="https://tarteel.ai/logo.svg">
      <img height="24" src="https://tarteel.ai/logo.svg">
    </picture>
  </a>
  <a aria-label="A project by Tarteel Shield" href="https://tarteel.ai"><img src='https://img.shields.io/badge/A%20PROJECT%20BY%20Tarteel-000000.svg?style=for-the-badge'></a>
  <a aria-label="Follow on X formerly Twitter" href="https://x.com/intent/follow?screen_name=tarteelai"><img alt="X (formerly Twitter) Follow" src="https://img.shields.io/twitter/follow/tarteelai?style=for-the-badge&logo=x"></a>
  <a aria-label="Join the community on Discord" href="https://t.zip/discord?utm_source=github&utm_medium=readme&utm_campaign=qul"><img alt="Discord" src="https://img.shields.io/discord/934719200222642186?style=for-the-badge&logo=discord&label=Join%20our%20discord"></a>
</p>

Welcome to the Tarteel's QUL! This project is a comprehensive Content Management System designed to manage Quranic data, including translations, tafsirs, Audio, Audio segments, Arabic scripts, Mushaf layouts, and much more.

QUL is implemented using Ruby on Rails, and Active Admin for implementing the admin interface.

## Features
- Translations and Tafsirs Management: Easily add, proofread, fix issues, and export different formats.
- Audio Management: Easily add both ayah by ayah and gapless aduio, manage audio segments, and export segments data.
- Arabic Scripts: Preview different Arabic scripts, both ayah by ayah and word by word.
- Mushaf Layouts: Manage different Mushaf layouts, preview them, and export them.
- User Management: Manage users, their roles, and permissions.
- Mutashabihat ul Quran: Manage Mutashabihat ul Quran data.
- Surah info: Manage Surah info data in multiple languages.
- Content Versioning: Keep track of all changes made to the content.
- Export Data: Export data in different formats.
- Import Data: Import data from different sources.
- Quranic grammar and morphology: Manage Quranic grammar and morphology data.

## Setup Guide
This guide will help you set up the QUL project on your local machine. Follow the steps below to get started.

### Prerequisites
- **Ruby**: Version 3.3.3
- **Rails**: Version 7.0.3
- **RVM or rbenv**: For managing Ruby versions
- **PostgreSQL**:  14.3 or higher
- **Redis**: 7.0.0 or higher

#### 1. Clone the repository
```bash
git clone git@github.com:TarteelAI/quranic-universal-library.git
cd quranic-universal-library
```

#### 2. Install Ruby and setup environment
```bash
rvm install 3.3.3
rvm use 3.3.3
rvm gemset create qul
rvm gemset use qul
```

#### 3. Install PostgreSQL
- **Ubuntu/Debian**
```bash
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib libpq-dev
```
- **MacOS**
```bash
brew install postgresql
```
- **Windows**
Download and install the latest version of PostgreSQL from the [official website](https://www.postgresql.org/download/windows/).

#### 4. Install Dependencies
```bash
gem install bundler
bundle install
```

#### 5. Database Configuration

**The QUL project requires two databases:**

1. **`quran_dev`**: This database holds all Quranic data, including translations, tafsirs, audio etc. It's accessed through `quran_api_db_dev` for the development environment.
2. **`quran_community_tarteel`**: This database manages user accounts, permissions, and user changes.

#### 6. Create Databases
Create the **`quran_community_tarteel`** database for managing user content.
```bash
rails db:create
```

For **`quran_dev`** you can create it manually or change the database name to `quran_dev` for `development` group in database.yml file and run `rails db:create` again.

#### 7. Load the data for **`quran_dev`** database
The `quran_dev` database dump is available in both SQL and binary formats. Follow the appropriate instructions below to restore the database.

#### Restoring from SQL Dump
7.1 **Restore using SQL Dump:**
Download the [SQL dump file](https://quran-assets.tarteel.ai/cms/qul-mini-dump/quran_dev.sql.zip) and restore it using
```bash
  psql quran_dev < "path to sql dump file"
```

7.2 **Restore using binary dump:**
Download the [Binary dump file](https://quran-assets.tarteel.ai/cms/qul-mini-dump/quran_dev.dump.zip) and restore it using
```bash
pg_restore --host localhost --port 5432 --no-owner --no-privileges --no-tablespaces --no-acl --dbname quran_dev -v "path to binary dump file"
```

### 8. Run the migrations for **`quran_community_tarteel`** database
```ruby
rails db:migrate
rails db:migrate
rails db:seed
```

#### 9. Run the Application
```bash
bin/dev
```

🌟Insha`Allah! Your application should be up and running at time point! 🌟

You can now visit [http://localhost:3000](http://localhost:3000) in your browser to explore the app.

🔐 Head over to the admin panel at [http://localhost:3000/admin](http://localhost:3000/admin)

### 10. Contributing to QUL
We welcome contributions to enhance the QUL project! If you'd like to contribute, please follow these steps:

10.1 **Fork the Repository:**
Click on the "Fork" button at the top right of this page to create your own copy of the repository.

10.2 **Clone Your Fork:**
```bash
   git clone https://github.com/your_username/qul.git
```

10.3. **Create a new feature branch:**
  ```bash
     git checkout -b making-qul
  ```
10.4 **Make Your Changes:**

10.5 **Push Your Changes:**
```bash
git add .
git commit -m "Add a brief description of your changes"
git push origin your-feature-branch
```
10.6 **Create a Pull Request:**

May Allah reward your efforts and make them beneficial for the community! 🤲