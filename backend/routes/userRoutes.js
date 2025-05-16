const express = require("express")
const admin = require("firebase-admin")
const User = require("../models/User")
const router = express.Router()
const verifyFirebaseToken = require("../middleware/verifyFirebaseToken") // make sure this exists

/**
 * Validate request body
 */
const validateRequestBody = (req, res, requiredFields) => {
  for (const field of requiredFields) {
    if (!req.body[field]) {
      res.status(400).json({ message: `Missing required field: ${field}` })
      return true
    }
  }
  return false
}

// ** Route: Register New User **
router.post("/register", async (req, res) => {
  const { email, password, username, firebaseUid } = req.body

  // Validate required fields
  if (!email || !username) {
    return res.status(400).json({ message: "Email and username are required" })
  }

  try {
    // Check if user already exists in MongoDB
    const existingUser = await User.findOne({ email })
    if (existingUser) {
      return res.status(400).json({ message: "User already exists in the database." })
    }

    let userFirebaseUid = firebaseUid

    // If no Firebase UID was provided, create a new Firebase user
    if (!userFirebaseUid) {
      if (!password) {
        return res.status(400).json({ message: "Password is required when Firebase UID is not provided" })
      }

      try {
        // Create a new Firebase user
        const firebaseUser = await admin.auth().createUser({
          email,
          password,
        })
        userFirebaseUid = firebaseUser.uid
        console.log(`Created new Firebase user with UID: ${userFirebaseUid}`)
      } catch (firebaseError) {
        console.error(`Firebase user creation error: ${firebaseError.message}`)
        return res.status(500).json({
          message: `Error registering user: ${firebaseError.message}`,
        })
      }
    } else {
      console.log(`Using provided Firebase UID: ${userFirebaseUid}`)
    }

    // Save user in MongoDB
    const newUser = new User({
      firebaseUid: userFirebaseUid,
      email,
      username,
    })
    await newUser.save()
    console.log(`Saved user to MongoDB with UID: ${userFirebaseUid}`)

    return res.status(201).json({ message: "User registered successfully." })
  } catch (error) {
    console.error(`Error registering user: ${error.message}`)
    return res.status(500).json({ message: `Error registering user: ${error.message}` })
  }
})

// ** Route: Login User **
router.post("/login", async (req, res) => {
  const { email, password } = req.body

  // Validate required fields
  if (validateRequestBody(req, res, ["email", "password"])) return

  try {
    // Verify Firebase user
    const userRecord = await admin.auth().getUserByEmail(email)

    // Generate Firebase custom token
    const customToken = await admin.auth().createCustomToken(userRecord.uid)

    // Check if user exists in MongoDB
    const existingUser = await User.findOne({ firebaseUid: userRecord.uid })
    if (!existingUser) {
      return res.status(404).json({ message: "User not found in the database." })
    }

    return res.status(200).json({
      message: "Login successful.",
      token: customToken,
      user: { email: existingUser.email, username: existingUser.username },
    })
  } catch (error) {
    console.error(`Login error: ${error.message}`)
    return res.status(401).json({
      message: "Invalid email or password.",
      error: error.message,
    })
  }
})

// ** Route: Get Current User Info **
// Example usage: GET /users/me
router.get("/me", verifyFirebaseToken, async (req, res) => {
  try {
    // 'req.user.uid' is presumably set by verifyFirebaseToken
    // after verifying the incoming token
    const user = await User.findOne({ firebaseUid: req.user.uid })
    if (!user) {
      return res.status(404).json({ message: "User not found in the database." })
    }
    // Return just the username (and any other fields you want to expose)
    return res.status(200).json({ username: user.username })
  } catch (error) {
    console.error(`Error fetching current user info: ${error.message}`)
    return res.status(500).json({ message: `Error fetching user: ${error.message}` })
  }
})

// Send email verification
router.post("/send-verification-email", verifyFirebaseToken, async (req, res) => {
  try {
    const user = await admin.auth().getUser(req.user.uid)

    if (user.emailVerified) {
      return res.status(200).json({ message: "Email already verified" })
    }

    const customToken = await admin.auth().createCustomToken(user.uid)

    // Generate email verification link
    const actionCodeSettings = {
      url: `${process.env.FRONTEND_URL}/verify-email?token=${customToken}`,
      handleCodeInApp: true,
    }

    await admin.auth().generateEmailVerificationLink(user.email, actionCodeSettings)

    return res.status(200).json({ message: "Verification email sent" })
  } catch (error) {
    console.error(`Error sending verification email: ${error.message}`)
    return res.status(500).json({ message: `Error sending verification email: ${error.message}` })
  }
})

