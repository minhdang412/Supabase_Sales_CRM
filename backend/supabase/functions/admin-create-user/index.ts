import { allowedRoles, corsHeaders, errorResponse, HttpError, requireAdmin, validateAssignment, validateRoleAssignment } from '../_shared/admin.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405, headers: corsHeaders })
  try {
    const { adminClient, organizationId } = await requireAdmin(req)
    const { email, full_name, role, department_id = null, team_id = null } = await req.json()
    if (typeof email !== 'string' || !email.trim() || typeof full_name !== 'string' || !full_name.trim() || !allowedRoles.has(role)) {
      throw new HttpError('Thông tin tài khoản không hợp lệ', 400)
    }
    validateRoleAssignment(role, department_id, team_id)
    await validateAssignment(adminClient, organizationId, department_id, team_id)

    const address = email.trim().toLowerCase()
    let existingId: string | null = null
    for (let page = 1; ; page++) {
      const { data: listed, error: listError } = await adminClient.auth.admin.listUsers({ page, perPage: 1000 })
      if (listError) throw listError
      existingId = listed.users.find(u => u.email?.toLowerCase() === address)?.id ?? null
      if (existingId || listed.users.length < 1000) break
    }
    let userId = existingId
    if (userId) {
      const { data: existingProfile, error: profileLookupError } = await adminClient.from('profiles')
        .select('organization_id,status').eq('id', userId).single()
      if (profileLookupError) throw profileLookupError
      if (existingProfile.organization_id || existingProfile.status !== 'locked') {
        throw new HttpError('Email đã thuộc một tài khoản CRM. Hãy chỉnh tài khoản hiện có.', 409)
      }
    } else {
      const origin = req.headers.get('origin')
      let redirectTo: string | undefined
      if (origin) {
        const site = new URL(origin)
        if (site.protocol === 'https:' || (site.protocol === 'http:' && site.hostname === 'localhost')) {
          redirectTo = new URL('/set-password', site).toString()
        }
      }
      const { data, error } = await adminClient.auth.admin.inviteUserByEmail(address, {
        data: { full_name: full_name.trim() },
        ...(redirectTo ? { redirectTo } : {}),
      })
      if (error) throw new HttpError(error.message, 400)
      userId = data.user.id
    }

    // The Auth trigger creates a locked profile first. An orphan Auth account can be assigned here.
    const { error: profileError } = await adminClient.from('profiles').update({
      full_name: full_name.trim(), role, organization_id: organizationId,
      department_id, team_id, status: 'active',
    }).eq('id', userId)
    if (profileError) throw profileError
    return Response.json({ user_id: userId, existing_auth_user: !!existingId }, { headers: corsHeaders })
  } catch (error) { return errorResponse(error) }
})
