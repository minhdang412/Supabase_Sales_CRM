import { corsHeaders, errorResponse, HttpError, requireAdmin, validateAssignment, validateRoleAssignment } from '../_shared/admin.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405, headers: corsHeaders })
  try {
    const { adminClient, callerId, organizationId } = await requireAdmin(req)
    const { user_id, locked = true } = await req.json()
    if (typeof user_id !== 'string' || typeof locked !== 'boolean') throw new HttpError('Yêu cầu không hợp lệ', 400)
    if (user_id === callerId && locked) throw new HttpError('Không thể tự khóa tài khoản quản trị', 400)
    const { data: target } = await adminClient.from('profiles').select('id,role,department_id,team_id')
      .eq('id', user_id).eq('organization_id', organizationId).maybeSingle()
    if (!target) throw new HttpError('Tài khoản không hợp lệ', 400)
    if (!locked) {
      validateRoleAssignment(target.role, target.department_id, target.team_id)
      await validateAssignment(adminClient, organizationId, target.department_id, target.team_id)
    }

    const { error } = await adminClient.from('profiles').update({ status: locked ? 'locked' : 'active' }).eq('id', user_id)
    if (error) throw error
    return Response.json({ ok: true }, { headers: corsHeaders })
  } catch (error) { return errorResponse(error) }
})
