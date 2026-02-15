import mongoose from 'mongoose';

const MessageSchema = new mongoose.Schema({
  chat: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Chat',
    required: true
  },
  sender: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  text: { type: String },
  imageUrl: { type: String },
  status: { 
    type: String, 
    enum: ['sent', 'delivered', 'seen'], 
    default: 'sent' 
  },

  deletedAt: { type: Date }

}, { timestamps: true });

MessageSchema.index({ chat: 1, createdAt: -1 });


export const Message = mongoose.model('Message', MessageSchema);