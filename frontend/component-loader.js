/**
 * Component Loader - Dynamically loads HTML components into the page
 * This allows us to split large HTML files into smaller, manageable pieces
 */

class ComponentLoader {
    constructor() {
        this.cache = {};
    }

    /**
     * Load a component from a file and insert it into the DOM
     * @param {string} componentPath - Path to the component file
     * @param {string} targetId - ID of the element where component should be inserted
     * @param {string} position - Where to insert: 'replace', 'before', 'after', 'prepend', 'append'
     */
    async loadComponent(componentPath, targetId, position = 'replace') {
        try {
            // Check cache first
            let html = this.cache[componentPath];
            
            if (!html) {
                // Fetch the component
                const response = await fetch(componentPath);
                if (!response.ok) {
                    throw new Error(`Failed to load component: ${componentPath}`);
                }
                html = await response.text();
                this.cache[componentPath] = html;
            }

            // Find target element
            const target = document.getElementById(targetId);
            if (!target) {
                console.error(`Target element not found: ${targetId}`);
                return;
            }

            // Insert the component based on position
            switch(position) {
                case 'replace':
                    target.innerHTML = html;
                    break;
                case 'before':
                    target.insertAdjacentHTML('beforebegin', html);
                    break;
                case 'after':
                    target.insertAdjacentHTML('afterend', html);
                    break;
                case 'prepend':
                    target.insertAdjacentHTML('afterbegin', html);
                    break;
                case 'append':
                    target.insertAdjacentHTML('beforeend', html);
                    break;
                default:
                    target.innerHTML = html;
            }

            // Execute any scripts in the loaded component
            this.executeScripts(target);

        } catch (error) {
            console.error(`Error loading component ${componentPath}:`, error);
        }
    }

    /**
     * Execute scripts found in loaded HTML
     */
    executeScripts(container) {
        const scripts = container.querySelectorAll('script');
        scripts.forEach(oldScript => {
            const newScript = document.createElement('script');
            Array.from(oldScript.attributes).forEach(attr => {
                newScript.setAttribute(attr.name, attr.value);
            });
            newScript.textContent = oldScript.textContent;
            oldScript.parentNode.replaceChild(newScript, oldScript);
        });
    }

    /**
     * Load multiple components
     */
    async loadComponents(components) {
        const promises = components.map(({ path, targetId, position }) => 
            this.loadComponent(path, targetId, position)
        );
        await Promise.all(promises);
    }
}

// Create global instance
window.componentLoader = new ComponentLoader();

// Auto-load components marked with data-component attribute
document.addEventListener('DOMContentLoaded', async () => {
    const componentElements = document.querySelectorAll('[data-component]');
    const components = Array.from(componentElements).map(el => ({
        path: el.dataset.component,
        targetId: el.id,
        position: el.dataset.position || 'replace'
    }));
    
    if (components.length > 0) {
        await window.componentLoader.loadComponents(components);
    }
});