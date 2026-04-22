// Global test setup — runs before every test file
// Suppress logger output during tests to keep output clean
vi.mock('../lib/logger', () => ({
  default: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
    debug: vi.fn(),
  },
  requestLogger: (_req: unknown, _res: unknown, next: () => void) => next(),
}));
