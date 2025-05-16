// middleware/verifyFirebaseToken.js
const admin = require('firebase-admin');

const verifyFirebaseToken = async (req, res, next) => {
  console.log('Headers:', JSON.stringify(req.headers)); // Log all headers for debugging
  
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    console.log('No authorization header found');
    return res.status(401).json({ message: 'Unauthorized: No token provided' });
  }
  
  console.log('Auth header:', authHeader);
  
  if (!authHeader.startsWith('Bearer ')) {
    console.log('Authorization header does not start with Bearer');
    return res.status(401).json({ message: 'Unauthorized: Invalid token format' });
  }

  const idToken = authHeader.split(' ')[1];
  if (!idToken) {
    console.log('No token found after Bearer prefix');
    return res.status(401).json({ message: 'Unauthorized: Empty token' });
  }

  console.log('Token length:', idToken.length);
  console.log('Token first 10 chars:', idToken.substring(0, 10));

  try {
    console.log('Verifying token...');
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    console.log('Token verified successfully for user:', decodedToken.uid);
    
    req.user = decodedToken;
    next();
  } catch (error) {
    console.error('Token verification failed:', error);
    
    // Handle different Firebase auth errors
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({
        message: 'Token expired',
        code: 'token-expired'
      });
    } else if (error.code === 'auth/id-token-revoked') {
      return res.status(401).json({
        message: 'Token has been revoked',
        code: 'token-revoked'
      });
    }
    
    return res.status(401).json({
      message: 'Unauthorized: Invalid token',
      code: 'invalid-token'
    });
  }
};

module.exports = verifyFirebaseToken;