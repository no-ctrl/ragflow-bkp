const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, '..', 'node_modules', '@umijs', 'plugins', 'dist', 'tailwindcss.js');

if (fs.existsSync(filePath)) {
  let content = fs.readFileSync(filePath, 'utf8');
  // Check if already patched to avoid redundant writes (though replace handles it)
  // We look for the variable definition and replace the value
  const newContent = content.replace(/var CHECK_TIMEOUT_UNIT_SECOND = \d+;/, 'var CHECK_TIMEOUT_UNIT_SECOND = 300;');

  if (content !== newContent) {
    fs.writeFileSync(filePath, newContent, 'utf8');
    console.log('Successfully patched tailwindcss.js timeout to 300s');
  } else {
    // Check if it's already 300 to confirm
    if (content.includes('var CHECK_TIMEOUT_UNIT_SECOND = 300;')) {
        console.log('tailwindcss.js is already patched (timeout = 300s)');
    } else {
        console.warn('Could not find pattern "var CHECK_TIMEOUT_UNIT_SECOND = ...;" in tailwindcss.js');
    }
  }
} else {
  console.warn('tailwindcss.js not found at ' + filePath + ', skipping patch');
}
