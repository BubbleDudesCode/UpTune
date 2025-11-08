-- Recently Played table for Supabase
CREATE TABLE IF NOT EXISTS public.recently_played (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    song_id TEXT NOT NULL,
    title TEXT,
    artist TEXT,
    image_url TEXT,
    provider TEXT,
    metadata JSONB,
    played_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, song_id)
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_recently_played_user_played 
ON public.recently_played(user_id, played_at DESC);

-- RLS Policies
ALTER TABLE public.recently_played ENABLE ROW LEVEL SECURITY;

CREATE POLICY recently_played_select_own ON public.recently_played
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY recently_played_insert_own ON public.recently_played
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY recently_played_update_own ON public.recently_played
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY recently_played_delete_own ON public.recently_played
    FOR DELETE USING (auth.uid() = user_id);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.recently_played TO authenticated;

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_recently_played_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER recently_played_updated_at
    BEFORE UPDATE ON public.recently_played
    FOR EACH ROW
    EXECUTE FUNCTION update_recently_played_updated_at();
