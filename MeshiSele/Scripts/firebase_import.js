const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccount = require('./service-account-key.json'); // You need to download this from Firebase Console

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function importRecipes() {
  try {
    const recipesData = JSON.parse(fs.readFileSync(path.join(__dirname, '../Data/recipes.json'), 'utf8'));
    
    console.log('Starting recipes import...');
    const batch = db.batch();
    
    recipesData.recipes.forEach((recipe) => {
      const docRef = db.collection('recipes').doc(recipe.id);
      // Remove the id field from the data being saved
      const { id, ...recipeWithoutId } = recipe;
      batch.set(docRef, recipeWithoutId);
    });
    
    await batch.commit();
    console.log(`✅ Successfully imported ${recipesData.recipes.length} recipes`);
  } catch (error) {
    console.error('❌ Error importing recipes:', error);
  }
}

async function importEatingOutMeals() {
  try {
    const mealsData = JSON.parse(fs.readFileSync(path.join(__dirname, '../Data/eating_out_meals.json'), 'utf8'));
    
    console.log('Starting eating out meals import...');
    const batch = db.batch();
    
    mealsData.eatingOutMeals.forEach((meal) => {
      const docRef = db.collection('eatingOutMeals').doc(meal.id);
      // Remove the id field from the data being saved
      const { id, ...mealWithoutId } = meal;
      batch.set(docRef, mealWithoutId);
    });
    
    await batch.commit();
    console.log(`✅ Successfully imported ${mealsData.eatingOutMeals.length} eating out meals`);
  } catch (error) {
    console.error('❌ Error importing eating out meals:', error);
  }
}

async function main() {
  await importRecipes();
  await importEatingOutMeals();
  console.log('🎉 Import completed!');
  process.exit(0);
}

main(); 