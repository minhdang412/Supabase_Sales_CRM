import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

export class HttpError extends Error {
  constructor(message: string, public status: number) { super(message) }
}

export function errorResponse(error: unknown) {
  const status = error instanceof HttpError ? error.status : 500
  const message = error instanceof HttpError ? error.message : 'Không thể xử lý yêu cầu'
  return new Response(message, { status, headers: corsHeaders })
}

function defaultKey(name: string) {
  const keys = JSON.parse(Deno.env.get(name) || '{}') as Record<string, string>
  return keys.default
}

export async function requireAdmin(req: Request) {
  const token = /^Bearer\s+(.+)$/i.exec(req.headers.get('Authorization') || '')?.[1]
  if (!token) throw new HttpError('Unauthorized', 401)
  const url = Deno.env.get('SUPABASE_URL')
  const publishable = defaultKey('SUPABASE_PUBLISHABLE_KEYS') || Deno.env.get('SUPABASE_PUBLISHABLE_KEY')
  const secret = defaultKey('SUPABASE_SECRET_KEYS') || Deno.env.get('SUPABASE_SECRET_KEY')
  if (!url || !publishable || !secret) throw new Error('Missing Supabase function configuration')

  const authClient = createClient(url, publishable, { auth: { persistSession: false } })
  const adminClient = createClient(url, secret, { auth: { persistSession: false } })
  const { data: { user }, error } = await authClient.auth.getUser(token)
  if (error || !user) throw new HttpError('Unauthorized', 401)
  const { data: profile, error: profileError } = await adminClient.from('profiles')
    .select('role,status,organization_id').eq('id', user.id).single()
  if (profileError || !profile || profile.role !== 'admin' || profile.status !== 'active' || !profile.organization_id) {
    throw new HttpError('Forbidden', 403)
  }
  return { adminClient, callerId: user.id, organizationId: profile.organization_id as string }
}

export const allowedRoles = new Set(['sales', 'team_leader', 'sales_manager', 'admin'])

export function validateRoleAssignment(role: string, departmentId: unknown, teamId: unknown) {
  if ((departmentId !== null && typeof departmentId !== 'string') ||
      (teamId !== null && typeof teamId !== 'string')) throw new HttpError('Phòng/nhóm không hợp lệ', 400)
  if (role === 'admin' && (departmentId || teamId)) throw new HttpError('Admin không chọn phòng/nhóm', 400)
  if (role === 'sales_manager' && (!departmentId || teamId)) throw new HttpError('Trưởng phòng cần phòng và không chọn nhóm', 400)
  if (['sales', 'team_leader'].includes(role) && (!departmentId || !teamId)) throw new HttpError('Nhân viên/trưởng nhóm cần phòng và nhóm', 400)
}

export async function validateAssignment(
  adminClient: Awaited<ReturnType<typeof requireAdmin>>['adminClient'],
  organizationId: string,
  departmentId: string | null,
  teamId: string | null,
) {
  if (departmentId) {
    const { data: department } = await adminClient.from('departments')
      .select('id').eq('id', departmentId).eq('organization_id', organizationId).eq('is_active', true).maybeSingle()
    if (!department) throw new HttpError('Phòng không hợp lệ', 400)
  }
  if (teamId) {
    if (!departmentId) throw new HttpError('Chọn phòng trước khi chọn nhóm', 400)
    const { data: team } = await adminClient.from('teams')
      .select('id').eq('id', teamId).eq('department_id', departmentId)
      .eq('organization_id', organizationId).eq('is_active', true).maybeSingle()
    if (!team) throw new HttpError('Nhóm không thuộc phòng đã chọn', 400)
  }
}
