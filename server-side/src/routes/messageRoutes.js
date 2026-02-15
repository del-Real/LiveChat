import express from 'express';
import multer from 'multer';
import { getMessagesPaginated, deleteMessage, uploadImage } from '../controllers/messageController.js';

const router = express.Router();

// Configure storage with limits and file filtering to prevent 400 errors
const storage = multer.memoryStorage();
const upload = multer({ 
  storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error(`The server received type ${file.mimetype}`), false);
    }
  }
});

router.get('/paginated/:chatId', getMessagesPaginated);
router.delete('/:messageId', deleteMessage);

// Updated route with custom error handling for the 'image' field
router.post('/upload', (req, res, next) => {
  upload.single('image')(req, res, (err) => {
    if (err instanceof multer.MulterError) {
      // A Multer error occurred (e.g., file too large, wrong field name)
      return res.status(400).json({ error: `Multer Error: ${err.message}` });
    } else if (err) {
      // An unknown error occurred
      return res.status(400).json({ error: err.message });
    }
    // Everything went fine, move to the controller
    next();
  });
}, uploadImage);

export default router;