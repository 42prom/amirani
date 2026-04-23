import { Router, Request, Response } from 'express';
import prisma from '../../lib/prisma';
import logger from '../../lib/logger';

const router = Router();

/**
 * GET /api/gyms/:gymId/language/:lang
 * Fetch a dynamic language pack for a specific gym.
 * Fallback to system default if gym-specific pack is missing.
 * Implements ETag caching for flagship performance.
 */
router.get('/:gymId/language/:lang', async (req: Request, res: Response) => {
  try {
    const { gymId, lang } = req.params;
    const normalizedLang = lang.toUpperCase();

    // 1. Try fetching gym-specific pack
    let pack = await prisma.languagePack.findUnique({
      where: { gymId_language: { gymId, language: normalizedLang } }
    });

    // 2. Fallback to system default (where gymId is null)
    if (!pack) {
      pack = await prisma.languagePack.findFirst({
        where: { gymId: null, language: normalizedLang }
      });
    }

    if (!pack) {
      return res.status(404).json({ error: `Language pack for ${normalizedLang} not found` });
    }

    // 3. ETag Caching Logic (Flagship Efficiency)
    const etag = `W/"${pack.version}-${pack.updatedAt.getTime()}"`;
    if (req.headers['if-none-match'] === etag) {
      return res.status(304).end();
    }

    res.setHeader('ETag', etag);
    res.setHeader('Cache-Control', 'public, max-age=3600'); // Cache for 1 hour
    res.json({
      language: pack.language,
      version: pack.version,
      updatedAt: pack.updatedAt,
      data: pack.data
    });

  } catch (err: any) {
    logger.error('[i18n] Failed to fetch language pack', { err: err.message, params: req.params });
    res.status(500).json({ error: 'Internal server error fetching language pack' });
  }
});

export default router;
