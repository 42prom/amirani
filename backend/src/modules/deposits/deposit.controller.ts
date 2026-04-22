import { Request, Response } from 'express';
import { DepositService } from './deposit.service';
import { Role, DepositStatus, DepositType } from '@prisma/client';

export class DepositController {
  static async submitDeposit(req: Request, res: Response) {
    try {
      const { gymId } = req.params;
      const { amount, type, reference, notes, currency } = req.body;
      // @ts-ignore
      const userId = req.user.id;
      // @ts-ignore
      const role = req.user.role as Role;
      // @ts-ignore
      const managedGymId = req.user.managedGymId;

      if (!gymId || !amount || !type) {
        return res.status(400).json({ error: 'gymId, amount, and type are required' });
      }

      if (!Object.values(DepositType).includes(type)) {
         return res.status(400).json({ error: 'Invalid deposit type' });
      }

      const deposit = await DepositService.submitDeposit(
        gymId,
        userId,
        role,
        { amount: Number(amount), type, reference, notes, currency },
        managedGymId
      );

      res.status(201).json(deposit);
    } catch (error: any) {
      if (error.message.includes('Access denied')) {
        return res.status(403).json({ error: error.message });
      }
      res.status(400).json({ error: error.message });
    }
  }

  static async getGymDeposits(req: Request, res: Response) {
    try {
      const { gymId } = req.params;
      // @ts-ignore
      const userId = req.user.id;
      // @ts-ignore
      const role = req.user.role as Role;
      // @ts-ignore
      const managedGymId = req.user.managedGymId;

      const deposits = await DepositService.getGymDeposits(gymId, userId, role, managedGymId);
      res.json(deposits);
    } catch (error: any) {
      if (error.message.includes('Access denied')) {
        return res.status(403).json({ error: error.message });
      }
      res.status(400).json({ error: error.message });
    }
  }

  static async getAllDeposits(req: Request, res: Response) {
    try {
      // @ts-ignore
      const userId = req.user.id;
      // @ts-ignore
      const role = req.user.role as Role;
      const { status } = req.query;

      const deposits = await DepositService.getAllDeposits(
        userId,
        role,
        status as DepositStatus
      );
      
      res.json(deposits);
    } catch (error: any) {
      if (error.message.includes('Access denied')) {
        return res.status(403).json({ error: error.message });
      }
      res.status(400).json({ error: error.message });
    }
  }

  static async updateDepositStatus(req: Request, res: Response) {
    try {
      const { depositId } = req.params;
      const { status } = req.body;
      // @ts-ignore
      const userId = req.user.id;
      // @ts-ignore
      const role = req.user.role as Role;

      if (!status || !Object.values(DepositStatus).includes(status as DepositStatus)) {
        return res.status(400).json({ error: 'Valid status is required' });
      }

      const deposit = await DepositService.updateDepositStatus(
        depositId,
        userId,
        role,
        status as DepositStatus
      );
      
      res.json(deposit);
    } catch (error: any) {
      if (error.message.includes('Access denied')) {
        return res.status(403).json({ error: error.message });
      }
      res.status(400).json({ error: error.message });
    }
  }
}