// Password reset request
router.post("/reset-password", async (req, res) => {
  const { email } = req.body

  if (!email) {
    return res.status(400).json({ message: "Email is required" })
  }

  try {
    // Define the action code settings with the correct redirect URL
    const actionCodeSettings = {
      // Make sure this URL is accessible from your Flutter app
      url: `${process.env.FRONTEND_URL || "http://localhost:5000"}/reset-password-confirm`,
      handleCodeInApp: true,
    }

    // Generate and send the password reset link
    await admin.auth().generatePasswordResetLink(email, actionCodeSettings)

    console.log(`Password reset email sent to: ${email}`)
    return res.status(200).json({ message: "Password reset email sent" })
  } catch (error) {
    console.error(`Error sending password reset: ${error.message}`)

    // Don't reveal if the email exists or not for security
    return res.status(200).json({ message: "If the email exists, a password reset link has been sent" })
  }
})

// Check email verification status
router.get("/verification-status", verifyFirebaseToken, async (req, res) => {
  try {
    const user = await admin.auth().getUser(req.user.uid)
    return res.status(200).json({ emailVerified: user.emailVerified })
  } catch (error) {
    console.error(`Error checking verification status: ${error.message}`)
    return res.status(500).json({ message: `Error checking verification status: ${error.message}` })
  }
})

// Clean up a Firebase user by email
router.post("/cleanup-user", async (req, res) => {
  const { email } = req.body

  if (!email) {
    return res.status(400).json({ message: "Email is required" })
  }

  try {
    console.log(`Attempting to clean up user with email: ${email}`)

    // Try to find the user in Firebase
    try {
      const userRecord = await admin.auth().getUserByEmail(email)
      console.log(`Found user in Firebase with UID: ${userRecord.uid}`)

      // Delete the user from Firebase
      await admin.auth().deleteUser(userRecord.uid)
      console.log(`Deleted user from Firebase with UID: ${userRecord.uid}`)

      // Also delete from MongoDB if exists
      const mongoUser = await User.findOne({ email })
      if (mongoUser) {
        await User.deleteOne({ email })
        console.log(`Deleted user from MongoDB with email: ${email}`)
      } else {
        console.log(`No user found in MongoDB with email: ${email}`)
      }

      return res.status(200).json({
        message: "User cleaned up successfully",
        details: {
          firebaseUid: userRecord.uid,
          mongoDeleted: !!mongoUser,
        },
      })
    } catch (error) {
      if (error.code === "auth/user-not-found") {
        console.log(`No user found in Firebase with email: ${email}`)
        return res.status(404).json({ message: "User not found in Firebase" })
      }
      throw error
    }
  } catch (error) {
    console.error(`Error cleaning up user: ${error.message}`)
    return res.status(500).json({
      message: `Error cleaning up user: ${error.message}`,
      stack: error.stack,
    })
  }
})
// Create a test user with the Admin SDK
router.post("/create-test-user", async (req, res) => {
  const { email, password, username } = req.body

  if (!email || !password || !username) {
    return res.status(400).json({ message: "Email, password, and username are required" })
  }

  try {
    console.log(`Creating test user with email: ${email}`)

    // First, try to clean up any existing user with this email
    try {
      const userRecord = await admin.auth().getUserByEmail(email)
      await admin.auth().deleteUser(userRecord.uid)
      console.log(`Deleted existing Firebase user with UID: ${userRecord.uid}`)
    } catch (error) {
      if (error.code !== "auth/user-not-found") {
        throw error
      }
    }

    // Clean up any MongoDB user with this email
    const existingUser = await User.findOne({ email })
    if (existingUser) {
      await User.deleteOne({ email })
      console.log(`Deleted existing MongoDB user with email: ${email}`)
    }

    // Create the user in Firebase
    const userRecord = await admin.auth().createUser({
      email,
      password,
      emailVerified: false,
    })
    console.log(`Created Firebase user with UID: ${userRecord.uid}`)

    // Create the user in MongoDB
    const newUser = new User({
      firebaseUid: userRecord.uid,
      email,
      username,
    })
    await newUser.save()
    console.log(`Created MongoDB user with UID: ${userRecord.uid}`)

    return res.status(201).json({
      message: "Test user created successfully",
      user: {
        uid: userRecord.uid,
        email: userRecord.email,
        username,
      },
    })
  } catch (error) {
    console.error(`Error creating test user: ${error.message}`)
    return res.status(500).json({
      message: `Error creating test user: ${error.message}`,
      stack: error.stack,
    })
  }
})

module.exports = router

