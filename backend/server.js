// server.js
const express = require("express")
const http = require("http")
const dotenv = require("dotenv")
const admin = require("firebase-admin")
const cors = require("cors")
const helmet = require("helmet")
const mongoose = require("mongoose")

// Load environment variables
dotenv.config()

// Initialize Express app
const app = express()

// Middleware
app.use(express.json())
app.use(express.urlencoded({ extended: true }))
app.use(cors()) // Add CORS middleware

// Use Helmet for security headers (with relaxed CSP for development)
app.use(
  helmet({
    contentSecurityPolicy: false, // Disable CSP during development
  }),
)

// Initialize Firebase Admin with environment variables
let firebaseConfig
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  // Use service account from environment variable
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
  firebaseConfig = {
    credential: admin.credential.cert(serviceAccount),
  }
} else {
  // Fall back to service account file (for development)
  try {
    const serviceAccount = require("./firebase-adminsdk.json")
    firebaseConfig = {
      credential: admin.credential.cert(serviceAccount),
    }
  } catch (error) {
    console.error("Error loading Firebase service account:", error)
    process.exit(1)
  }
}

admin.initializeApp(firebaseConfig)

// Connect to MongoDB
mongoose
  .connect(process.env.MONGODB_URI)
  .then(() => console.log("Connected to MongoDB"))
  .catch((err) => {
    console.error("MongoDB connection error:", err)
    process.exit(1)
  })

// Import routes
const userRoutes = require("./routes/userRoutes")
const incomeRoutes = require("./routes/incomeRoutes")
const expenseRoutes = require("./routes/expenseRoutes")
const budgetRoutes = require("./routes/budgetRoutes")
const goalRoutes = require("./routes/goalRoutes")
const alertRoutes = require("./routes/alertRoutes")
const chatRoutes = require("./routes/chatRoutes")
const predictionRoutes = require("./routes/predictionRoutes")

// Middleware to verify Firebase token
const verifyFirebaseToken = async (req, res, next) => {
  const authHeader = req.headers.authorization

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    console.log("Missing or invalid token format:", authHeader)
    return res.status(401).json({ message: "Unauthorized: Missing or invalid token" })
  }

  const token = authHeader.split(" ")[1]

  try {
    console.log("Verifying token:", token.substring(0, 10) + "...")
    const decodedToken = await admin.auth().verifyIdToken(token)
    req.user = decodedToken
    next()
  } catch (error) {
    console.error("Error verifying Firebase token:", error)
    return res.status(401).json({ message: "Unauthorized: Invalid token", error: error.message })
  }
}

// Use routes
app.use("/users", userRoutes)
app.use("/income", incomeRoutes)
app.use("/expenses", expenseRoutes)
app.use("/budgets", budgetRoutes)
app.use("/goals", goalRoutes)
app.use("/alerts", alertRoutes)
app.use("/chat", chatRoutes)
app.use("/prediction", predictionRoutes)

// Basic route for testing
app.get("/", (req, res) => {
  res.send("Personal Finance API is running")
})

// Add this route to your server.js
app.get("/test-auth", verifyFirebaseToken, (req, res) => {
  res.json({
    message: "Authentication successful",
    user: {
      uid: req.user.uid,
      email: req.user.email,
    },
  })
})

// Add this route to your server.js
app.get("/debug-token", (req, res) => {
  const authHeader = req.headers.authorization

  res.json({
    hasAuthHeader: !!authHeader,
    authHeader: authHeader ? authHeader.substring(0, 20) + "..." : null,
    startsWithBearer: authHeader ? authHeader.startsWith("Bearer ") : false,
    tokenLength: authHeader && authHeader.startsWith("Bearer ") ? authHeader.split(" ")[1].length : 0,
  })
})

// Define port
const PORT = process.env.PORT || 5000

// Create HTTP server
const httpServer = http.createServer(app)

// Start server
httpServer.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`)
})

