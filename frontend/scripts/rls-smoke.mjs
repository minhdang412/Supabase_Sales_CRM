import assert from 'node:assert/strict'
import { createClient } from '@supabase/supabase-js'

const required = ['DEV_URL', 'DEV_PUBLISHABLE_KEY', 'SALES_A_EMAIL', 'SALES_A_PASSWORD',
  'SALES_B_EMAIL', 'SALES_B_PASSWORD', 'MANAGER_EMAIL', 'MANAGER_PASSWORD']
for (const name of required) if (!process.env[name]) throw new Error(`Thiếu biến môi trường ${name}`)
const url = process.env.DEV_URL
const key = process.env.DEV_PUBLISHABLE_KEY
const client = () => createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } })
async function login(email, password) {
  const sb = client()
  const { error } = await sb.auth.signInWithPassword({ email, password })
  if (error) throw error
  return sb
}
async function rows(result) {
  if (result.error) throw result.error
  return result.data ?? []
}
const a = await login(process.env.SALES_A_EMAIL, process.env.SALES_A_PASSWORD)
const b = await login(process.env.SALES_B_EMAIL, process.env.SALES_B_PASSWORD)
const manager = await login(process.env.MANAGER_EMAIL, process.env.MANAGER_PASSWORD)
const leader = process.env.LEADER_EMAIL && process.env.LEADER_PASSWORD
  ? await login(process.env.LEADER_EMAIL, process.env.LEADER_PASSWORD) : null
const profiles = await Promise.all([a, b, manager, leader].filter(Boolean).map(async sb => {
  const { data: { user } } = await sb.auth.getUser()
  const profile = (await rows(sb.from('profiles').select('id,team_id,department_id,role').eq('id', user.id).single()))
  return profile
}))
assert.notEqual(profiles[0].id, profiles[1].id)
assert.equal(profiles[0].department_id, profiles[1].department_id, 'Hai Sales phải cùng phòng cho Duplicate Report')
assert.equal(profiles[2].role, 'sales_manager')
const sources = await rows(a.from('lead_sources').select('id').eq('is_active', true).limit(1))
assert.ok(sources.length, 'Thiếu nguồn khách')
const sourceId = sources[0].id
// Two valid Vietnamese numbers normalized to the same contact. Records remain in DEV.
const phone = '09' + String(Math.floor(Math.random() * 1e8)).padStart(8, '0')
const marker = 'RLS-SMOKE-' + Date.now()
async function create(sb, suffix) {
  const result = await rows(sb.rpc('create_lead', {
    p_source_id: sourceId, p_display_name: marker + suffix,
    p_contact_raw: phone, p_contact_type: 'phone',
    p_product_id: null, p_variant_id: null, p_note: 'DEV RLS smoke'
  }))
  assert.equal(result.length, 1)
  return result[0].customer_id
}
const aId = await create(a, '-A')
const bId = await create(b, '-B')
const search = async sb => rows(sb.rpc('search_customers_filtered', {
  p_query: phone, p_quick_filter: 'all', p_source_id: null, p_stage_id: null, p_limit: 100, p_offset: 0
}))
const aVisible = await search(a)
const bVisible = await search(b)
assert.ok(aVisible.some(c => c.customer_id === aId))
assert.ok(!aVisible.some(c => c.customer_id === bId), 'Sales A nhìn thấy hồ sơ B')
assert.ok(bVisible.some(c => c.customer_id === bId))
assert.ok(!bVisible.some(c => c.customer_id === aId), 'Sales B nhìn thấy hồ sơ A')
const direct = await rows(a.from('customers').select('id').eq('id', bId))
assert.equal(direct.length, 0, 'Direct table read bị lộ')
const forbidden = await a.rpc('get_duplicate_customers', { p_contact_type: 'phone' })
assert.ok(forbidden.error, 'Sales không được gọi Duplicate Report')
const dup = await rows(manager.rpc('get_duplicate_customers', { p_contact_type: 'phone' }))
assert.ok(dup.some(d => d.match_value === phone && d.records.some(r => r.customer_id === aId)
  && d.records.some(r => r.customer_id === bId)), 'Manager không thấy đủ hai hồ sơ')
if (leader) {
  const leaderDup = await leader.rpc('get_duplicate_customers', { p_contact_type: 'phone' })
  assert.ok(leaderDup.error, 'Trưởng nhóm không được gọi Duplicate Report')
  const visible = await search(leader)
  assert.equal(visible.some(c => c.customer_id === aId), profiles[3].team_id === profiles[0].team_id)
  assert.equal(visible.some(c => c.customer_id === bId), profiles[3].team_id === profiles[1].team_id)
}
console.log('PASS: tạo trùng, Sales isolation, direct RLS, Manager duplicate, Team Leader scope (nếu có).')
console.log('DEV test records:', aId, bId)
