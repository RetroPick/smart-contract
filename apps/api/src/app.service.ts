import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getHello() {
    return {
      status: 'ok',
      app: 'api',
      program: 'market_engine',
      packages: ['@retropick/sdk', '@retropick/types'],
    };
  }
}
