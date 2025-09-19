import { Injectable, Logger } from '@nestjs/common';
import { MailerService as NestMailerService } from '@nestjs-modules/mailer';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class MailerService {
  private readonly logger = new Logger(MailerService.name);

  constructor(
    private readonly nestMailerService: NestMailerService,
    private readonly prisma: PrismaService,
  ) {}

  async sendTestEmail() {
    const message = `This is a test email.`;

    await this.nestMailerService.sendMail({
      from: 'Test <noreply@winkels.com.br>',
      to: 'hmaster.studio@gmail.com',
      subject: `Test Email`,
      text: message,
    });
  }

  @Cron(CronExpression.EVERY_1ST_DAY_OF_MONTH_AT_MIDNIGHT)
  async sendMonthlyReports() {
    this.logger.log('Sending monthly reports...');
    // keep track of execution time
    const start = Date.now();

    const users = await this.prisma.user.findMany({
      where: {
        email: {
          not: 'hmaster.studio@gmail.com',
        },
      },
      include: {
        meshes: {
          include: {
            devices: {
              include: {
                readings: true,
              },
            },
          },
        },
      },
    });

    for (const user of users) {
      for (const mesh of user.meshes) {
        let totalTemp = 0;
        let readingCount = 0;
        for (const device of mesh.devices) {
          for (const reading of device.readings) {
            if (reading.temperature) {
              totalTemp += reading.temperature;
              readingCount++;
            }
          }
        }
        const avgTemp = readingCount > 0 ? totalTemp / readingCount : 0;

        const message = `Monthly report for mesh ${mesh.name}: Average temperature is ${avgTemp.toFixed(2)}°C.`;

        await this.nestMailerService.sendMail({
          to: user.email,
          subject: `Monthly Report for ${mesh.name}`,
          text: message,
        });

        this.logger.log(
          `Sent monthly report to ${user.email} for mesh ${mesh.name}`,
        );
      }
    }

    const end = Date.now();
    this.logger.log(`Monthly reports sent in ${end - start} ms`);
  }
}
