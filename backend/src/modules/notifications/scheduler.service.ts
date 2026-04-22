import prisma from '../../lib/prisma';
import { NotificationService } from './notification.service';
import { NotificationType } from '@prisma/client';
import logger from '../../lib/logger';

const DAY_ENUMS = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];

export class SchedulerService {
  private static interval: NodeJS.Timeout | null = null;
  private static isRunning = false;

  static start() {
    if (this.interval) return;
    logger.info('[Scheduler] Proactive Reminder Engine started');
    this.checkUpcomingTasks();
    this.interval = setInterval(() => {
      this.checkUpcomingTasks();
    }, 15 * 60 * 1000);
  }

  static stop() {
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
    }
  }

  private static async checkUpcomingTasks() {
    if (this.isRunning) return;
    this.isRunning = true;
    const now = new Date();
    try {
      await Promise.all([
        this.processMealReminders(now),
        this.processWorkoutReminders(now),
      ]);
    } catch (error) {
      logger.error('[Scheduler] Scan failed', { error });
    } finally {
      this.isRunning = false;
    }
  }

  // ── Meal reminders ───────────────────────────────────────────────────────────

  private static async processMealReminders(now: Date) {
    const activeDietPlans = await prisma.dietPlan.findMany({
      where: { isActive: true, deletedAt: null },
      include: {
        user: { include: { notificationPreference: true } },
        meals: { where: { isDraft: false } },
      },
    });

    for (const plan of activeDietPlans) {
      if (!plan.user.timezone) continue;
      const userLocalTime = this.getUserTime(now, plan.user.timezone);
      const [currentHour, currentMinute] = userLocalTime.split(':').map(Number);

      for (const meal of plan.meals) {
        if (!meal.timeOfDay) continue;
        const [mealHour, mealMinute] = meal.timeOfDay.split(':').map(Number);
        if (this.isMatchingTime(currentHour, currentMinute, mealHour, mealMinute, 15)) {
          await this.sendMealReminder(plan.user, meal);
        }
      }
    }
  }

  // ── Workout reminders ────────────────────────────────────────────────────────
  // Sent once per day in the 7–9am window (user local time) for any routine
  // whose dayOfWeek matches today. No timeOfDay on routines — morning reminder only.

  private static async processWorkoutReminders(now: Date) {
    const activeWorkoutPlans = await prisma.workoutPlan.findMany({
      where: { isActive: true, deletedAt: null },
      include: {
        user: { include: { notificationPreference: true } },
        routines: { where: { isDraft: false } },
      },
    });

    for (const plan of activeWorkoutPlans) {
      if (!plan.user.timezone) continue;
      const userLocalTime = this.getUserTime(now, plan.user.timezone);
      const [currentHour] = userLocalTime.split(':').map(Number);

      // Only send in the 7–9am window
      if (currentHour < 7 || currentHour >= 9) continue;

      const userDayEnum = this.getUserDayEnum(now, plan.user.timezone);

      for (const routine of plan.routines) {
        if (!routine.dayOfWeek || routine.dayOfWeek !== userDayEnum) continue;
        await this.sendWorkoutReminder(plan.user, routine);
      }
    }
  }

  private static async sendMealReminder(user: any, meal: any) {
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const existing = await prisma.notification.findFirst({
      where: {
        userId: user.id,
        type: NotificationType.MEAL_REMINDER,
        createdAt: { gte: startOfToday },
        data: { path: ['mealId'], equals: meal.id },
      } as any,
    });
    if (existing) return;

    await NotificationService.send({
      userId: user.id,
      type: NotificationType.MEAL_REMINDER,
      title: `${meal.name} Reminder`,
      body: `Time for your ${meal.name.toLowerCase()}! Stay on track with your nutrition plan.`,
      data: { mealId: meal.id, planId: meal.planId, path: '/diet' },
      channels: ['PUSH', 'IN_APP'],
    });
  }

  private static async sendWorkoutReminder(user: any, routine: any) {
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const existing = await prisma.notification.findFirst({
      where: {
        userId: user.id,
        type: NotificationType.WORKOUT_REMINDER,
        createdAt: { gte: startOfToday },
        data: { path: ['routineId'], equals: routine.id },
      } as any,
    });
    if (existing) return;

    await NotificationService.send({
      userId: user.id,
      type: NotificationType.WORKOUT_REMINDER,
      title: `Today's Workout: ${routine.name}`,
      body: `You have a ${routine.estimatedMinutes}-minute workout scheduled today. Time to crush it!`,
      data: { routineId: routine.id, planId: routine.planId, path: '/workout' },
      channels: ['PUSH', 'IN_APP'],
    });
  }

  private static getUserTime(date: Date, timezone: string): string {
    try {
      return new Intl.DateTimeFormat('en-GB', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false,
        timeZone: timezone,
      }).format(date);
    } catch {
      return '00:00';
    }
  }

  private static getUserDayEnum(date: Date, timezone: string): string {
    try {
      const dayName = new Intl.DateTimeFormat('en-US', { weekday: 'long', timeZone: timezone }).format(date);
      return dayName.toUpperCase();
    } catch {
      return DAY_ENUMS[date.getDay()];
    }
  }

  private static isMatchingTime(userH: number, userM: number, taskH: number, taskM: number, bufferM: number): boolean {
    const userTotal = userH * 60 + userM;
    const taskTotal = taskH * 60 + taskM;
    const diff = taskTotal - userTotal;
    return diff >= 0 && diff <= bufferM;
  }
}
