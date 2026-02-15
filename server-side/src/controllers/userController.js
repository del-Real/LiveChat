import { User } from '../models/User.js';
import bcrypt from 'bcrypt';
import crypto from 'crypto';
import {
  sendVerificationEmail,
  sendResetPasswordEmail
} from '../utils/sendVerificationEmail.js';

//CREATE USER (With Validation & Verification) 
export const createUser = async (req, res) => {
  try {
    let { username, email, password } = req.body;

    // Validation Logic (from Teammate)
    if (!username || !email || !password) {
      return res.status(400).json({ message: "Username, email, and password are required" });
    }

    username = username.trim();
    email = email.toLowerCase().trim();

    const usernameRegex = /^[a-zA-Z0-9_]{3,20}$/;
    if (!usernameRegex.test(username)) {
      return res.status(400).json({ message: "Invalid username format (3-20 chars, alphanumeric)" });
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ message: "Invalid email format" });
    }

    const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&]).{8,}$/;
    if (!passwordRegex.test(password)) {
      return res.status(400).json({
        message: "Password must be at least 8 chars with uppercase, lowercase, number, and symbol",
      });
    }

    // Check Existence
    const existingUser = await User.findOne({ $or: [{ username }, { email }] });
    if (existingUser) {
      return res.status(409).json({ message: "Username or email already in use" });
    }

    //  Hashing & Token Generation
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);
    const verificationToken = crypto.randomBytes(32).toString('hex');

    // Create User
    await User.create({
      username,
      email,
      password: hashedPassword,
      isVerified: false,
      verificationToken,
    });

    //Send Email
    await sendVerificationEmail(email, verificationToken);  //send the email with the token to the user 

    res.status(201).json({
      message: "User created successfully. Please verify your email.",
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

//EMAIL VERIFICATION 
export const verifyEmail = async (req, res) => {
  try {
    const user = await User.findOne({ verificationToken: req.query.token });

    if (!user) {
      return res.send(`
        <html><body style="font-family:Arial; text-align:center; margin-top:50px;">
          <h2>❌ Invalid or expired link</h2>
        </body></html>
      `);
    }

    user.isVerified = true;
    user.verificationToken = undefined;
    await user.save();

    res.send(`
      <html><body style="font-family:Arial; text-align:center; margin-top:50px;">
        <h2>✅ Email verified successfully</h2>
        <p>You can now login to your account.</p>
      </body></html>
    `);
  } catch (err) { 
    res.status(500).send('Server error');
  }
};

// LOGIN USER 
export const loginUser = async (req, res) => {
  try {
    const { identifier, password } = req.body; // Using 'identifier' from your Main

    if (!identifier || !password) {
      return res.status(400).json({ message: "Identifier and password are required" });
    }

    // Find by Username OR Email 
    const user = await User.findOne({
      $or: [
        { username: identifier },
        { email: identifier.toLowerCase() }
      ]
    });

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    //Verification Check 
    if (!user.isVerified) {
      return res.status(401).json({ message: "Please verify your email first" });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: "Invalid password" });
    }

    res.status(200).json({
      message: "Login successful",
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
        displayName: user.displayName,
        profilePicture: user.profilePicture,
      },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

//FORGOT & RESET PASSWORD
export const forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) return res.status(400).json({ message: "Email is required" });

    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ message: "User not found" });

    const resetToken = crypto.randomBytes(32).toString("hex");
    const hashedToken = crypto.createHash("sha256").update(resetToken).digest("hex");

    user.resetPasswordToken = hashedToken;
    user.resetPasswordExpires = Date.now() + 15 * 60 * 1000; // 15 mins
    await user.save();

  await sendResetPasswordEmail(user.email, resetToken);


    res.status(200).json({ message: "Password reset email sent" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
export const resetPassword = async (req, res) => {
  try {
    const { token } = req.params;
    const { password } = req.body;

    
    const passwordRegex =
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&]).{8,}$/;

    if (!passwordRegex.test(password)) {
      return res.status(400).json({
        message:
          "Password must be at least 8 chars with uppercase, lowercase, number, and symbol",
      });
    }

    const hashedToken = crypto
      .createHash("sha256")
      .update(token)
      .digest("hex");

    const user = await User.findOne({
      resetPasswordToken: hashedToken,
      resetPasswordExpires: { $gt: Date.now() },
    });

    if (!user) {
      return res
        .status(400)
        .json({ message: "Invalid or expired token" });
    }

    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(password, salt);
    user.resetPasswordToken = undefined;
    user.resetPasswordExpires = undefined;

    await user.save();

    res.status(200).json({
      message: "Password reset successful",
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};


// SEARCH USER 
export const searchUserByExactUsername = async (req, res) => {
  try {
    const { username } = req.query;
    if (!username) return res.status(400).json({ error: "Username query required" });

    const user = await User.findOne({ username }).select('username _id email');
    if (!user) return res.status(404).json({ message: "User not found" });

    res.status(200).json(user);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const resendVerificationEmail = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ message: "Email is required" });
    }

    const user = await User.findOne({ email });

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    if (user.isVerified) {
      return res.status(400).json({
        message: "Email already verified",
      });
    }

    // Generate a fresh token
    const newToken = crypto.randomBytes(32).toString('hex');
    user.verificationToken = newToken;
    await user.save();

    // Send the new email
    await sendVerificationEmail(email, newToken);

    res.status(200).json({
      message: "Verification email sent again",
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const updateProfile = async (req, res) => {
  try {
    const { userId, displayName, profilePicture } = req.body;
    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { displayName, profilePicture },
      { new: true }
    ).select('-password');

    const io = req.app.get('io'); 
    if (io) {
      io.emit('user_profile_updated', updatedUser);
    }

    res.json(updatedUser);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};