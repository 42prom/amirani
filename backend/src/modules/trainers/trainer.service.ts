import prisma from '../../lib/prisma';
import { Role, DifficultyLevel, NotificationType } from '@prisma/client';
import { NotificationService } from '../notifications/notification.service';
import { WorkoutProcessorService } from '../workouts/workout-processor.service';
import { DietProcessorService } from '../diets/diet-processor.service';

const workoutProcessor = new WorkoutProcessorService(prisma);
const dietProcessor = new DietProcessorService(prisma);

// ─── Custom Errors ───────────────────────────────────────────────────────────

export class TrainerNotFoundError extends Error {
  constructor(public resource: string = 'Trainer') {
    super(`${resource} not found`);
    this.name = 'TrainerNotFoundError';
  }
}

export class TrainerAccessDeniedError extends Error {
  constructor(message = 'Access denied') {
    super(message);
    this.name = 'TrainerAccessDeniedError';
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** Resolve trainer profile by userId, throw if not found */
async function resolveProfile(userId: string) {
  const profile = await prisma.trainerProfile.findUnique({ where: { userId } });
  if (!profile) throw new TrainerNotFoundError('Trainer profile');
  return profile;
}

/** Verify a member is assigned to this trainer */
async function verifyMemberAssigned(trainerId: string, memberId: string) {
  const membership = await prisma.gymMembership.findFirst({
    where: { userId: memberId, trainerId },
  });
  if (!membership) throw new TrainerAccessDeniedError('Member is not assigned to you');
  return membership;
}

// ─── Service ─────────────────────────────────────────────────────────────────

export class TrainerService {
  /** Notify a member that their active plan has been structurally updated (silent refresh) */
  private static async notifyMemberOfChange(memberId: string, planType: 'workout' | 'diet') {
    // Only notify if the change happened to an ACTIVE plan.
    // We check this inside the calling methods to avoid redundant DB hits here.
    return NotificationService.send({
      userId: memberId,
      type: NotificationType.SYSTEM,
      title: 'Plan Updated',
      body: `Coach updated your ${planType} plan.`,
      channels: ['PUSH'], 
      data: {
        type: 'SYNC_DOWN',
        planType,
        path: planType === 'workout' ? '/workout' : '/diet',
      },
    }).catch(() => {});
  }

  // ── Profile & Members ──────────────────────────────────────────────────────

  static async getMyProfile(userId: string) {
    const profile = await prisma.trainerProfile.findUnique({
      where: { userId },
      select: {
        id: true,
        fullName: true,
        avatarUrl: true,
        age: true,
        specialization: true,
        bio: true,
        certifications: true,
        isAvailable: true,
        gymId: true,
        gym: { select: { id: true, name: true, city: true, logoUrl: true } },
        _count: { select: { assignedMembers: true } },
      },
    });
    if (!profile) throw new TrainerNotFoundError('Trainer profile');
    return profile;
  }

  static async getAssignedMembers(userId: string) {
    const profile = await resolveProfile(userId);

    const memberships = await prisma.gymMembership.findMany({
      where: { trainerId: profile.id },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            fullName: true,
            avatarUrl: true,
            weight: true,
            targetWeightKg: true,
            height: true,
            heightCm: true,
            dob: true,
            gender: true,
            medicalConditions: true,
            noMedicalConditions: true,
            unitPreference: true,
            languagePreference: true,
          },
        },
        plan: { select: { id: true, name: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return memberships;
  }

  static async getMemberStats(trainerId: string, memberId: string) {
    const profile = await resolveProfile(trainerId);
    await verifyMemberAssigned(profile.id, memberId);

    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const [totalAttendance, recentAttendance, avgDuration, memberInfo] =
      await Promise.all([
        prisma.attendance.count({ where: { userId: memberId, gymId: profile.gymId } }),
        prisma.attendance.findMany({
          where: { userId: memberId, gymId: profile.gymId, checkIn: { gte: thirtyDaysAgo } },
          orderBy: { checkIn: 'desc' },
          take: 10,
        }),
        prisma.attendance.aggregate({
          where: { userId: memberId, gymId: profile.gymId, duration: { not: null } },
          _avg: { duration: true },
        }),
        prisma.user.findUnique({
          where: { id: memberId },
          select: {
            id: true, fullName: true, email: true,
            avatarUrl: true, createdAt: true, weight: true, height: true, heightCm: true,
            targetWeightKg: true, unitPreference: true, languagePreference: true,
            dob: true, gender: true, medicalConditions: true,
            noMedicalConditions: true,
          },
        }),
      ]);

    const attendedDays = new Set(
      recentAttendance.map((a) => a.checkIn.toISOString().split('T')[0])
    ).size;

    // BMI = weight(kg) / height(m)^2 — requires both fields in SI units
    let bmi: number | null = null;
    if (memberInfo) {
      const weightKg  = memberInfo.weight ? parseFloat(String(memberInfo.weight)) : null;
      const heightM   = memberInfo.heightCm ? memberInfo.heightCm / 100 : null;
      if (weightKg && heightM && heightM > 0) {
        bmi = Math.round((weightKg / (heightM * heightM)) * 10) / 10;
      }
    }

    return {
      member: memberInfo,
      stats: {
        totalVisits: totalAttendance,
        last30DaysVisits: recentAttendance.length,
        attendanceRate: Math.round((attendedDays / 30) * 100),
        avgSessionMinutes: Math.round(avgDuration._avg.duration || 0),
        bmi,
      },
      recentAttendance: recentAttendance.map((a) => ({
        date: a.checkIn,
        duration: a.duration,
      })),
    };
  }

  static async getDashboardStats(userId: string) {
    const profile = await resolveProfile(userId);

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const [totalMembers, activeMembers, memberIds] = await Promise.all([
      prisma.gymMembership.count({ where: { trainerId: profile.id } }),
      prisma.gymMembership.count({ where: { trainerId: profile.id, status: 'ACTIVE' } }),
      prisma.gymMembership.findMany({
        where: { trainerId: profile.id },
        select: { userId: true },
      }),
    ]);

    const memberUserIds = memberIds.map((m) => m.userId);

    const todayCheckIns = await prisma.attendance.count({
      where: { userId: { in: memberUserIds }, gymId: profile.gymId, checkIn: { gte: today } },
    });

    const inactiveMembers = await Promise.all(
      memberUserIds.map(async (memberId) => {
        const lastVisit = await prisma.attendance.findFirst({
          where: { userId: memberId, gymId: profile.gymId },
          orderBy: { checkIn: 'desc' },
        });
        if (!lastVisit || lastVisit.checkIn < sevenDaysAgo) {
          const user = await prisma.user.findUnique({
            where: { id: memberId },
            select: { id: true, fullName: true },
          });
          return { ...user, lastVisit: lastVisit?.checkIn || null };
        }
        return null;
      })
    );

    return {
      totalMembers,
      activeMembers,
      todayCheckIns,
      inactiveMembers: inactiveMembers.filter(Boolean),
      gym: { id: profile.gymId },
    };
  }

  static async updateAvailability(userId: string, isAvailable: boolean) {
    const profile = await resolveProfile(userId);
    return prisma.trainerProfile.update({ where: { id: profile.id }, data: { isAvailable } });
  }

  static async getMembersAttendance(userId: string, options?: { startDate?: Date; endDate?: Date }) {
    const profile = await resolveProfile(userId);

    const memberships = await prisma.gymMembership.findMany({
      where: { trainerId: profile.id },
      select: { userId: true },
    });

    const memberIds = memberships.map((m) => m.userId);
    const where: any = { userId: { in: memberIds }, gymId: profile.gymId };

    if (options?.startDate || options?.endDate) {
      where.checkIn = {};
      if (options.startDate) where.checkIn.gte = options.startDate;
      if (options.endDate) where.checkIn.lte = options.endDate;
    }

    return prisma.attendance.findMany({
      where,
      include: { user: { select: { id: true, fullName: true, avatarUrl: true } } },
      orderBy: { checkIn: 'desc' },
      take: 100,
    });
  }

  // ── Workout Plan Management ────────────────────────────────────────────────

  static async createWorkoutPlan(
    userId: string,
    memberId: string,
    data: {
      name: string;
      description?: string;
      difficulty?: DifficultyLevel;
      startDate?: Date;
      endDate?: Date;
      numWeeks?: number;
    }
  ) {
    const profile = await resolveProfile(userId);
    await verifyMemberAssigned(profile.id, memberId);

    // Creates the underlying "Docker Image"
    const masterTemplate = await prisma.masterWorkoutTemplate.create({
      data: {
        name: data.name,
        description: data.description,
        difficulty: data.difficulty ?? DifficultyLevel.BEGINNER,
        isAIGenerated: false,
        creatorId: profile.id,
      }
    });

    // Creates the Instance pointer
    return prisma.workoutPlan.create({
      data: {
        name: data.name,
        description: data.description,
        difficulty: data.difficulty ?? DifficultyLevel.BEGINNER,
        isAIGenerated: false,
        isActive: false,
        startDate: data.startDate,
        endDate: data.endDate,
        numWeeks: data.numWeeks ?? 4,
        userId: memberId,
        trainerId: profile.id,
        masterTemplateId: masterTemplate.id,
      },
      include: {
        masterTemplate: { include: { routines: { include: { exercises: true } } } },
      },
    });
  }

  /** Get all trainer-created workout plans for a member */
  static async getMemberWorkoutPlans(userId: string, memberId: string) {
    const profile = await resolveProfile(userId);
    await verifyMemberAssigned(profile.id, memberId);

    const plans = await prisma.workoutPlan.findMany({
      where: { userId: memberId, trainerId: profile.id },
      include: {
        routines: { 
          include: { exercises: { orderBy: { orderIndex: 'asc' } } },
          orderBy: { scheduledDate: 'asc' }
        },
        masterTemplate: {
          include: {
            routines: {
              include: { exercises: { orderBy: { orderIndex: 'asc' } } },
              orderBy: { orderIndex: 'asc' },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    
    // Polyfill for frontend: merging template routines and literal routines
    return plans.map((p: any) => ({
       ...p,
       routines: [
         ...(p.masterTemplate?.routines || []),
         ...(p.routines || [])
       ]
    }));
  }

  /** Update workout plan metadata */
  static async updateWorkoutPlan(
    userId: string,
    planId: string,
    data: { name?: string; description?: string; difficulty?: DifficultyLevel; isActive?: boolean; startDate?: Date; numWeeks?: number; }
  ) {
    const profile = await resolveProfile(userId);

    const plan = await prisma.workoutPlan.findFirst({
      where: { id: planId, trainerId: profile.id },
    });
    if (!plan) throw new TrainerNotFoundError('Workout plan');

    if (data.isActive) {
      // DEACTIVATE any other trainer plans for this member (Soft-deactivation)
      const oldTrainerPlans = await prisma.workoutPlan.findMany({
        where: { userId: plan.userId, trainerId: profile.id, id: { not: planId }, isActive: true },
        select: { id: true }
      });
      if (oldTrainerPlans.length > 0) {
        await prisma.workoutPlan.updateMany({
          where: { id: { in: oldTrainerPlans.map((p: any) => p.id) } },
          data: { isActive: false }
        });
      }

      // Check whether member already had an AI-generated active plan (conflict)
      const aiConflict = await prisma.workoutPlan.findFirst({
        where: { userId: plan.userId, isAIGenerated: true, isActive: true },
        select: { id: true },
      });

      // Notify member of the newly activated plan
      NotificationService.send({
        userId: plan.userId,
        type: NotificationType.SYSTEM,
        title: 'New Workout Journey Begins! 💪',
        body: aiConflict
          ? `Coach ${profile.fullName} activated "${data.name ?? plan.name}". Your AI plan has been replaced.`
          : `Coach ${profile.fullName} activated "${data.name ?? plan.name}". Open the app to start training! ✨`,
        channels: ['PUSH', 'IN_APP'],
        data: {
          type: 'PLAN_ASSIGNED',
          planType: 'workout',
          planId,
          hadAIConflict: String(!!aiConflict),
          path: '/workout',
        },
      }).catch(() => { /* non-blocking */ });
    } else if (data.isActive === false) {
      NotificationService.send({
        userId: plan.userId,
        type: NotificationType.SYSTEM,
        title: 'Workout Plan Paused ⏸️',
        body: `Your plan "${plan.name}" has been deactivated by your coach.`,
        channels: ['PUSH', 'IN_APP'],
        data: { path: '/workout' }
      }).catch(() => {});
    } else if (plan.isActive && (data.name || data.description || data.numWeeks)) {
      NotificationService.send({
        userId: plan.userId,
        type: NotificationType.SYSTEM,
        title: 'Workout Plan Updated 📝',
        body: `Coach ${profile.fullName} updated your active plan details: ${data.name ?? plan.name}`,
        channels: ['PUSH', 'IN_APP'],
        data: { path: '/workout' }
      }).catch(() => {});
    }

    const updated = await prisma.workoutPlan.update({
      where: { id: planId },
      data,
      include: {
        masterTemplate: { include: { routines: { include: { exercises: true } } } },
        routines: { include: { exercises: true } },
      },
    });
    
    if (updated.masterTemplate && data.name) {
       await prisma.masterWorkoutTemplate.update({
          where: { id: updated.masterTemplateId ?? '' },
          data: { 
             name: data.name, 
             description: data.description, 
             difficulty: data.difficulty ?? updated.difficulty 
          }
       });
    }

    if (updated.isActive) {
       await TrainerService.notifyMemberOfChange(updated.userId, 'workout');
    }

    return { ...updated, routines: [
      ...(updated.masterTemplate?.routines || []),
      ...(updated.routines || [])
    ] };
  }

  /** Delete a workout plan (and all its routines/exercises via cascade) */
  static async deleteWorkoutPlan(userId: string, planId: string) {
    const profile = await resolveProfile(userId);

    const plan = await prisma.workoutPlan.findUnique({
      where: { id: planId },
      include: { masterTemplate: true }
    });
    if (!plan || plan.trainerId !== profile.id) throw new TrainerNotFoundError('Workout plan');

    if (plan.isActive) {
       await TrainerService.notifyMemberOfChange(plan.userId, 'workout');
    }

    await prisma.workoutPlan.delete({ where: { id: planId } });
    if (plan.masterTemplateId) {
       await prisma.masterWorkoutTemplate.delete({ where: { id: plan.masterTemplateId } }).catch(() => {});
    }
  }

  // ── Routine Management ─────────────────────────────────────────────────────

  /** Add a workout day/routine to an existing plan */
  static async addRoutine(
    userId: string,
    planId: string,
    data: {
      name: string;
      scheduledDate?: string | Date;
      estimatedMinutes?: number;
      orderIndex?: number;
      isDraft?: boolean;
    }
  ) {
    const profile = await resolveProfile(userId);

    const plan = await prisma.workoutPlan.findFirst({
      where: { id: planId, trainerId: profile.id },
      include: { masterTemplate: true }
    });
    if (!plan) throw new TrainerNotFoundError('Workout plan');

    let routine;

    if (data.scheduledDate) {
      // Create literal instance for specific calendar date
      routine = await prisma.workoutRoutine.create({
        data: {
          planId,
          name: data.name,
          scheduledDate: new Date(data.scheduledDate),
          estimatedMinutes: data.estimatedMinutes ?? 45,
          orderIndex: data.orderIndex ?? 0,
          isDraft: data.isDraft ?? false,
        },
        include: { exercises: { orderBy: { orderIndex: 'asc' } } },
      });
    } else {
      // Create master template routine
      if (!plan.masterTemplateId) throw new TrainerNotFoundError('Master Template missing on plan');
      const count = await prisma.masterWorkoutRoutine.count({ where: { templateId: plan.masterTemplateId } });
      routine = await prisma.masterWorkoutRoutine.create({
        data: {
          name: data.name,
          estimatedMinutes: data.estimatedMinutes ?? 45,
          orderIndex: data.orderIndex ?? count,
          templateId: plan.masterTemplateId,
        },
        include: { exercises: { orderBy: { orderIndex: 'asc' } } },
      });
    }

    if (plan.isActive) {
      await TrainerService.notifyMemberOfChange(plan.userId, 'workout');
    }

    return routine;
  }

  /** Update a routine */
  static async updateRoutine(
    userId: string,
    routineId: string,
    data: { name?: string; estimatedMinutes?: number; isDraft?: boolean; }
  ) {
    const profile = await resolveProfile(userId);

    // Try literal routine first
    const literalRoutine = await prisma.workoutRoutine.findFirst({
      where: { id: routineId, plan: { trainerId: profile.id } },
    });

    let updated;
    if (literalRoutine) {
      updated = await prisma.workoutRoutine.update({
        where: { id: routineId },
        data,
        include: { exercises: { orderBy: { orderIndex: 'asc' } }, plan: true },
      });
      if (updated.plan?.isActive) await TrainerService.notifyMemberOfChange(updated.plan.userId, 'workout');
    } else {
      // Search in master routines
      const masterRoutine = await prisma.masterWorkoutRoutine.findFirst({
        where: { id: routineId, template: { creatorId: profile.id } },
      });
      if (!masterRoutine) throw new TrainerNotFoundError('Routine');

      updated = await prisma.masterWorkoutRoutine.update({
        where: { id: routineId },
        data,
        include: { exercises: { orderBy: { orderIndex: 'asc' } } },
      });
      const plan = await prisma.workoutPlan.findFirst({ where: { masterTemplateId: updated.templateId, isActive: true } });
      if (plan) await TrainerService.notifyMemberOfChange(plan.userId, 'workout');
    }

    return updated;
  }

  /** Delete a routine */
  static async deleteRoutine(userId: string, routineId: string) {
    const profile = await resolveProfile(userId);

    const literalRoutine = await prisma.workoutRoutine.findFirst({
      where: { id: routineId, plan: { trainerId: profile.id } },
    });

    if (literalRoutine) {
      await prisma.workoutRoutine.delete({ where: { id: routineId } });
    } else {
      const masterRoutine = await prisma.masterWorkoutRoutine.findFirst({
        where: { id: routineId, template: { creatorId: profile.id } },
      });
      if (!masterRoutine) throw new TrainerNotFoundError('Routine');
      await prisma.masterWorkoutRoutine.delete({ where: { id: routineId } });
    }
  }

  // ── Exercise Management ────────────────────────────────────────────────────

  /** Add exercises to a routine */
  static async addExercises(
    userId: string,
    routineId: string,
    exercises: Array<{
      exerciseName: string;
      exerciseLibraryId?: string;
      targetSets?: number;
      targetReps?: number;
      targetWeight?: number;
      restSeconds?: number;
      rpe?: number;
      progressionNote?: string;
    }>
  ) {
    const profile = await resolveProfile(userId);

    // Try finding in WorkoutRoutine (literal) first
    const literalRoutine = await prisma.workoutRoutine.findFirst({
      where: { id: routineId, plan: { trainerId: profile.id } },
      include: { exercises: { orderBy: { orderIndex: 'desc' }, take: 1 } },
    });

    let created;
    if (literalRoutine) {
      const startIndex = (literalRoutine.exercises[0]?.orderIndex ?? -1) + 1;
      created = await prisma.$transaction(
        exercises.map((ex, i) => prisma.exerciseSet.create({
          data: {
            ...ex,
            orderIndex: startIndex + i,
            routineId
          }
        }))
      );
      if (literalRoutine.planId) {
        const p = await prisma.workoutPlan.findUnique({ where: { id: literalRoutine.planId } });
        if (p?.isActive) await TrainerService.notifyMemberOfChange(p.userId, 'workout');
      }
    } else {
      // Manage master routine
      const masterRoutine = await prisma.masterWorkoutRoutine.findFirst({
        where: { id: routineId, template: { creatorId: profile.id } },
        include: { exercises: { orderBy: { orderIndex: 'desc' }, take: 1 } },
      });
      if (!masterRoutine) throw new TrainerNotFoundError('Routine');

      const startIndex = (masterRoutine.exercises[0]?.orderIndex ?? -1) + 1;
      created = await prisma.$transaction(
        exercises.map((ex, i) => prisma.masterExerciseSet.create({
          data: {
            ...ex,
            orderIndex: startIndex + i,
            routineId
          }
        }))
      );
      
      const plan = await prisma.workoutPlan.findFirst({
        where: { masterTemplateId: masterRoutine.templateId, isActive: true }
      });
      if (plan) await TrainerService.notifyMemberOfChange(plan.userId, 'workout');

      // Update routine estimated duration
      const allEx = await prisma.masterExerciseSet.findMany({ where: { routineId } });
      const estMin = workoutProcessor.estimateRoutineDuration(allEx as any);
      await prisma.masterWorkoutRoutine.update({ 
        where: { id: routineId }, 
        data: { estimatedMinutes: estMin } 
      });
    }

    return created;
  }

  /** Update a single exercise */
  static async updateExercise(
    userId: string,
    exerciseId: string,
    data: {
      exerciseName?: string;
      exerciseLibraryId?: string;
      targetSets?: number;
      targetReps?: number;
      targetWeight?: number;
      restSeconds?: number;
      rpe?: number;
      progressionNote?: string;
      orderIndex?: number;
    }
  ) {
    const profile = await resolveProfile(userId);

    // Try literal exercise first
    const literalEx = await prisma.exerciseSet.findFirst({
      where: { id: exerciseId, routine: { plan: { trainerId: profile.id } } },
    });

    let updated;
    if (literalEx) {
      updated = await prisma.exerciseSet.update({ where: { id: exerciseId }, data });
      const r = await prisma.workoutRoutine.findUnique({ where: { id: updated.routineId }, include: { plan: true } });
      if (r?.plan?.isActive) await TrainerService.notifyMemberOfChange(r.plan.userId, 'workout');
    } else {
      const masterEx = await prisma.masterExerciseSet.findFirst({
        where: { id: exerciseId, routine: { template: { creatorId: profile.id } } },
        include: { routine: true }
      });
      if (!masterEx) throw new TrainerNotFoundError('Exercise');

      updated = await prisma.masterExerciseSet.update({ where: { id: exerciseId }, data });
      const plan = await prisma.workoutPlan.findFirst({ where: { masterTemplateId: masterEx.routine.templateId, isActive: true } });
      if (plan) await TrainerService.notifyMemberOfChange(plan.userId, 'workout');
      
      // Update duration
      const allEx = await prisma.masterExerciseSet.findMany({ where: { routineId: updated.routineId } });
      const estMin = workoutProcessor.estimateRoutineDuration(allEx as any);
      await prisma.masterWorkoutRoutine.update({ where: { id: updated.routineId }, data: { estimatedMinutes: estMin } });
    }

    return updated;
  }

  /** Delete a single exercise */
  static async deleteExercise(userId: string, exerciseId: string) {
    const profile = await resolveProfile(userId);

    // Try literal first
    const literalEx = await prisma.exerciseSet.findFirst({
      where: { id: exerciseId, routine: { plan: { trainerId: profile.id } } },
    });

    if (literalEx) {
      const r = await prisma.workoutRoutine.findUnique({ where: { id: literalEx.routineId }, include: { plan: true } });
      await prisma.exerciseSet.delete({ where: { id: exerciseId } });
      if (r?.plan?.isActive) await TrainerService.notifyMemberOfChange(r.plan.userId, 'workout');
    } else {
      const masterEx = await prisma.masterExerciseSet.findFirst({
        where: { id: exerciseId, routine: { template: { creatorId: profile.id } } },
        include: { routine: true }
      });
      if (!masterEx) throw new TrainerNotFoundError('Exercise');
      const plan = await prisma.workoutPlan.findFirst({ where: { masterTemplateId: masterEx.routine.templateId, isActive: true } });
      if (plan) await TrainerService.notifyMemberOfChange(plan.userId, 'workout');
      await prisma.masterExerciseSet.delete({ where: { id: exerciseId } });
    }
  }

  // ── Exercise Library Search ────────────────────────────────────────────────

  /** Search the global exercise library for use in plan builder */
  static async searchExerciseLibrary(query: string, limit = 20, lang: 'EN' | 'KA' | 'RU' = 'EN') {
    const rows = await prisma.exerciseLibrary.findMany({
      where: {
        OR: [
          { name:   { contains: query, mode: 'insensitive' } },
          { nameKa: { contains: query, mode: 'insensitive' } },
          { nameRu: { contains: query, mode: 'insensitive' } },
        ],
      },
      select: { id: true, name: true, nameKa: true, nameRu: true, primaryMuscle: true, secondaryMuscles: true, difficulty: true },
      take: limit,
      orderBy: { name: 'asc' },
    });

    return rows.map(r => ({
      id:             r.id,
      name:           (lang === 'KA' && r.nameKa) ? r.nameKa
                    : (lang === 'RU' && r.nameRu) ? r.nameRu
                    : r.name,
      nameEn:         r.name,
      primaryMuscle:  r.primaryMuscle,
      secondaryMuscles: r.secondaryMuscles,
      difficulty:     r.difficulty,
    }));
  }

  // ── Diet Plan Management ───────────────────────────────────────────────────

  static async createDietPlan(
    userId: string,
    memberId: string,
    data: {
      name: string;
      targetCalories: number;
      targetProtein: number;
      targetCarbs: number;
      targetFats: number;
      targetWater?: number;
      startDate?: Date;
      numWeeks?: number;
    }
  ) {
    const profile = await resolveProfile(userId);
    await verifyMemberAssigned(profile.id, memberId);

    // Creates the underlying "Docker Image"
    const masterTemplate = await prisma.masterDietTemplate.create({
      data: {
        name: data.name,
        targetCalories: data.targetCalories,
        targetProtein: data.targetProtein,
        targetCarbs: data.targetCarbs,
        targetFats: data.targetFats,
        targetWater: data.targetWater ?? 3.0,
        isAIGenerated: false,
        creatorId: profile.id,
      }
    });

    // Plans are created inactive — trainer explicitly activates via activateDietPlan
    return prisma.dietPlan.create({
      data: {
        name: data.name,
        isAIGenerated: false,
        isActive: false,
        targetCalories: data.targetCalories,
        targetProtein: data.targetProtein,
        targetCarbs: data.targetCarbs,
        targetFats: data.targetFats,
        targetWater: data.targetWater ?? 3.0,
        startDate: data.startDate ?? null,
        numWeeks: data.numWeeks ?? 4,
        userId: memberId,
        trainerId: profile.id,
        masterTemplateId: masterTemplate.id,
      },
      include: {
        masterTemplate: { include: { meals: { orderBy: { orderIndex: 'asc' } } } },
      },
    });
  }

  /** Activate a diet plan — deactivates all other trainer plans for that member */
  static async activateDietPlan(userId: string, planId: string) {
    const profile = await resolveProfile(userId);

    const plan = await prisma.dietPlan.findFirst({
      where: { id: planId, trainerId: profile.id },
    });
    if (!plan) throw new TrainerNotFoundError('Diet plan');

    // DEACTIVATE all other trainer plans (Soft-deactivation)
    const oldTrainerDietPlans = await prisma.dietPlan.findMany({
      where: { userId: plan.userId, trainerId: profile.id, id: { not: planId }, isActive: true },
      select: { id: true }
    });
    if (oldTrainerDietPlans.length > 0) {
      await prisma.dietPlan.updateMany({
        where: { id: { in: oldTrainerDietPlans.map((p: any) => p.id) } },
        data: { isActive: false }
      });
    }

    // Check whether member already had an AI-generated active diet plan (conflict)
    const aiConflict = await prisma.dietPlan.findFirst({
      where: { userId: plan.userId, isAIGenerated: true, isActive: true },
      select: { id: true },
    });

    // Notify member
    NotificationService.send({
      userId: plan.userId,
      type: NotificationType.SYSTEM,
      title: 'New Nutrition Plan Assigned 🍏',
      body: aiConflict
        ? `Coach ${profile.fullName} activated a new diet plan. Your AI plan has been replaced.`
        : `Coach ${profile.fullName} activated a new diet plan. Let's start tracking! ✨`,
      channels: ['PUSH', 'IN_APP'],
      data: {
        type: 'PLAN_ASSIGNED',
        planType: 'diet',
        planId,
        hadAIConflict: String(!!aiConflict),
        path: '/diet',
      },
    }).catch(() => { /* non-blocking */ });

    return prisma.dietPlan.update({
      where: { id: planId },
      data: { isActive: true },
      include: { masterTemplate: { include: { meals: { orderBy: { orderIndex: 'asc' } } } } },
    });
  }

  /** Deactivate a diet plan */
  static async deactivateDietPlan(userId: string, planId: string) {
    const profile = await resolveProfile(userId);

    const plan = await prisma.dietPlan.findFirst({
      where: { id: planId, trainerId: profile.id },
    });
    if (!plan) throw new TrainerNotFoundError('Diet plan');

    return prisma.dietPlan.update({
      where: { id: planId },
      data: { isActive: false },
      include: { masterTemplate: { include: { meals: { orderBy: { orderIndex: 'asc' } } } } },
    });
  }

  /** Get all trainer-created diet plans for a member */
  static async getMemberDietPlans(userId: string, memberId: string) {
    const profile = await resolveProfile(userId);
    await verifyMemberAssigned(profile.id, memberId);

    const plans = await prisma.dietPlan.findMany({
      where: { userId: memberId, trainerId: profile.id },
      include: { 
        meals: { orderBy: { scheduledDate: 'asc' }, include: { ingredients: true } },
        masterTemplate: { include: { meals: { orderBy: { orderIndex: 'asc' }, include: { ingredients: true } } } } 
      },
      orderBy: { createdAt: 'desc' },
    });
    
    return plans.map((p: any) => ({
       ...p,
       meals: [
         ...(p.masterTemplate?.meals || []).map((m: any) => ({
           id: m.id,
           name: m.name,
           timeOfDay: m.timeOfDay,
           scheduledDate: null,
           totalCalories: m.ingredients?.reduce((s: number, i: any) => s + i.calories, 0) || 0,
           protein: m.ingredients?.reduce((s: number, i: any) => s + Number(i.protein), 0) || 0,
           carbs: m.ingredients?.reduce((s: number, i: any) => s + Number(i.carbs), 0) || 0,
           fats: m.ingredients?.reduce((s: number, i: any) => s + Number(i.fats), 0) || 0,
           isDraft: false,
           instructions: m.instructions,
           mediaUrl: m.mediaUrl,
           ingredients: (m.ingredients || []).map((i: any) => ({
             name: i.name,
             amount: Number(i.amount),
             unit: i.unit,
             calories: i.calories,
             protein: Number(i.protein),
             carbs: Number(i.carbs),
             fats: Number(i.fats)
           }))
         })),
         ...(p.meals || []).map((m: any) => ({
           ...m,
           scheduledDate: m.scheduledDate ? m.scheduledDate.toISOString().split('T')[0] : null,
           ingredients: (m.ingredients || []).map((i: any) => ({
             name: i.name,
             amount: Number(i.amount),
             unit: i.unit,
             calories: i.calories,
             protein: Number(i.protein),
             carbs: Number(i.carbs),
             fats: Number(i.fats)
           }))
         }))
       ]
    }));
  }

  /** Update diet plan metadata */
  static async updateDietPlan(
    userId: string,
    planId: string,
    data: {
      name?: string;
      targetCalories?: number;
      targetProtein?: number;
      targetCarbs?: number;
      targetFats?: number;
      targetWater?: number;
      isActive?: boolean;
    }
  ) {
    const profile = await resolveProfile(userId);

    const plan = await prisma.dietPlan.findFirst({
      where: { id: planId, trainerId: profile.id },
    });
    if (!plan) throw new TrainerNotFoundError('Diet plan');

    const updated = await prisma.dietPlan.update({
      where: { id: planId },
      data,
      include: { masterTemplate: { include: { meals: { orderBy: { orderIndex: 'asc' }, include: { ingredients: true } } } } },
    });
    
    if (updated.masterTemplate) {
        if (data.name || data.targetCalories) {
           await prisma.masterDietTemplate.update({
              where: { id: updated.masterTemplateId ?? '' },
              data: { 
                 name: data.name, 
                 targetCalories: data.targetCalories,
                 targetProtein: data.targetProtein,
                 targetCarbs: data.targetCarbs,
                 targetFats: data.targetFats,
                 targetWater: data.targetWater
              }
           });
        }
    }

    if (data.isActive === false) {
       NotificationService.send({
        userId: plan.userId,
        type: NotificationType.SYSTEM,
        title: 'Diet Plan Paused ⏸️',
        body: `Your nutrition plan "${plan.name}" has been deactivated.`,
        channels: ['PUSH', 'IN_APP'],
        data: { path: '/diet' }
      }).catch(() => {});
    } else if (plan.isActive && (data.name || data.targetCalories)) {
       NotificationService.send({
        userId: plan.userId,
        type: NotificationType.SYSTEM,
        title: 'Diet Plan Updated 🍎',
        body: `Coach ${profile.fullName} updated your active diet plan: ${data.name ?? plan.name}`,
        channels: ['PUSH', 'IN_APP'],
        data: { path: '/diet' }
      }).catch(() => {});
    }

    return updated;
  }

  /** Delete a diet plan */
  static async deleteDietPlan(userId: string, planId: string) {
    const profile = await resolveProfile(userId);

    const plan = await prisma.dietPlan.findFirst({
      where: { id: planId, trainerId: profile.id },
    });
    if (!plan) throw new TrainerNotFoundError('Diet plan');

    await prisma.dietPlan.delete({ where: { id: planId } });
  }

  /** Publish a diet plan to the member */
  static async publishDietPlan(userId: string, planId: string) {
    const profile = await resolveProfile(userId);

    const plan = await prisma.dietPlan.findFirst({
      where: { id: planId, trainerId: profile.id },
    });
    if (!plan) throw new TrainerNotFoundError('Diet plan');

    if (plan.isPublished) return plan; // Already published

    const updated = await prisma.dietPlan.update({
      where: { id: planId },
      data: { isPublished: true },
    });

    NotificationService.send({
      userId: plan.userId,
      type: NotificationType.SYSTEM,
      title: 'New Diet Plan! 🥗',
      body: `Coach ${profile.fullName} just published your nutrition plan: ${plan.name}`,
      channels: ['PUSH', 'IN_APP'],
      data: { path: '/diet' }
    }).catch(() => {});

    return updated;
  }

  // ── Meal Management ────────────────────────────────────────────────────────

  /** Add a meal to a diet plan */
  static async addMeal(
    userId: string,
    planId: string,
    data: {
      name: string;
      timeOfDay?: string;
      scheduledDate?: Date;
      totalCalories: number;
      protein: number;
      carbs: number;
      fats: number;
      ingredients?: any;
      instructions?: string;
      mediaUrl?: string;
      isDraft?: boolean;
      notificationTime?: string;
      isReminderEnabled?: boolean;
    }
  ) {
    const profile = await resolveProfile(userId);

    const plan = await prisma.dietPlan.findFirst({
      where: { id: planId, trainerId: profile.id },
    });
    if (!plan) throw new TrainerNotFoundError('Diet plan');

    const ingredients = Array.isArray(data.ingredients) 
      ? data.ingredients 
      : [];

    const totals = dietProcessor.calculateMealTotals(ingredients);
    const mealData = {
      name: data.name,
      timeOfDay: data.timeOfDay,
      instructions: data.instructions ?? null,
      mediaUrl: data.mediaUrl,
      notificationTime: data.notificationTime,
      isReminderEnabled: data.isReminderEnabled ?? true,
    };

    let meal;
    if (data.scheduledDate) {
      // Create literal instance for specific calendar date
      meal = await prisma.meal.create({
        data: {
          ...mealData,
          planId: plan.id,
          scheduledDate: data.scheduledDate,
          totalCalories: totals.totalCalories,
          protein: totals.protein,
          carbs: totals.carbs,
          fats: totals.fats,
          ingredients: {
            create: ingredients.map((ing: any) => ({
              name: ing.name ?? 'Food Item',
              amount: ing.amount ?? 100,
              unit: ing.unit ?? 'g',
              calories: ing.calories ?? 0,
              protein: ing.protein ?? 0,
              carbs: ing.carbs ?? 0,
              fats: ing.fats ?? 0,
            }))
          }
        },
        include: { ingredients: true }
      });
    } else {
      // Create master template loop item
      const count = await prisma.masterMeal.count({ where: { templateId: plan.masterTemplateId ?? '' } });
      meal = await prisma.masterMeal.create({
        data: {
          ...mealData,
          templateId: plan.masterTemplateId ?? '',
          orderIndex: count,
          ingredients: {
            create: ingredients.map((ing: any) => ({
              name: ing.name ?? 'Food Item',
              amount: ing.amount ?? 100,
              unit: ing.unit ?? 'g',
              calories: ing.calories ?? 0,
              protein: ing.protein ?? 0,
              carbs: ing.carbs ?? 0,
              fats: ing.fats ?? 0,
            }))
          }
        },
        include: { ingredients: true }
      });
    }
    
    // Send back polyfilled totals for mobile app compatibility
    const mealWithTotals = {
       ...meal,
       totalCalories: totals.totalCalories,
       protein: totals.protein,
       carbs: totals.carbs,
       fats: totals.fats
    };

    if (plan.isActive) {
      await TrainerService.notifyMemberOfChange(plan.userId, 'diet');
    }

    return mealWithTotals;
  }

  /** Update a meal */
  static async updateMeal(
    userId: string,
    mealId: string,
    data: {
      name?: string;
      timeOfDay?: string;
      scheduledDate?: Date;
      totalCalories?: number;
      protein?: number;
      carbs?: number;
      fats?: number;
      ingredients?: any;
      instructions?: string;
      isDraft?: boolean;
    }
  ) {
    const profile = await resolveProfile(userId);

    // Try finding in MasterMeal first
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let meal: any = await prisma.masterMeal.findFirst({
      where: { id: mealId, template: { creatorId: profile.id } as any },
    });

    let isMaster = true;
    if (!meal) {
      meal = await prisma.meal.findFirst({
        where: { id: mealId, plan: { trainerId: profile.id } as any },
      });
      isMaster = false;
    }

    if (!meal) throw new TrainerNotFoundError('Meal');

    const ingredients = Array.isArray(data.ingredients) ? data.ingredients : undefined;

    const totals = ingredients ? dietProcessor.calculateMealTotals(ingredients) : null;

    let updated: any;
    if (isMaster) {
      // If items are being updated for MasterMeal, we must delete old items and insert new ones
      if (ingredients) {
        await prisma.masterMealIngredient.deleteMany({ where: { mealId } });
        await prisma.$transaction(
          ingredients.map((ing: any) => prisma.masterMealIngredient.create({
            data: {
              mealId,
              name: ing.name ?? 'Food Item',
              amount: ing.amount ?? 100,
              unit: ing.unit ?? 'g',
              calories: ing.calories ?? 0,
              protein: ing.protein ?? 0,
              carbs: ing.carbs ?? 0,
              fats: ing.fats ?? 0,
            }
          }))
        );
      }

      updated = await prisma.masterMeal.update({ 
        where: { id: mealId },
        data: {
           name: data.name,
           timeOfDay: data.timeOfDay,
           instructions: data.instructions,
           notificationTime: (data as any).notificationTime,
           isReminderEnabled: (data as any).isReminderEnabled
        },
        include: { ingredients: true }
      });
    } else {
      if (ingredients) {
        await prisma.mealIngredient.deleteMany({ where: { mealId } });
      }

      updated = await prisma.meal.update({
        where: { id: mealId },
        data: {
           name: data.name,
           timeOfDay: data.timeOfDay,
           instructions: data.instructions,
           scheduledDate: data.scheduledDate,
           totalCalories: totals!.totalCalories,
           protein: totals!.protein,
           carbs: totals!.carbs,
           fats: totals!.fats,
           ...(ingredients ? {
             ingredients: {
               create: ingredients.map((ing: any) => ({
                 name: ing.name ?? 'Food Item',
                 amount: ing.amount ?? 100,
                 unit: ing.unit ?? 'g',
                 calories: ing.calories ?? 0,
                 protein: ing.protein ?? 0,
                 carbs: ing.carbs ?? 0,
                 fats: ing.fats ?? 0,
               }))
             }
           } : {})
        },
        include: { ingredients: true }
      });
    }

    const plan = await prisma.dietPlan.findFirst({ 
      where: { 
        OR: [
          { masterTemplateId: updated.templateId },
          { id: (updated as any).planId }
        ],
        isActive: true 
      } 
    });
    if (plan?.isActive) {
      await TrainerService.notifyMemberOfChange(plan.userId, 'diet');
    }
    
    // Polyfill totals for consistency
    const finalTotals = totals ?? dietProcessor.calculateMealTotals(updated.ingredients || []);
    
    return {
       ...updated,
       totalCalories: finalTotals.totalCalories,
       protein: finalTotals.protein,
       carbs: finalTotals.carbs,
       fats: finalTotals.fats
    };
  }

  /** Delete a meal */
  static async deleteMeal(userId: string, mealId: string) {
    const profile = await resolveProfile(userId);

    // Try finding in MasterMeal
    let meal: any = await prisma.masterMeal.findFirst({
      where: { id: mealId, template: { creatorId: profile.id } as any },
    });

    let isMaster = true;
    if (!meal) {
      meal = await prisma.meal.findFirst({
        where: { id: mealId, plan: { trainerId: profile.id } as any },
      });
      isMaster = false;
    }

    if (!meal) throw new TrainerNotFoundError('Meal');

    const plan = await prisma.dietPlan.findFirst({ 
      where: { 
        OR: [
          { masterTemplateId: meal.templateId },
          { id: (meal as any).planId }
        ],
        isActive: true 
      } 
    });
    
    if (plan?.isActive) {
      await TrainerService.notifyMemberOfChange(plan.userId, 'diet');
    }

    if (isMaster) {
      await prisma.masterMeal.delete({ where: { id: mealId } });
    } else {
      await prisma.meal.delete({ where: { id: mealId } });
    }
  }

  // ── Draft Template Library ─────────────────────────────────────────────────

  static async getDraftTemplates(userId: string) {
    const profile = await resolveProfile(userId);
    return prisma.trainerDraftTemplate.findMany({
      where: { trainerId: profile.id },
      orderBy: { createdAt: 'desc' },
    });
  }

  static async createDraftTemplate(
    userId: string,
    type: 'meal' | 'day' | 'week',
    name: string,
    data: any,
  ) {
    const profile = await resolveProfile(userId);

    return prisma.trainerDraftTemplate.create({
      data: { trainerId: profile.id, type, name, data },
    });
  }

  static async updateDraftTemplate(
    userId: string,
    templateId: string,
    patch: { name?: string; data?: any },
  ) {
    const profile = await resolveProfile(userId);
    const tpl = await prisma.trainerDraftTemplate.findFirst({
      where: { id: templateId, trainerId: profile.id },
    });
    if (!tpl) throw new TrainerNotFoundError('Draft template');

    return prisma.trainerDraftTemplate.update({
      where: { id: templateId },
      data: patch,
    });
  }

  static async deleteDraftTemplate(userId: string, templateId: string) {
    const profile = await resolveProfile(userId);
    const tpl = await prisma.trainerDraftTemplate.findFirst({
      where: { id: templateId, trainerId: profile.id },
    });
    if (!tpl) throw new TrainerNotFoundError('Draft template');

    await prisma.trainerDraftTemplate.delete({ where: { id: templateId } });
  }

  // ── Training Sessions ──────────────────────────────────────────────────────

  /** List upcoming SCHEDULED sessions for a gym, newest first by startTime */
  static async listUpcomingSessions(gymId: string, limit = 20) {
    const now = new Date();
    return prisma.trainingSession.findMany({
      where: { gymId, status: 'SCHEDULED', startTime: { gte: now } },
      include: {
        trainer: { select: { id: true, fullName: true, avatarUrl: true } },
        _count: { select: { bookings: { where: { status: 'CONFIRMED' } } } },
      },
      orderBy: { startTime: 'asc' },
      take: limit,
    });
  }

  /** Get confirmed bookings for a user (upcoming only) */
  static async getMySessionBookings(userId: string) {
    const now = new Date();
    return prisma.sessionBooking.findMany({
      where: {
        userId,
        status: 'CONFIRMED',
        session: { startTime: { gte: now } },
      },
      include: {
        session: {
          include: {
            trainer: { select: { id: true, fullName: true, avatarUrl: true } },
          },
        },
      },
      orderBy: { session: { startTime: 'asc' } },
      take: 20,
    });
  }

  /** Book a session — upsert so a cancelled booking can be re-confirmed */
  static async bookSession(userId: string, sessionId: string) {
    const session = await prisma.trainingSession.findUnique({
      where: { id: sessionId },
      include: { _count: { select: { bookings: { where: { status: 'CONFIRMED' } } } } },
    });
    if (!session) throw new TrainerNotFoundError('Session');
    if (session.status !== 'SCHEDULED') throw new TrainerAccessDeniedError('Session is not available for booking');

    if (session.maxCapacity !== null && session._count.bookings >= session.maxCapacity) {
      throw new TrainerAccessDeniedError('Session is fully booked');
    }

    return prisma.sessionBooking.upsert({
      where: { sessionId_userId: { sessionId, userId } },
      create: { sessionId, userId, status: 'CONFIRMED' },
      update: { status: 'CONFIRMED', bookedAt: new Date() },
    });
  }

  /** Cancel a booking */
  static async cancelBooking(userId: string, sessionId: string) {
    const booking = await prisma.sessionBooking.findUnique({
      where: { sessionId_userId: { sessionId, userId } },
    });
    if (!booking) throw new TrainerNotFoundError('Booking');

    return prisma.sessionBooking.update({
      where: { sessionId_userId: { sessionId, userId } },
      data: { status: 'CANCELLED' },
    });
  }
}
