let cities = [];

function setupAutocomplete() {
    fetch('https://unpkg.com/cities.json@1.1.0/cities.json')
        .then(response => response.json())
        .then(data => {
            cities = data;
            console.log('Cities loaded:', cities.length);
        })
        .catch(error => {
            console.error('Error loading cities:', error);
            alert('Failed to load city data. Please enter locations manually.');
            document.getElementById('location').placeholder = 'Enter location manually (e.g., Toronto, Ontario, Canada)';
        });

    const locationInput = document.getElementById('location');
    const dropdown = document.getElementById('autocomplete-dropdown');
    let debounceTimeout;

    function showSuggestions(input) {
        dropdown.innerHTML = '';
        dropdown.classList.add('hidden');
        if (!input || cities.length === 0) return;

        const filtered = cities
            .filter(city =>
                city.name.toLowerCase().startsWith(input.toLowerCase()) ||
                city.name.toLowerCase().includes(input.toLowerCase())
            )
            .slice(0, 10)
            .map(city => ({
                display: `${city.name}${city.admin_name ? `, ${city.admin_name}` : ''}, ${city.country}`,
                value: city
            }));

        if (filtered.length === 0) {
            const item = document.createElement('div');
            item.className = 'autocomplete-item text-gray-500';
            item.textContent = 'No matching cities';
            dropdown.appendChild(item);
            dropdown.classList.remove('hidden');
            return;
        }

        filtered.forEach(loc => {
            const item = document.createElement('div');
            item.className = 'autocomplete-item';
            item.textContent = loc.display;
            item.addEventListener('click', () => {
                locationInput.value = loc.display;
                dropdown.classList.add('hidden');
                console.log('Selected location:', loc.display);
            });
            dropdown.appendChild(item);
        });

        dropdown.classList.remove('hidden');
        console.log('Showing suggestions for:', input, filtered.map(f => f.display));
    }

    locationInput.addEventListener('input', () => {
        clearTimeout(debounceTimeout);
        debounceTimeout = setTimeout(() => {
            const value = locationInput.value.trim();
            console.log('Input event:', value);
            showSuggestions(value);
        }, 300);
    });

    locationInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !dropdown.classList.contains('hidden')) {
            const firstItem = dropdown.querySelector('.autocomplete-item:not(.text-gray-500)');
            if (firstItem) {
                locationInput.value = firstItem.textContent;
                dropdown.classList.add('hidden');
                console.log('Enter key selected:', firstItem.textContent);
            }
            e.preventDefault();
        }
    });

    document.addEventListener('click', (e) => {
        if (!locationInput.contains(e.target) && !dropdown.contains(e.target)) {
            dropdown.classList.add('hidden');
            console.log('Dropdown hidden');
        }
    });
}

export { setupAutocomplete };