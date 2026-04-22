import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { v4 as uuidv4 } from 'uuid';
import logger from '../../utils/logger';

// Ensure uploads directory exists
const uploadsDir = path.join(process.cwd(), 'uploads');
const subDirs = ['avatars', 'equipment', 'gyms'];

export function ensureUploadDirs() {
  if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
  }
  subDirs.forEach(dir => {
    const subPath = path.join(uploadsDir, dir);
    if (!fs.existsSync(subPath)) {
      fs.mkdirSync(subPath, { recursive: true });
    }
  });
}

// File type validation
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB

export type UploadCategory = 'avatars' | 'equipment' | 'gyms';

// Storage configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const category = (req.params.category as UploadCategory) || 'avatars';
    const destPath = path.join(uploadsDir, category);
    cb(null, destPath);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const uniqueName = `${uuidv4()}${ext}`;
    cb(null, uniqueName);
  }
});

// File filter
const fileFilter = (req: Express.Request, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  if (ALLOWED_TYPES.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error('Invalid file type. Only JPEG, PNG, WebP, and GIF are allowed.'));
  }
};

// Multer instance
export const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: MAX_FILE_SIZE
  }
});

// Upload service class
export class UploadService {
  static getFileUrl(filename: string, category: UploadCategory): string {
    return `/uploads/${category}/${filename}`;
  }

  static async deleteFile(filename: string, category: UploadCategory): Promise<boolean> {
    const filePath = path.join(uploadsDir, category, filename);
    try {
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
        return true;
      }
      return false;
    } catch (error) {
      logger.warn({ error }, 'Error deleting file');
      return false;
    }
  }

  static extractFilename(url: string): string | null {
    const match = url.match(/\/uploads\/[^/]+\/([^/]+)$/);
    return match ? match[1] : null;
  }
}

// Error class
export class UploadValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'UploadValidationError';
  }
}

