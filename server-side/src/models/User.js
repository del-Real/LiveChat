import mongoose from 'mongoose';

const UserSchema = new mongoose.Schema(
  {
    username: { 
      type: String, 
      required: true, 
      unique: true, 
      trim: true 
    },
    email: { 
      type: String, 
      required: true, 
      unique: true, 
      lowercase: true, 
      trim: true 
    },
    password: { 
      type: String, 
      required: true 
    },

    displayName: { 
      type: String, trim: true 
    },
    profilePicture: { 
      type: String, default: "" 
    },
    
    isVerified: { 
      type: Boolean, 
      default: false 
    },
    verificationToken: { 
      type: String 
    },

    resetPasswordToken: {
      type: String,
    },
    resetPasswordExpires: {
      type: Date,
    },
  },
  { timestamps: true }
);


UserSchema.index({ chats: 1 });

export const User = mongoose.model('User', UserSchema); // create user using user scema from the mongo 
//to allow me to use it in the other files