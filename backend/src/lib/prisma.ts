import { PrismaClient, Prisma } from '@prisma/client';

/**
 * Global soft-delete filter via Prisma Client Extension.
 *
 * Automatically injects `deletedAt: null` into every read operation
 * (findFirst, findMany, findUnique, count, aggregate, groupBy) on models
 * that carry a `deletedAt` timestamp: WorkoutPlan, DietPlan, DailyProgress.
 *
 * Uses the stable `$extends` API (Prisma 4.7+) instead of the deprecated
 * `$use` middleware, so it works correctly on Prisma 4 and Prisma 5.
 *
 * Callers that explicitly pass `deletedAt: { not: null }` (e.g. admin recovery views)
 * will have their value preserved — the injected filter only fills the gap
 * when `deletedAt` is absent from the query args.
 */

const SOFT_DELETE_MODELS = new Set(['WorkoutPlan', 'DietPlan', 'DailyProgress', 'User', 'Gym', 'GymMembership']);
const READ_OPERATIONS    = new Set(['findFirst', 'findMany', 'findUnique', 'findUniqueOrThrow', 'findFirstOrThrow', 'count', 'aggregate', 'groupBy']);

const base = new PrismaClient();

const prisma = base.$extends({
  query: {
    $allModels: {
      async $allOperations({ model, operation, args, query }: any) {
        if (model && SOFT_DELETE_MODELS.has(model) && READ_OPERATIONS.has(operation)) {
          const typedArgs = args as any;
          if (typedArgs.where?.deletedAt === undefined) {
            typedArgs.where = { ...(typedArgs.where ?? {}), deletedAt: null };
          }
        }
        return query(args);
      },
    },
  },
}) as any;

export { Prisma };
export default prisma;
