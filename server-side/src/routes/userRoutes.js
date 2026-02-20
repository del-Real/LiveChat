import express from 'express';
import { 
  createUser, 
  loginUser, 
  searchUserByExactUsername, 
  verifyEmail,               
  resendVerificationEmail,    
  forgotPassword,            
  resetPassword,
  updateProfile  
} from '../controllers/userController.js';

const router = express.Router();

// --- Registration & Verification ---
router.post('/create', createUser);
router.get('/verify-email', verifyEmail);
router.post('/resend-verification', resendVerificationEmail);

// --- Password Management ---
router.post('/forgot-password', forgotPassword);
router.post('/reset-password/:token', resetPassword);

// --- Authentication & Discovery ---
router.post('/login', loginUser);
router.get('/search', searchUserByExactUsername); 

router.put('/update-profile', updateProfile);

export default router;