## Deploying to InfinityFree (shared hosting)

InfinityFree is a basic shared host. Use file sessions/cache and sync queues. No SSH or Composer at runtime, so upload a prebuilt ZIP.

### Option A: Use GitHub Actions (recommended)
1. In GitHub, run workflow "Build shared-hosting ZIP" (Actions tab).
2. Download artifact `krayin-shared.zip` after it finishes.
3. Extract `krayin-shared.zip` locally.
4. Upload files to your hosting `htdocs/` directory via FTP.

### Option B: Build locally
```bash
composer install --no-dev --optimize-autoloader --ignore-platform-req=ext-calendar
npm ci || npm install
npm run build
cp .env.example .env && php artisan key:generate --force
php artisan config:cache route:cache view:cache
zip -r krayin-shared.zip app bootstrap config database public resources routes vendor artisan \
  composer.json composer.lock vite.config.js storage/lang storage/framework .env packages
```

### InfinityFree setup
- Create a MySQL database in Control Panel. Note host, db name, user, password.
- In uploaded files, edit `.env` with your database credentials.
- Ensure `APP_ENV=production`, `APP_DEBUG=false`.
- Set `CACHE_DRIVER=file`, `SESSION_DRIVER=file`, `QUEUE_CONNECTION=sync`.

### Pointing the document root
InfinityFree's `htdocs` is the public root. Move these files into `htdocs`:
- Contents of our `public/` folder

And place the rest of the Laravel app one level up is not possible on InfinityFree free plan. Instead, keep everything in `htdocs` and update `.htaccess` to route correctly. If you cannot place app outside webroot, keep as-is and rely on `.htaccess` protections.

### Running migrations without CLI
InfinityFree doesn't allow `php artisan` via SSH. Import schema using your panel's phpMyAdmin:
1. Export Laravel default tables from `database/sql/base.sql` (if provided) or run locally and export the empty schema to SQL.
2. Import SQL into your InfinityFree database.

### Common gotchas
- Large vendor directories may exceed upload limits. Use the GitHub Actions artifact.
- file_put_contents permission errors: ensure `storage` and `bootstrap/cache` are writable (755 or 775).
- SMTP often blocked; use `MAIL_MAILER=mail` or a transactional API.

