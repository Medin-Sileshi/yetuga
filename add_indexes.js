const fs = require('fs');
const { execSync } = require('child_process');

// Define all the indexes we want to add
const allIndexes = [
  {
    "collectionGroup": "notifications",
    "queryScope": "COLLECTION",
    "fields": [
      {
        "fieldPath": "userId",
        "order": "ASCENDING"
      },
      {
        "fieldPath": "createdAt",
        "order": "DESCENDING"
      },
      {
        "fieldPath": "__name__",
        "order": "DESCENDING"
      }
    ]
  },
  {
    "collectionGroup": "notifications",
    "queryScope": "COLLECTION",
    "fields": [
      {
        "fieldPath": "eventId",
        "order": "ASCENDING"
      },
      {
        "fieldPath": "senderId",
        "order": "ASCENDING"
      }
    ]
  },
  {
    "collectionGroup": "events",
    "queryScope": "COLLECTION",
    "fields": [
      {
        "fieldPath": "isPrivate",
        "order": "ASCENDING"
      },
      {
        "fieldPath": "createdAt",
        "order": "DESCENDING"
      },
      {
        "fieldPath": "__name__",
        "order": "DESCENDING"
      }
    ]
  },
  {
    "collectionGroup": "events",
    "queryScope": "COLLECTION",
    "fields": [
      {
        "fieldPath": "userId",
        "order": "ASCENDING"
      },
      {
        "fieldPath": "createdAt",
        "order": "DESCENDING"
      },
      {
        "fieldPath": "__name__",
        "order": "DESCENDING"
      }
    ]
  },
  {
    "collectionGroup": "users",
    "queryScope": "COLLECTION",
    "fields": [
      {
        "fieldPath": "username",
        "order": "ASCENDING"
      }
    ]
  }
];

// Function to add an index
function addIndex(index) {
  // Create a temporary file with just this index
  const tempIndexes = {
    "indexes": [index],
    "fieldOverrides": []
  };
  
  fs.writeFileSync('firestore.indexes.json', JSON.stringify(tempIndexes, null, 2));
  
  try {
    // Try to deploy just this index
    console.log(`Deploying index for ${index.collectionGroup} with fields: ${index.fields.map(f => f.fieldPath).join(', ')}...`);
    execSync('firebase deploy --only "firestore:indexes"', { stdio: 'inherit' });
    console.log('Success!');
    return true;
  } catch (error) {
    console.error(`Failed to deploy index: ${error.message}`);
    return false;
  }
}

// Main function to add all indexes one by one
function addAllIndexes() {
  console.log('Starting to add indexes one by one...');
  
  let successCount = 0;
  let failCount = 0;
  
  for (const index of allIndexes) {
    if (addIndex(index)) {
      successCount++;
    } else {
      failCount++;
    }
  }
  
  console.log(`Finished adding indexes. Success: ${successCount}, Failed: ${failCount}`);
  
  // Create the final file with all indexes
  const finalIndexes = {
    "indexes": allIndexes,
    "fieldOverrides": []
  };
  
  fs.writeFileSync('firestore.indexes.json', JSON.stringify(finalIndexes, null, 2));
  console.log('Created final firestore.indexes.json file with all indexes.');
}

// Run the main function
addAllIndexes();
