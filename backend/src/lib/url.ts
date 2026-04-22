import { Request } from 'express';

/** Format relative URL to absolute URL */
export const getFullUrl = (req: Request | any, url: string | null | undefined): string | null => {
  if (!url) return null;
  if (url.startsWith('http')) return url;
  const protocol = req.headers['x-forwarded-proto'] || req.protocol;
  const host = req.get('host');
  return `${protocol}://${host}${url.startsWith('/') ? '' : '/'}${url}`;
};
