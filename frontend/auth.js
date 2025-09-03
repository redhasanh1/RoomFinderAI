const defaultProfileImage = 'data:image/svg+xml;base64,' + btoa(`
    <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">
        <rect width="100" height="100" rx="50" fill="#E5E7EB"/>
        <path d="M50 45C56.075 45 61 40.075 61 34C61 27.925 56.075 23 50 23C43.925 23 39 27.925 39 34C39 40.075 43.925 45 50 45Z" fill="#9CA3AF"/>
        <path d="M30 77C30 77 30 66.103 30 62C30 55.373 36.268 50 44 50H56C63.732 50 70 55.373 70 62C70 66.103 70 77 70 77" fill="#9CA3AF"/>
    </svg>
`.trim());

async function initializeAuth(supabase, allowAnonymous = false) {
    let currentUser = JSON.parse(null);
    const authSection = document.getElementById('authSection');

    if (!currentUser) {
        if (allowAnonymous) {
            console.log('No user found, but anonymous access allowed');
            return false; // Don't redirect, let caller handle
        }
        window.location.href = '/login';
        return false;
    }

    // Check if Supabase is available
    if (!supabase) {
        console.warn('Supabase not available - using local storage only');
        if (authSection) {
            authSection.innerHTML = `
                <a href="/profile">
                    <img id="profileLogo" src="${currentUser.profileImage || defaultProfileImage}" alt="Profile" class="w-10 h-10 rounded-full profile-logo">
                </a>
            `;
        }
        return true;
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
            profile_image: defaultProfileImage
        };
        const { data, error: insertError } = await supabase
            .from('profiles')
            .insert([newProfile])
            .select()
            .single();

        if (insertError) {
            console.error('Error creating profile:', insertError);
            if (allowAnonymous) {
                console.log('Profile creation failed, but anonymous access allowed');
                return false; // Don't redirect, let caller handle
            }
            alert('Failed to initialize user profile.');
            window.location.href = '/login';
            return false;
        }
        profile = data;
    }

    currentUser.id = profile.id;
    
    // Check if profile has old placeholder image and update if needed
    const oldPlaceholderPatterns = [
        'https://via.placeholder.com/',
        'https://ui-avatars.com/api/',
        'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDA',
        'PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDA'
    ];
    
    const needsUpdate = !profile.profile_image || 
        oldPlaceholderPatterns.some(pattern => profile.profile_image.includes(pattern));
    
    
    if (needsUpdate) {
        // Update profile in Supabase
        const { data: updatedProfile, error: updateError } = await supabase
            .from('profiles')
            .update({ profile_image: defaultProfileImage })
            .eq('email', currentUser.email)
            .select()
            .single();
            
        if (updateError) {
            console.error('Error updating profile image:', updateError);
        } else {
            profile = updatedProfile;
        }
    }
    
    currentUser.profileImage = profile.profile_image;
    // localStorage removed - using Supabase);

    authSection.innerHTML = `
        <a href="/profile">
            <img id="profileLogo" src="${currentUser.profileImage}" alt="Profile" class="w-10 h-10 rounded-full profile-logo">
        </a>
    `;
    return true;
}

export { initializeAuth };