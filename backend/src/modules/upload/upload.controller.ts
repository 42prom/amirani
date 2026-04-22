import { Router, Response } from 'express';
import { upload, UploadService, UploadCategory, ensureUploadDirs } from './upload.service';
import { authenticate, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { success, validationError, internalError } from '../../utils/response';
import logger from '../../utils/logger';

const router = Router();

// Ensure upload directories exist on startup
ensureUploadDirs();

// All upload routes require authentication
router.use(authenticate);

/**
 * POST /upload/:category - Upload a file
 * Categories: avatars, equipment, gyms
 */
router.post('/:category', (req: AuthenticatedRequest, res: Response) => {
  const category = req.params.category as UploadCategory;

  // Validate category
  if (!['avatars', 'equipment', 'gyms'].includes(category)) {
    return validationError(res, [{ field: 'category', message: 'Invalid category. Must be avatars, equipment, or gyms.' }]);
  }

  upload.single('file')(req, res, (err) => {
    if (err) {
      if (err.message.includes('Invalid file type')) {
        return validationError(res, [{ field: 'file', message: err.message }]);
      }
      if (err.code === 'LIMIT_FILE_SIZE') {
        return validationError(res, [{ field: 'file', message: 'File size exceeds 5MB limit.' }]);
      }
      logger.error({ err }, 'Upload error');
      return internalError(res);
    }

    if (!req.file) {
      return validationError(res, [{ field: 'file', message: 'No file uploaded.' }]);
    }

    const url = UploadService.getFileUrl(req.file.filename, category);

    success(res, {
      filename: req.file.filename,
      url,
      originalName: req.file.originalname,
      size: req.file.size,
      mimetype: req.file.mimetype
    });
  });
});

/**
 * DELETE /upload/:category/:filename - Delete a file
 */
router.delete('/:category/:filename', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { category, filename } = req.params;

    if (!['avatars', 'equipment', 'gyms'].includes(category)) {
      return validationError(res, [{ field: 'category', message: 'Invalid category.' }]);
    }

    const deleted = await UploadService.deleteFile(filename, category as UploadCategory);

    if (deleted) {
      success(res, { message: 'File deleted successfully.' });
    } else {
      success(res, { message: 'File not found or already deleted.' });
    }
  } catch (err) {
    logger.error({ err }, 'Delete file error');
    internalError(res);
  }
});

export default router;

