import dotenv from 'dotenv';
import path from 'path';

// Load .env from the root/backend directory
dotenv.config({ path: path.resolve(__dirname, '../../.env') });
