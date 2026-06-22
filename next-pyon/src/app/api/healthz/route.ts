import { NextResponse } from 'next/server'
import { prisma } from '@/lib/db'

export const runtime = 'edge'

export async function GET() {
  try {
    // Count users to verify database connection
    const userCount = await prisma.user.count()
    
    return NextResponse.json({
      status: 'ok',
      runtime: process.env.NEXT_RUNTIME || 'unknown',
      database: 'connected',
      userCount,
      timestamp: new Date().toISOString()
    })
  } catch (error: any) {
    return NextResponse.json({
      status: 'error',
      runtime: process.env.NEXT_RUNTIME || 'unknown',
      database: 'disconnected',
      error: error.message || String(error),
      timestamp: new Date().toISOString()
    }, { status: 500 })
  }
}
