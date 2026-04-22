export * from './notification-provider.interface';
export * from './push.provider';
export * from './email.provider';
export * from './inapp.provider';

import { INotificationProvider } from './notification-provider.interface';
import { PushNotificationProvider } from './push.provider';
import { EmailNotificationProvider } from './email.provider';
import { InAppNotificationProvider } from './inapp.provider';

export type NotificationChannelType = 'PUSH' | 'EMAIL' | 'SMS' | 'IN_APP';

/**
 * Notification Provider Factory
 */
export class NotificationProviderFactory {
  private static providers: Map<NotificationChannelType, INotificationProvider> = new Map();

  static getProvider(channel: NotificationChannelType): INotificationProvider {
    if (this.providers.has(channel)) {
      return this.providers.get(channel)!;
    }

    let provider: INotificationProvider;

    switch (channel) {
      case 'PUSH':
        provider = new PushNotificationProvider();
        break;
      case 'EMAIL':
        provider = new EmailNotificationProvider();
        break;
      case 'IN_APP':
        provider = new InAppNotificationProvider();
        break;
      case 'SMS':
        // SMS not implemented yet, fall back to in-app
        provider = new InAppNotificationProvider();
        break;
      default:
        provider = new InAppNotificationProvider();
    }

    this.providers.set(channel, provider);
    return provider;
  }

  static getAllProviders(): INotificationProvider[] {
    return [
      this.getProvider('PUSH'),
      this.getProvider('EMAIL'),
      this.getProvider('IN_APP'),
    ];
  }
}
