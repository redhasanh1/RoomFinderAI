const profileImages = [
    'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPGNpcmNsZSBjeD0iMjAiIGN5PSIyMCIgcj0iMjAiIGZpbGw9IiM2NjdFRUEiLz4KPGNpcmNsZSBjeD0iMjAiIGN5PSIxNiIgcj0iNiIgZmlsbD0id2hpdGUiLz4KPHBhdGggZD0iTTEwIDMwQzEwIDI1LjU4MTcgMTQuNTgxNyAyMiAyMCAyMkMyNS40MTgzIDIyIDMwIDI1LjU4MTcgMzAgMzBWMzJIMTBWMzBaIiBmaWxsPSJ3aGl0ZSIvPgo8L3N2Zz4K',
    'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPGNpcmNsZSBjeD0iMjAiIGN5PSIyMCIgcj0iMjAiIGZpbGw9IiM0RUNEQzQiLz4KPGNpcmNsZSBjeD0iMjAiIGN5PSIxNiIgcj0iNiIgZmlsbD0id2hpdGUiLz4KPHBhdGggZD0iTTEwIDMwQzEwIDI1LjU4MTcgMTQuNTgxNyAyMiAyMCAyMkMyNS40MTgzIDIyIDMwIDI1LjU4MTcgMzAgMzBWMzJIMTBWMzBaIiBmaWxsPSJ3aGl0ZSIvPgo8L3N2Zz4K',
    'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPGNpcmNsZSBjeD0iMjAiIGN5PSIyMCIgcj0iMjAiIGZpbGw9IiNGRkU2NkQiLz4KPGNpcmNsZSBjeD0iMjAiIGN5PSIxNiIgcj0iNiIgZmlsbD0id2hpdGUiLz4KPHBhdGggZD0iTTEwIDMwQzEwIDI1LjU4MTcgMTQuNTgxNyAyMiAyMCAyMkMyNS40MTgzIDIyIDMwIDI1LjU4MTcgMzAgMzBWMzJIMTBWMzBaIiBmaWxsPSJ3aGl0ZSIvPgo8L3N2Zz4K',
    'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPGNpcmNsZSBjeD0iMjAiIGN5PSIyMCIgcj0iMjAiIGZpbGw9IiM2QjcyODAiLz4KPGNpcmNsZSBjeD0iMjAiIGN5PSIxNiIgcj0iNiIgZmlsbD0id2hpdGUiLz4KPHBhdGggZD0iTTEwIDMwQzEwIDI1LjU4MTcgMTQuNTgxNyAyMiAyMCAyMkMyNS40MTgzIDIyIDMwIDI1LjU4MTcgMzAgMzBWMzJIMTBWMzBaIiBmaWxsPSJ3aGl0ZSIvPgo8L3N2Zz4K',
    'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPGNpcmNsZSBjeD0iMjAiIGN5PSIyMCIgcj0iMjAiIGZpbGw9IiNGRjlGMUMiLz4KPGNpcmNsZSBjeD0iMjAiIGN5PSIxNiIgcj0iNiIgZmlsbD0id2hpdGUiLz4KPHBhdGggZD0iTTEwIDMwQzEwIDI1LjU4MTcgMTQuNTgxNyAyMiAyMCAyMkMyNS40MTgzIDIyIDMwIDI1LjU4MTcgMzAgMzBWMzJIMTBWMzBaIiBmaWxsPSJ3aGl0ZSIvPgo8L3N2Zz4K'
];

async function initializeAuth(supabase) {
    let currentUser = JSON.parse(localStorage.getItem('currentUser'));
    const authSection = document.getElementById('authSection');

    if (!currentUser) {
        window.location.href = '/login';
        return false;
    }

    // Check if user exists in profiles table
    let { data: profile, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('email', currentUser.email)
        .single();

    if (error || !profile) {
        // Create profile if it doesn't exist
        const newProfile = {
            email: currentUser.email,
            profile_image: profileImages[Math.floor(Math.random() * profileImages.length)]
        };
        const { data, error: insertError } = await supabase
            .from('profiles')
            .insert([newProfile])
            .select()
            .single();

        if (insertError) {
            console.error('Error creating profile:', insertError);
            alert('Failed to initialize user profile.');
            window.location.href = '/login';
            return false;
        }
        profile = data;
    }

    currentUser.id = profile.id;
    currentUser.profileImage = profile.profile_image;
    localStorage.setItem('currentUser', JSON.stringify(currentUser));

    authSection.innerHTML = `
        <a href="/profile">
            <img id="profileLogo" src="${currentUser.profileImage}" alt="Profile" class="w-10 h-10 rounded-full profile-logo">
        </a>
    `;
    return true;
}

export { initializeAuth };