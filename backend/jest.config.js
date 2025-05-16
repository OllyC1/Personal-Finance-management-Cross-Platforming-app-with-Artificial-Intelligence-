// jest.config.js
module.exports = {
    testEnvironment: 'node',
    coverageDirectory: 'coverage',
    collectCoverageFrom: [
      'services/**/*.js',
      'controllers/**/*.js',
      'models/**/*.js',
      'routes/**/*.js',
      '!**/node_modules/**',
    ],
    reporters: [
      'default',
      ['jest-junit', {
        outputDirectory: './test-results/junit',
        outputName: 'junit.xml',
      }],
      ['jest-html-reporter', {
        pageTitle: 'Test Report',
        outputPath: './test-results/html/test-report.html',
      }],
    ],
  };