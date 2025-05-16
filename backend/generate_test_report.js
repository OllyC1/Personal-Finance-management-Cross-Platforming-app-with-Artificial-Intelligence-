const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Create directories if they don't exist
const testResultsDir = path.join(__dirname, 'test-results');
const htmlDir = path.join(testResultsDir, 'html');
const jsonDir = path.join(testResultsDir, 'json');

if (!fs.existsSync(testResultsDir)) fs.mkdirSync(testResultsDir);
if (!fs.existsSync(htmlDir)) fs.mkdirSync(htmlDir);
if (!fs.existsSync(jsonDir)) fs.mkdirSync(jsonDir);

// Run tests with coverage
console.log('Running tests with coverage...');
try {
  execSync('npm run test:coverage -- --config=jest.config.js --passWithNoTests', { stdio: 'inherit' });
} catch (error) {
  console.error('Some tests failed, but continuing with report generation');
}

// Run tests with reporters
console.log('Generating test reports...');
try {
  execSync('npm run test:report -- --config=jest.config.js --passWithNoTests', { stdio: 'inherit' });
} catch (error) {
  console.error('Error generating reports, but continuing');
}

// Generate a summary JSON file
console.log('Generating summary...');
try {
  const jestOutput = execSync('npm test -- --config=jest.config.js --json --passWithNoTests').toString();
  let testResults;
  
  try {
    // Find the JSON part of the output (skip npm output)
    const jsonStart = jestOutput.indexOf('{');
    if (jsonStart >= 0) {
      testResults = JSON.parse(jestOutput.substring(jsonStart));
    } else {
      throw new Error('No JSON found in output');
    }
  } catch (e) {
    console.error('Error parsing Jest output, using default summary:', e.message);
    testResults = {};
  }
  
  const summary = {
    numTotalTests: testResults.numTotalTests || 0,
    numPassedTests: testResults.numPassedTests || 0,
    numFailedTests: testResults.numFailedTests || 0,
    numPendingTests: testResults.numPendingTests || 0,
    testResults: (testResults.testResults || []).map(suite => ({
      name: suite.name,
      status: suite.status,
      tests: (suite.assertionResults || []).map(test => ({
        title: test.title,
        status: test.status,
        duration: test.duration
      }))
    }))
  };
  
  fs.writeFileSync(
    path.join(jsonDir, 'summary.json'),
    JSON.stringify(summary, null, 2)
  );
} catch (error) {
  console.error('Error generating summary:', error);
  
  // Create a default summary if no tests exist
  const defaultSummary = {
    numTotalTests: 0,
    numPassedTests: 0,
    numFailedTests: 0,
    numPendingTests: 0,
    testResults: [],
    message: "No tests found in the project or error running tests. Please check your test files."
  };
  
  fs.writeFileSync(
    path.join(jsonDir, 'summary.json'),
    JSON.stringify(defaultSummary, null, 2)
  );
}

console.log('Test reports generated successfully!');
console.log(`HTML Report: ${path.join(htmlDir, 'test-report.html')}`);
console.log(`Coverage Report: ${path.join(__dirname, 'coverage', 'index.html')}`);
console.log(`Summary JSON: ${path.join(jsonDir, 'summary.json')}`);