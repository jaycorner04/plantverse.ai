-- supabase_schema.sql
-- Run this in the Supabase SQL Editor to initialize your PlantVerse AI database

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. USERS
CREATE TABLE users (
  id UUID REFERENCES auth.users NOT NULL PRIMARY KEY,
  username TEXT UNIQUE,
  full_name TEXT,
  avatar_url TEXT,
  xp_points INTEGER DEFAULT 0,
  gardening_streak INTEGER DEFAULT 0,
  is_premium BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Row Level Security (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public profiles are viewable by everyone." ON users FOR SELECT USING (TRUE);
CREATE POLICY "Users can insert their own profile." ON users FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile." ON users FOR UPDATE USING (auth.uid() = id);

-- 2. PLANTS (Encyclopedia)
CREATE TABLE plants (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  common_name TEXT NOT NULL,
  scientific_name TEXT NOT NULL,
  family TEXT,
  genus TEXT,
  description TEXT,
  image_url TEXT,
  native_region TEXT,
  climate_zone TEXT,
  toxicity_level TEXT, -- e.g., 'None', 'Low', 'High'
  care_difficulty TEXT, -- 'Beginner', 'Intermediate', 'Advanced'
  water_requirement TEXT,
  sunlight_requirement TEXT,
  story_markdown TEXT,
  is_rare BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW())
);

-- RLS
ALTER TABLE plants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Plants are viewable by everyone." ON plants FOR SELECT USING (TRUE);

-- 3. SCANS (History)
CREATE TABLE scans (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  image_url TEXT NOT NULL,
  plant_id UUID REFERENCES plants(id),
  confidence_score FLOAT,
  ai_analysis_json JSONB,
  scanned_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW())
);

-- RLS
ALTER TABLE scans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own scans." ON scans FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own scans." ON scans FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own scans." ON scans FOR DELETE USING (auth.uid() = user_id);

-- 4. SAVED_PLANTS (Personal Garden)
CREATE TABLE saved_plants (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  plant_id UUID REFERENCES plants(id),
  custom_name TEXT,
  date_added TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()),
  last_watered TIMESTAMP WITH TIME ZONE,
  last_fertilized TIMESTAMP WITH TIME ZONE
);

-- RLS
ALTER TABLE saved_plants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their garden." ON saved_plants FOR ALL USING (auth.uid() = user_id);

-- 5. REMINDERS
CREATE TABLE reminders (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  saved_plant_id UUID REFERENCES saved_plants(id) ON DELETE CASCADE NOT NULL,
  reminder_type TEXT, -- 'Water', 'Fertilize', 'Repot'
  frequency_days INTEGER,
  next_due_date TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN DEFAULT TRUE
);

-- RLS
ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their reminders." ON reminders FOR ALL USING (auth.uid() = user_id);

-- 6. COMMUNITY POSTS
CREATE TABLE posts (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  image_url TEXT NOT NULL,
  caption TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW())
);

-- RLS
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Posts are viewable by everyone." ON posts FOR SELECT USING (TRUE);
CREATE POLICY "Users can manage their posts." ON posts FOR ALL USING (auth.uid() = user_id);

-- 7. FOLLOWERS (Community)
CREATE TABLE followers (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  follower_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  following_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()),
  UNIQUE(follower_id, following_id)
);

-- RLS
ALTER TABLE followers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Followers are viewable by everyone." ON followers FOR SELECT USING (TRUE);
CREATE POLICY "Users can manage their following." ON followers FOR ALL USING (auth.uid() = follower_id);

-- Set up storage buckets
-- Note: You'll also need to create storage buckets via the UI or API:
-- 1. 'avatars'
-- 2. 'scans'
-- 3. 'posts'
