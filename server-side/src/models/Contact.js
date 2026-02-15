import mongoose from "mongoose";

const ContactSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },

    contactId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },

    status: {
      type: String,
      enum: ['pending', 'accepted', 'blocked'],
      required: true,
    },

    requester: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
    },

    isFavorite: { type: Boolean, default: false },
    
    blockedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
  },
  { timestamps: true }
);

// One row per direction
ContactSchema.index({ userId: 1, contactId: 1 }, { unique: true });

export const Contact = mongoose.model('Contact', ContactSchema);
