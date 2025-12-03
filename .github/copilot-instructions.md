# Quranic Universal Library (QUL) Development Instructions

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Prerequisites and Environment Setup
- **CRITICAL**: Ruby version 3.3.3 is required. Ruby 3.2.3 will cause Gemfile compatibility issues.
- **Node.js**: Version 20+ (current: v20.19.4 works)
- **PostgreSQL**: Version 14.3+ required (16.9 tested and working)
- **Redis**: Version 7.0.0+ required for caching and background jobs
- **RVM or rbenv**: Required for Ruby version management

### Initial Setup Commands
Execute these commands in order. NEVER CANCEL any of these operations:

1. **Install system dependencies (Ubuntu/Debian)**:
   ```bash
   sudo apt-get update
   sudo apt-get install -y postgresql postgresql-contrib libpq-dev redis-server curl build-essential
   ```

2. **Install RVM and Ruby 3.3.3** (NEVER CANCEL - takes 15-20 minutes):
   ```bash
   curl -sSL https://get.rvm.io | bash -s stable
   source ~/.rvm/scripts/rvm
   rvm install 3.3.3
   rvm use 3.3.3
   rvm gemset create qul
   rvm gemset use qul
   ```
   **TIMEOUT: Set 30+ minutes. Installation may take up to 20 minutes.**

3. **Install Ruby dependencies** (NEVER CANCEL - takes 5-10 minutes):
   ```bash
   gem install bundler
   bundle install
   ```
   **TIMEOUT: Set 15+ minutes for complex gem compilation.**

4. **Install Node.js dependencies** (NEVER CANCEL - takes 3-5 minutes):
   ```bash
   npm install
   ```
   **Note**: If Cypress or Puppeteer installation fails due to network restrictions, use:
   ```bash
   export CYPRESS_INSTALL_BINARY=0
   export PUPPETEER_SKIP_DOWNLOAD=true
   npm install
   ```
   **TIMEOUT: Set 10+ minutes for large dependency downloads.**

### Build Commands
Execute these for frontend asset compilation:

1. **Build JavaScript** (takes ~1 second, TESTED):
   ```bash
   npm run build
   ```
   **TIMEOUT: Set 2+ minutes.** May show esbuild warnings about direct eval usage - this is normal.

2. **Build CSS** (takes ~4 seconds, TESTED):
   ```bash
   npm run build:css
   ```
   **TIMEOUT: Set 5+ minutes.** Will show Sass deprecation warnings about Bootstrap - this is normal and expected.

### Database Setup
**CRITICAL**: QUL requires TWO separate PostgreSQL databases:

1. **`quran_community_tarteel`**: User accounts, permissions, community content
2. **`quran_dev`**: Quranic data (translations, tafsirs, audio, etc.)

**Setup commands:**
```bash
# Start PostgreSQL service
sudo service postgresql start

# Create PostgreSQL user (if needed)
sudo -u postgres createuser -s $(whoami)

# Create databases
rails db:create
rails db:migrate
```

**Database dumps**: Download the mini development dump from:
- SQL: https://static-cdn.tarteel.ai/qul/mini-dumps/mini_quran_dev.sql.zip
- Binary: https://static-cdn.tarteel.ai/qul/mini-dumps/mini_quran_dev.dump.zip

**Restore database:**
```bash
# Option 1: SQL dump
psql quran_dev < path/to/mini_quran_dev.sql

# Option 2: Binary dump
pg_restore --host localhost --port 5432 --no-owner --no-privileges --no-tablespaces --no-acl --dbname quran_dev -v path/to/mini_quran_dev.dump
```

### Development Server
**Start all services** (NEVER CANCEL - may take 2-3 minutes to fully start):
```bash
# Start Redis
sudo service redis-server start

# Start Rails with asset watching (recommended)
bin/dev
```

**Alternative: Start Rails server only:**
```bash
bundle exec rails server
```

**TIMEOUT: Set 10+ minutes for initial server startup.** Rails application startup includes:
- Loading gems and dependencies (~30 seconds)
- Initializing Active Admin and other components (~1 minute)  
- Database connection and schema loading (~30 seconds)

**Expected startup output:**
```
=> Booting Puma
=> Rails 7.0.8.4 application starting in development
=> Run `bin/rails server --help` for more startup options
* Listening on http://127.0.0.1:3000
```

**Access points:**
- Main application: http://localhost:3000
- Admin panel: http://localhost:3000/admin

### Testing and Validation

**Rails Console Test** (TESTED - takes ~8 seconds):
```bash
bundle exec rails console
# Should load successfully with Rails version info
```

