import os
from supabase import create_client, Client

url: str = os.environ.get('SUPABASE_URL', '<url>')
key: str = os.environ.get('SUPBASE_KEY', '<key>')

supabase: Client = create_client(supabase_url=url, supabase_key=key)

def get_supabase_client():
    return supabase
