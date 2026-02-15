import express from 'express';
import { 
  getContacts, 
  getRequests, 
  respondToRequest, 
  sendContactRequest, 
  updateContactStatus, 
  deleteContact 
} from '../controllers/contactController.js';

const router = express.Router();

router.post('/request', sendContactRequest);
router.get('/requests/:userId', getRequests);
router.post('/respond', respondToRequest);
router.get('/get_contacts/:userId', getContacts);
router.patch('/:id/status', updateContactStatus);
router.delete('/:contactId', deleteContact);

export default router;