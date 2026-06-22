import { PrismaClient } from '@prisma/client'
import { PrismaD1 } from '@prisma/adapter-d1'

const prismaClientSingleton = () => {
  if (process.env.NEXT_RUNTIME === 'edge') {
    try {
      // Use dynamic require to avoid bundling issues in Node.js build steps
      const { getRequestContext } = require('@opennextjs/cloudflare')
      const { env } = getRequestContext()
      if (env && env.DB) {
        const adapter = new PrismaD1(env.DB)
        return new PrismaClient({ adapter })
      } else {
        console.warn("D1 database binding 'DB' not found in context. Falling back to Node.js PrismaClient.")
      }
    } catch (e) {
      console.error("Failed to initialize PrismaD1 adapter. Falling back to Node.js PrismaClient.", e)
    }
  }
  return new PrismaClient()
}

declare const globalThis: {
  prismaGlobal: ReturnType<typeof prismaClientSingleton>;
} & typeof global;

const prisma = globalThis.prismaGlobal ?? prismaClientSingleton()

export { prisma }

if (process.env.NODE_ENV !== 'production') globalThis.prismaGlobal = prisma
