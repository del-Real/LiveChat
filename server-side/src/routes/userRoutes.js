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


router.post('/create', createUser);
router.get('/verify-email', verifyEmail);
router.post('/resend-verification', resendVerificationEmail);


router.post('/forgot-password', forgotPassword);
router.post('/reset-password/:token', resetPassword);


router.post('/login', loginUser);
router.get('/search', searchUserByExactUsername); 

router.put('/update-profile', updateProfile);

export default router;