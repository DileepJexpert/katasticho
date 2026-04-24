ALTER TABLE app_user ADD COLUMN IF NOT EXISTS default_landing_page VARCHAR(50) DEFAULT '/dashboard';
