# Personal Finance App

A cross-platform personal finance application built with Flutter (frontend) and Node.js (backend).

## Project Structure

This repository contains both frontend and backend code:

- `/frontend` - Flutter application for cross-platform (iOS, Android, Web, Desktop)
- `/backend` - Node.js server with Express

## Technologies Used

### Frontend
- Flutter/Dart
- Cross-platform support (iOS, Android, Web, Windows, macOS, Linux)

### Backend
- Node.js
- Express
- MongoDB
- JWT Authentication

## Features
- User authentication
- Expense tracking
- Budget management
- Financial insights
- Cross-platform compatibility

## Screenshots
![Dashboard](screenshots/dashboard.png ), (screenshots/dashboard_mobile.png )

### Budget Management
![Budget Management](screenshots/budget.png)

### Expense Tracking
![Expense Tracking](screenshots/expense.png)

### Income Tracking
![Income Tracking](screenshots/income.png)

### Prediction Tracking
![Prediction Tracking](screenshots/prediction.png)
### Report Tracking
![Report Tracking](screenshots/report.png)


## Setup Instructions

### Backend Setup
1. Navigate to the backend directory: `cd backend`
2. Install dependencies: `npm install`
3. Create a `.env` file with required environment variables
4. Start the server: `npm start`

### Frontend Setup
1. Navigate to the frontend directory: `cd frontend`
2. Install Flutter dependencies: `flutter pub get`
3. Run the application: `flutter run`

## Firebase Setup

This application uses Firebase for authentication and database services. To set up:

1. Create a Firebase project at https://console.firebase.google.com/
2. Generate a service account key:
   - Go to Project Settings > Service Accounts
   - Click "Generate New Private Key"
   - Save the file securely (do not commit to Git)

3. Create a `.env` file in the backend directory with the following variables:

## Contact
For any questions about this project, please contact me at Oladipoibrahim9@gmail.com