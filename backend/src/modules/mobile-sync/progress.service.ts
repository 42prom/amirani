import prisma from '../../lib/prisma';
import { getDayOfWeekEnum } from './mobile.controller';

export class ProgressService {
  /**
   * Calculates the total number of tasks (meals + exercises) for a specific user and date.
   * This mirrors the 28-day projection logic used in MobileController to ensure consistency.
   */
  static async calculateTasksTotal(userId: string, date: Date): Promise<number> {
    const targetDate = new Date(date);
    targetDate.setUTCHours(0, 0, 0, 0);
    const dateString = targetDate.toISOString().split('T')[0];
    const currentDayEnum = getDayOfWeekEnum(targetDate);

    // 1. Calculate Workout Tasks
    let workoutTasks = 0;
    const activeWorkoutPlan = await prisma.workoutPlan.findFirst({
      where: { userId, isActive: true },
      include: {
        routines: {
          where: { isDraft: false, scheduledDate: targetDate },
        },
        masterTemplate: {
          include: {
            routines: {
              include: { exercises: true }
            }
          }
        }
      }
    });

    if (activeWorkoutPlan) {
      // Priority 1: Literal calendar override
      const literal = activeWorkoutPlan.routines.find(r => 
        r.scheduledDate && r.scheduledDate.toISOString().split('T')[0] === dateString
      );

      if (literal) {
        workoutTasks = (literal as any).exercises?.length || 0;
      } else if (activeWorkoutPlan.masterTemplate) {
        // Priority 2: Template Projection
        const templateRoutines = (activeWorkoutPlan.masterTemplate as any).routines || [];
        const hasExplicitDayOfWeek = templateRoutines.some((r: any) => r.dayOfWeek != null);

        let mr: any = null;
        if (hasExplicitDayOfWeek) {
          mr = templateRoutines.find((r: any) => r.dayOfWeek === currentDayEnum);
        } else {
          // Index-based circular mapping
          const planStart = new Date(activeWorkoutPlan.startDate || activeWorkoutPlan.createdAt);
          planStart.setUTCHours(0, 0, 0, 0);
          const diffDays = Math.round((targetDate.getTime() - planStart.getTime()) / (1000 * 60 * 60 * 24));
          const availableIndices = (Array.from(new Set(templateRoutines.map((r: any) => r.orderIndex as number))) as number[]).sort((a, b) => a - b);
          
          if (availableIndices.length > 0) {
            const loopIndex = ((diffDays % availableIndices.length) + availableIndices.length) % availableIndices.length;
            const targetIndex = availableIndices[loopIndex];
            mr = templateRoutines.find((r: any) => r.orderIndex === targetIndex);
          }
        }
        
        if (mr && !mr.isRestDay) {
          workoutTasks = mr.exercises?.length || 0;
        }
      }
    }

    // 2. Calculate Diet Tasks
    let dietTasks = 0;
    const activeDietPlan = await prisma.dietPlan.findFirst({
      where: { userId, isActive: true } as any,
      include: {
        meals: { where: { isDraft: false, scheduledDate: targetDate } as any },
        masterTemplate: { include: { meals: true } }
      }
    });

    if (activeDietPlan) {
      // Priority 1: Literal calendar override
      const overrides = (activeDietPlan as any).meals || [];
      if (overrides.length > 0) {
        dietTasks = overrides.length;
      } else if (activeDietPlan.masterTemplate) {
        // Priority 2: Template Projection
        const masterMeals = (activeDietPlan.masterTemplate as any).meals || [];
        const hasDayOfWeekMeals = masterMeals.some((mm: any) => mm.dayOfWeek != null);

        if (hasDayOfWeekMeals) {
          dietTasks = masterMeals.filter((mm: any) => mm.dayOfWeek === currentDayEnum).length;
        } else {
          const sortedMeals = [...masterMeals].sort((a: any, b: any) => (a.orderIndex ?? 0) - (b.orderIndex ?? 0));
          const mealsPerDay = sortedMeals.filter((mm: any) => (mm.orderIndex ?? 0) === 0).length || 1;
          const dayCount = Math.ceil(sortedMeals.length / mealsPerDay);
          
          if (dayCount > 0) {
            const planStart = new Date(activeDietPlan.startDate || activeDietPlan.createdAt);
            planStart.setUTCHours(0, 0, 0, 0);
            const diffDays = Math.round((targetDate.getTime() - planStart.getTime()) / (1000 * 60 * 60 * 24));
            const loopIndex = ((diffDays % dayCount) + dayCount) % dayCount;
            
            dietTasks = sortedMeals.slice(loopIndex * mealsPerDay, (loopIndex + 1) * mealsPerDay).length;
          }
        }
      }
    }

    return workoutTasks + dietTasks;
  }

  /**
   * Initializes or updates the tasksTotal for a user's today progress.
   */
  static async initializeTodayProgress(userId: string) {
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);
    
    const tasksTotal = await this.calculateTasksTotal(userId, today);
    
    await prisma.dailyProgress.upsert({
      where: { userId_date: { userId, date: today } },
      update: { tasksTotal },
      create: { 
        userId, 
        date: today, 
        tasksTotal,
        tasksCompleted: 0,
        score: 0
      }
    });
  }
}
