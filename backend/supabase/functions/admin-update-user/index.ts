import { allowedRoles, corsHeaders, errorResponse, HttpError, requireAdmin, validateAssignment, validateRoleAssignment } from '../_shared/admin.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405, headers: corsHeaders })
  try {
    const { adminClient, callerId, organizationId } = await requireAdmin(req)
    const { user_id, full_name, role, department_id = null, team_id = null } = await req.json()
    if (typeof user_id !== 'string' || typeof full_name !== 'string' || !full_name.trim() || !allowedRoles.has(role)) {
      throw new HttpError('Thông tin tài khoản không hợp lệ', 400)
    }
    if (user_id === callerId && role !== 'admin') throw new HttpError('Không thể tự bỏ quyền quản trị', 400)
    validateRoleAssignment(role, department_id, team_id)
    const { data: target } = await adminClient.from('profiles').select('organization_id,department_id,team_id')
      .eq('id', user_id).maybeSingle()
    if (!target || target.organization_id !== organizationId) throw new HttpError('Tài khoản không hợp lệ', 400)
    await validateAssignment(adminClient, organizationId, department_id, team_id)

    if (target.team_id !== team_id || target.department_id !== department_id) {
      const { count, error } = await adminClient.from('customers').select('id', { count: 'exact', head: true })
        .eq('owner_user_id', user_id)
      if (error) throw error
      if ((count ?? 0) > 0) throw new HttpError('Nhân viên còn khách đang phụ trách. Hãy chuyển khách trước khi đổi nhóm/phòng.', 409)
    }

    const { error } = await adminClient.from('profiles').update({ full_name: full_name.trim(), role, department_id, team_id }).eq('id', user_id)
    if (error) throw error
    return Response.json({ ok: true }, { headers: corsHeaders })
  } catch (error) { return errorResponse(error) }
})