**JavaScript linting** (ESLint config missing in project):
```bash
# Check for JavaScript files
find app/javascript -name "*.js" -o -name "*.vue"
# Note: No .eslintrc configuration file exists - linting may fail
```

**Ruby linting** (requires Ruby 3.3.3):
```bash
bundle exec rubocop --version
bundle exec rubocop
# Note: Will fail if Ruby version is not 3.3.3
```

**Cypress E2E tests** (in scripts/cypress-e2e directory):
```bash
cd scripts/cypress-e2e
npx cypress open  # GUI mode (may fail due to display/network restrictions)
npx cypress run   # Headless mode
```
**Note**: Cypress binary download often fails in restricted environments. Use `CYPRESS_INSTALL_BINARY=0` if needed.

### Validation Scenarios
After making changes, ALWAYS test these scenarios:

1. **Basic application startup**:
   - Run `bin/dev` and verify server starts without errors
   - Access http://localhost:3000 and verify page loads
   - Check logs for critical errors

2. **Admin panel access**:
   - Navigate to http://localhost:3000/admin
   - Verify admin interface loads (may show empty data without database dump)

3. **Asset compilation**:
   - Run `npm run build` and verify no JavaScript errors
   - Run `npm run build:css` and verify CSS compiles successfully

4. **Database connectivity**:
   - Run `bundle exec rails console`
   - Execute basic ActiveRecord queries to verify database connection

## Critical File Locations

### Configuration Files
- **Ruby version**: `.ruby-version` (3.3.3)
- **Node version**: `.node-version` (20)
- **Database config**: `config/database.yml`
- **Routes**: `config/routes.rb`
- **Environment variables**: `.env.sample` (copy to `.env`)

### Frontend Assets
- **JavaScript entry points**: `app/javascript/application.js`, `app/javascript/active_admin.js`
- **Vue.js components**: `app/javascript/svg/` directory
- **CSS/SCSS**: `app/assets/stylesheets/`
- **Build config**: `esbuild.config.js`

### Backend Code
- **Controllers**: `app/controllers/`
- **Models**: `app/models/`
- **Admin interface**: `app/admin/`
- **Views**: `app/views/`
- **Migrations**: `db/migrate/`

### Build Artifacts (DO NOT COMMIT)
- `app/assets/builds/` - Generated CSS files
- `node_modules/` - Node.js dependencies
- `tmp/` - Temporary files
- `log/` - Log files

## Common Issues and Solutions

### Ruby Version Mismatch
If you see "Your Ruby version is 3.x.x, but your Gemfile specified 3.3.3":
- Install Ruby 3.3.3 using RVM or rbenv
- Verify with `ruby --version`

### Database Connection Errors
If Rails cannot connect to PostgreSQL:
- Ensure PostgreSQL service is running: `pg_isready`
- Create database user: `sudo -u postgres createuser -s $(whoami)`

### Asset Compilation Issues
If CSS/JS builds fail:
- Check Node.js version: `node --version` (should be 20+)
- Clear cache: `rm -rf app/assets/builds/* node_modules/.cache`
- Rebuild: `npm run build && npm run build:css`

### Migration Failures
Migrations may fail without the `quran_dev` database properly set up:
- Ensure both databases exist
- Load the development database dump before running migrations

## Development Workflow
1. **Pull latest changes**: `git pull`
2. **Update dependencies**: `bundle install && npm install`
3. **Run migrations**: `rails db:migrate` (may fail without `quran_dev` database dump)
4. **Build assets**: `npm run build && npm run build:css`
5. **Start development server**: `bin/dev`
6. **Make changes and test**
7. **Validate before committing**: Test application startup and key functionality

Always validate that your changes don't break the basic application startup and core functionality before pushing changes.

## Validated Commands Summary
Based on actual testing, these commands work as expected:

**WORKING COMMANDS** (tested and confirmed):
- `npm install` (with environment variables to skip binary downloads)  
- `npm run build` (1 second, shows esbuild warnings - normal)
- `npm run build:css` (4 seconds, shows Sass deprecation warnings - normal)
- `bundle exec rails console` (8 seconds to load)
- `bundle exec rails server` (starts successfully, may show 500 errors without database dumps)
- Database services: PostgreSQL and Redis start and respond correctly

**KNOWN LIMITATIONS**:
- ESLint configuration is missing - `npm run lint` will fail
- RuboCop requires exact Ruby 3.3.3 version  
- Cypress/Puppeteer binary downloads fail in restricted networks
- Database migrations fail without the `quran_dev` database dump loaded
- Some features require both databases to be properly configured

**TIMING EXPECTATIONS**:
- npm install: ~7 seconds (with binary skips)
- Asset builds: ~5 seconds total
- Rails console load: ~8 seconds
- Rails server startup: ~10 seconds to listening state