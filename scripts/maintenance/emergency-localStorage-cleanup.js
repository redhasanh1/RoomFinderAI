// Emergency localStorage cleanup script
// Paste this into your browser console to free up space immediately

console.log('🚨 Emergency localStorage cleanup starting...');

// 1. Check current usage
let totalSize = 0;
const keys = [];
for (let i = 0; i < localStorage.length; i++) {
    const key = localStorage.key(i);
    const size = localStorage.getItem(key).length;
    totalSize += size;
    keys.push({ key, size });
}

console.log(`📊 Current localStorage usage: ${(totalSize / (1024 * 1024)).toFixed(2)}MB across ${keys.length} keys`);

// 2. Show largest keys
keys.sort((a, b) => b.size - a.size);
console.log('📈 Largest keys:');
keys.slice(0, 10).forEach(({key, size}) => {
    console.log(`  - ${key}: ${(size / (1024 * 1024)).toFixed(2)}MB`);
});

// 3. Emergency cleanup - keep only essential auth data
const essentialKeys = ['currentUser', 'authToken'];
let removedCount = 0;
let freedSpace = 0;

for (let i = localStorage.length - 1; i >= 0; i--) {
    const key = localStorage.key(i);
    if (key && !essentialKeys.includes(key)) {
        const size = localStorage.getItem(key).length;
        localStorage.removeItem(key);
        removedCount++;
        freedSpace += size;
    }
}

console.log(`🧹 Removed ${removedCount} keys, freed ${(freedSpace / (1024 * 1024)).toFixed(2)}MB`);

// 4. Test if we can write now
try {
    const testData = 'x'.repeat(1024); // 1KB test
    localStorage.setItem('__test__', testData);
    localStorage.removeItem('__test__');
    console.log('✅ localStorage is now writable!');
} catch (error) {
    console.log('❌ Storage still full, may need to clear browser data manually');
}

console.log('🎉 Emergency cleanup complete! Refresh the page to continue.');