const { execSync } = require('child_process');

try {
  // Run the Firebase CLI command to get the current indexes
  const output = execSync('firebase firestore:indexes', { encoding: 'utf8' });
  console.log('Current Firestore indexes:');
  console.log(output);
} catch (error) {
  console.error('Error fetching indexes:', error.message);
}
