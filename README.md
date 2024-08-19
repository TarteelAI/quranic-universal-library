# Quranic Universal Library(QUL) - https://qul.tarteel.ai/

Welcome to the Tarteel QUL! This project is a comprehensive Content Management System designed to manage Quranic data, including translations, tafsirs, Audio, Audio segments, Arabic scripts, Mushaf layouts, and much more.

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

#### 5. Setup Database
*QUL needs two databases:*
- `quran_dev`: Database for storing Quranic data
- `quran_community_tarteel`: This database store the users info, permissions and all user generated data.

#### 6. Create Databases
Create database for managing user content.
```bash
rails db:create
rails db:migrate
rails db:seed
```
For Quran related data, you'll need to create the database manually then import this [dump file](https://quran-assets.tarteel.ai/cms/quran_data.sql.zip).

### 7. Run the pending migrations
```ruby
rails db:migrate
```

#### 8. Run the Application
```bash
bin/dev
```

You can now visit http://localhost:3000 in your browser to see the application.
Visit http://localhost:3000/admin to access the admin panel.

#### Contributing

We welcome contributions from the community! If you'd like to contribute to this project, please follow these steps:

1. Fork the repository and clone it.
2. Create a new branch (git checkout -b feature-branch).
3. Make your changes.
4. Commit your changes (git commit -m 'Add some feature').
5. Push to the branch (git push origin feature-branch).
6. Open a pull request.
