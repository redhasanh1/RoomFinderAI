// Debug script to test why "can you raise it" failed

const testMessage = "can you raise it";

// Test the patterns from ai-negotiation.js
const isAskingForIncrease = /\b(can you|could you|would you).*(raise|increase|go up|higher)/i.test(testMessage) ||
                           /\b(raise it|increase it|go higher|bump it up)/i.test(testMessage);

console.log('Message:', testMessage);
console.log('Pattern 1 match:', /\b(can you|could you|would you).*(raise|increase|go up|higher)/i.test(testMessage));
console.log('Pattern 2 match:', /\b(raise it|increase it|go higher|bump it up)/i.test(testMessage));
console.log('Overall isAskingForIncrease:', isAskingForIncrease);

// Test individual parts
console.log('Has "can you":', /\b(can you|could you|would you)/.test(testMessage));
console.log('Has "raise":', /(raise|increase|go up|higher)/.test(testMessage));

// Test the exact message structure
console.log('Full pattern test:', /\b(can you|could you|would you).*(raise|increase|go up|higher)/i.test(testMessage));

// Expected: should be TRUE