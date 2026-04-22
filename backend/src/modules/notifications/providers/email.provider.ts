import {
  INotificationProvider,
  NotificationPayload,
  NotificationResult,
} from './notification-provider.interface';
import prisma from '../../../utils/prisma';
import axios from 'axios';
import * as nodemailer from 'nodemailer';
import { decryptField } from '../../../utils/crypto';

/**
 * Email Notification Provider
 * Supports SendGrid API and SMTP via database configuration
 */
export class EmailNotificationProvider implements INotificationProvider {
  readonly type = 'EMAIL' as const;

  async send(payload: NotificationPayload, email?: string): Promise<NotificationResult> {
    if (!email) {
      return { success: false, error: 'Email address not provided' };
    }

    try {
      const cfg = await prisma.pushNotificationConfig.findUnique({
        where: { id: 'singleton' },
      });

      if (!cfg || !cfg.emailEnabled) {
        return { success: true, messageId: 'disabled' };
      }

      if (cfg.emailProvider === 'sendgrid') {
        return this.sendViaSendGrid(cfg, email, payload);
      } else if (cfg.emailProvider === 'smtp') {
        return this.sendViaSmtp(cfg, email, payload);
      } else {
        return { success: false, error: 'No email provider configured' };
      }
    } catch (error: any) {
      return { success: false, error: 'Email delivery failed' };
    }
  }

  private async sendViaSendGrid(cfg: any, to: string, payload: NotificationPayload): Promise<NotificationResult> {
    const sendgridApiKey = decryptField(cfg.sendgridApiKey);
    if (!sendgridApiKey) throw new Error('SendGrid API key missing');

    try {
      const response = await axios.post(
        'https://api.sendgrid.com/v3/mail/send',
        {
          personalizations: [{ to: [{ email: to }] }],
          from: { email: cfg.fromEmail || 'noreply@amirani.app', name: cfg.fromName || 'Amirani' },
          subject: payload.title,
          content: [{ type: 'text/html', value: this.buildEmailTemplate(payload) }],
        },
        {
          headers: {
            Authorization: `Bearer ${sendgridApiKey}`,
            'Content-Type': 'application/json',
          },
        }
      );

      return { success: true, messageId: response.headers['x-message-id'] || `sg_${Date.now()}` };
    } catch (error: any) {
      const errMsg = error.response?.data?.errors?.[0]?.message || error.message;
      throw new Error(`SendGrid error: ${errMsg}`);
    }
  }

  private async sendViaSmtp(cfg: any, to: string, payload: NotificationPayload): Promise<NotificationResult> {
    if (!cfg.smtpHost) throw new Error('SMTP host missing');

    const transporter = nodemailer.createTransport({
      host: cfg.smtpHost,
      port: cfg.smtpPort || 587,
      secure: cfg.smtpPort === 465,
      auth: cfg.smtpUser ? {
        user: cfg.smtpUser,
        pass: decryptField(cfg.smtpPassword) ?? undefined,
      } : undefined,
    });

    const info = await transporter.sendMail({
      from: `"${cfg.fromName || 'Amirani'}" <${cfg.fromEmail || 'noreply@amirani.app'}>`,
      to,
      subject: payload.title,
      html: this.buildEmailTemplate(payload),
    });

    return { success: true, messageId: info.messageId };
  }

  async sendBatch(payloads: NotificationPayload[], emails?: string[]): Promise<NotificationResult[]> {
    if (!emails || emails.length !== payloads.length) {
      return payloads.map(() => ({ success: false, error: 'Email count mismatch' }));
    }
    return Promise.all(payloads.map((p, i) => this.send(p, emails[i])));
  }

  async isAvailable(): Promise<boolean> {
    const cfg = await prisma.pushNotificationConfig.findUnique({ where: { id: 'singleton' } });
    return !!cfg?.emailEnabled && (!!cfg.sendgridApiKey || !!cfg.smtpHost);
  }

  private buildEmailTemplate(payload: NotificationPayload): string {
    return `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; background: #121721; color: #fff; margin: 0; padding: 0; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #F1C40F; color: #000; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
          .content { padding: 30px; background: #1a2035; color: #fff; line-height: 1.6; }
          .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
          h1 { margin: 0; font-size: 24px; }
          p { margin: 16px 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>${payload.title}</h1>
          </div>
          <div class="content">
            <p>${payload.body}</p>
          </div>
          <div class="footer">
            <p>&copy; ${new Date().getFullYear()} Amirani Fitness. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    `;
  }
}

