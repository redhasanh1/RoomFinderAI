const profileImages = [
    'https://via.placeholder.com/40/FF6B6B',
    'https://via.placeholder.com/40/4ECDC4',
    'https://via.placeholder.com/40/FFE66D',
    'https://via.placeholder.com/40/6B7280',
    'https://via.placeholder.com/40/FF9F1C'
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