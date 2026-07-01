const fs = require('fs').promises;
const path = require('path');

async function analyzeWebsite(websitePath) {
  try {
    const files = await getAllFiles(websitePath);
    const analysis = {
      jsFiles: [],
      htmlFiles: [],
      cssFiles: [],
      apiCalls: [],
      components: [],
      routes: [],
      features: []
    };

    for (const file of files) {
      const ext = path.extname(file).toLowerCase();
      const relativePath = path.relative(websitePath, file);
      
      if (ext === '.js' || ext === '.jsx' || ext === '.ts' || ext === '.tsx') {
        analysis.jsFiles.push(relativePath);
        try {
          const content = await fs.readFile(file, 'utf-8');
          
          // Check for API calls
          if (content.includes('fetch') || content.includes('axios') || content.includes('$.ajax') || content.includes('XMLHttpRequest')) {
            analysis.apiCalls.push(relativePath);
          }
          
          // Check for React components
          if (content.includes('React.Component') || content.includes('function') || content.includes('const') && content.includes('return')) {
            analysis.components.push(relativePath);
          }
          
          // Check for routing
          if (content.includes('router') || content.includes('Route') || content.includes('navigate')) {
            analysis.routes.push(relativePath);
          }
          
          // Check for specific features
          if (content.includes('login') || content.includes('auth')) {
            analysis.features.push(`${relativePath}: Authentication`);
          }
          if (content.includes('product') || content.includes('listing')) {
            analysis.features.push(`${relativePath}: Product/Listing Management`);
          }
          if (content.includes('search') || content.includes('filter')) {
            analysis.features.push(`${relativePath}: Search/Filter Functionality`);
          }
          if (content.includes('chat') || content.includes('message')) {
            analysis.features.push(`${relativePath}: Chat/Messaging`);
          }
          if (content.includes('map') || content.includes('location')) {
            analysis.features.push(`${relativePath}: Map/Location Features`);
          }
          if (content.includes('payment') || content.includes('stripe') || content.includes('paypal')) {
            analysis.features.push(`${relativePath}: Payment Integration`);
          }
        } catch (error) {
          console.warn(`Could not read file ${file}:`, error.message);
        }
      } else if (ext === '.html') {
        analysis.htmlFiles.push(relativePath);
      } else if (ext === '.css') {
        analysis.cssFiles.push(relativePath);
      }
    }

    console.log('🔍 Website Analysis Results:');
    console.log('=' .repeat(50));
    console.log(`📁 JavaScript Files (${analysis.jsFiles.length}):`);
    analysis.jsFiles.slice(0, 10).forEach(file => console.log(`  - ${file}`));
    if (analysis.jsFiles.length > 10) console.log(`  ... and ${analysis.jsFiles.length - 10} more`);
    
    console.log(`\n📄 HTML Files (${analysis.htmlFiles.length}):`);
    analysis.htmlFiles.slice(0, 10).forEach(file => console.log(`  - ${file}`));
    if (analysis.htmlFiles.length > 10) console.log(`  ... and ${analysis.htmlFiles.length - 10} more`);
    
    console.log(`\n🎨 CSS Files (${analysis.cssFiles.length}):`);
    analysis.cssFiles.slice(0, 10).forEach(file => console.log(`  - ${file}`));
    if (analysis.cssFiles.length > 10) console.log(`  ... and ${analysis.cssFiles.length - 10} more`);
    
    console.log(`\n🌐 Files with API Calls (${analysis.apiCalls.length}):`);
    analysis.apiCalls.forEach(file => console.log(`  - ${file}`));
    
    console.log(`\n⚛️ React Components (${analysis.components.length}):`);
    analysis.components.slice(0, 10).forEach(file => console.log(`  - ${file}`));
    if (analysis.components.length > 10) console.log(`  ... and ${analysis.components.length - 10} more`);
    
    console.log(`\n🧭 Routing Files (${analysis.routes.length}):`);
    analysis.routes.forEach(file => console.log(`  - ${file}`));
    
    console.log(`\n✨ Detected Features (${analysis.features.length}):`);
    analysis.features.forEach(feature => console.log(`  - ${feature}`));
    
    console.log('\n📋 Migration Recommendations:');
    console.log('=' .repeat(50));
    
    if (analysis.features.some(f => f.includes('Authentication'))) {
      console.log('🔐 Authentication: Implement login/signup screens with secure token storage');
    }
    if (analysis.features.some(f => f.includes('Product/Listing'))) {
      console.log('🏠 Listings: Create FlatList components for property listings with native iOS cards');
    }
    if (analysis.features.some(f => f.includes('Search/Filter'))) {
      console.log('🔍 Search: Implement native search bars and filter modals');
    }
    if (analysis.features.some(f => f.includes('Chat/Messaging'))) {
      console.log('💬 Chat: Use React Native chat libraries with native keyboard handling');
    }
    if (analysis.features.some(f => f.includes('Map/Location'))) {
      console.log('🗺️ Maps: Integrate react-native-maps for native iOS map experience');
    }
    if (analysis.features.some(f => f.includes('Payment'))) {
      console.log('💳 Payments: Use React Native payment SDKs (Stripe, Apple Pay)');
    }
    
  } catch (error) {
    console.error('Error analyzing website:', error);
  }
}

async function getAllFiles(dir) {
  const files = [];
  const items = await fs.readdir(dir, { withFileTypes: true });
  
  for (const item of items) {
    const fullPath = path.join(dir, item.name);
    
    // Skip node_modules, .git, and other common directories
    if (item.isDirectory() && !['node_modules', '.git', '.next', 'build', 'dist', 'coverage'].includes(item.name)) {
      files.push(...await getAllFiles(fullPath));
    } else if (item.isFile()) {
      files.push(fullPath);
    }
  }
  
  return files;
}

// Analyze the frontend directory of RoomFinderAI
analyzeWebsite('./frontend');