import { PrismaClient } from '@prisma/client'
import { PrismaD1 } from '@prisma/adapter-d1'

const prismaClientSingleton = () => {
  if (process.env.NEXT_RUNTIME === 'edge') {
    try {
      // Use dynamic require to avoid bundling issues in Node.js build steps
      const openNext = require('@opennextjs/cloudflare')
      if (openNext && typeof openNext.getRequestContext === 'function') {
        const { env } = openNext.getRequestContext()
        if (env && env.DB) {
          const adapter = new PrismaD1(env.DB)
          return new PrismaClient({ adapter })
        } else {
          console.warn("D1 database binding 'DB' not found in context. Falling back to Node.js PrismaClient.")
        }
      } else {
        console.warn("getRequestContext is not available. Falling back to Node.js PrismaClient.")
      }
    } catch (e) {
      console.error("Failed to initialize PrismaD1 adapter. Falling back to Node.js PrismaClient.", e)
    }
  }
  if (!process.env.DATABASE_URL) {
    process.env.DATABASE_URL = 'file:./dev.db'
  }
  return new PrismaClient()
}

declare const globalThis: {
  prismaGlobal: any;
} & typeof global;

let _prismaInstance: any = null;

const getPrismaInstance = () => {
  if (!_prismaInstance) {
    _prismaInstance = globalThis.prismaGlobal ?? prismaClientSingleton();
    if (process.env.NODE_ENV !== 'production') {
      globalThis.prismaGlobal = _prismaInstance;
    }
  }
  return _prismaInstance;
};

const prisma = new Proxy({} as any, {
  get(_target, prop, receiver) {
    const instance = getPrismaInstance();
    const value = Reflect.get(instance, prop, receiver);
    if (typeof value === 'function') {
      return value.bind(instance);
    }
    return value;
  }
});

export { prisma }
