export type Role = 'sales' | 'team_leader' | 'sales_manager' | 'admin'
export type Priority = 'normal' | 'high'
export type Potential = 'hot' | 'potential' | 'watch'
export type OpportunityStatus = 'active' | 'paused' | 'won' | 'lost'

export interface Profile {
  id: string
  full_name: string
  role: Role
  status: 'active' | 'locked'
  organization_id?: string | null
  department_id?: string | null
  team_id?: string | null
}

export interface TodayTask {
  id: string
  title: string
  due_at: string
  priority: Priority
  customer_id?: string | null
  opportunity_id?: string | null
}

export interface PriorityLead {
  id: string
  display_name: string
  created_at: string
  source_name: string
  source_id?: string | null
  response_sla_minutes?: number | null
  age_minutes: number
}

export interface TodayDashboard {
  overview: {
    overdue_tasks: number
    today_tasks: number
    new_leads_today: number
    priority_unhandled: number
  }
  overdue_tasks: TodayTask[]
  upcoming_tasks: TodayTask[]
  priority_new_leads: PriorityLead[]
}

export interface CustomerListItem {
  customer_id: string
  display_name: string
  source_id?: string | null
  source_name: string
  last_activity_at?: string | null
  primary_contact?: string | null
  next_task_at?: string | null
  active_opportunity?: {
    id: string
    product_id?: string | null
    variant_id?: string | null
    stage_id?: string | null
    status?: OpportunityStatus
    priority?: Priority
    potential_level?: Potential
  } | null
}

export interface CustomerDetail {
  id: string
  owner_user_id: string
  display_name: string
  source_name: string
  note?: string | null
  created_at: string
  last_activity_at?: string | null
  contacts: Array<{ id: string; contact_type: string; raw_value: string; is_primary: boolean }>
  opportunities: OpportunityCard[]
  activities: Array<{ id: string; activity_type: string; result_code?: string | null; note?: string | null; occurred_at: string }>
  quotes: QuoteItem[]
  tasks: TaskItem[]
}

export interface OpportunityCard {
  id: string
  status: OpportunityStatus
  priority: Priority
  potential_level: Potential
  purchase_timeline: string
  payment_type: string
  loan_ratio?: number | null
  budget_min?: number | null
  budget_max?: number | null
  competitor_note?: string | null
  stage?: { id: string; code: string; display_name: string; sort_order: number } | null
  product?: { id: string; name: string } | null
  variant?: { id: string; name: string } | null
}

export interface TaskItem {
  id: string
  title: string
  due_at: string
  priority: Priority
  status: 'pending' | 'completed' | 'cancelled'
  note?: string | null
  customer_id?: string | null
  opportunity_id?: string | null
}

export interface QuoteItem {
  id: string
  version: number
  final_price?: number | null
  list_price?: number | null
  discount_amount?: number | null
  promotion_note?: string | null
  storage_path?: string | null
  status: 'draft' | 'sent' | 'accepted' | 'expired'
  created_at: string
  sent_at?: string | null
}

export interface MasterItem { id: string; name: string; code?: string; display_name?: string; sort_order?: number }
export interface ProductItem { id: string; name: string; code: string }
export interface StageItem { id: string; code: string; display_name: string; sort_order: number }
export interface TaskTypeItem { id: string; code: string; display_name: string }

export interface PipelineGroup {
  stage: StageItem
  customers: Array<{ customer_id: string; display_name: string; opportunity: OpportunityCard; source_name: string }>
}

export interface FunnelRow { stage_code: string; stage_name: string; reached_count: number }
export interface LeadSourceReportRow {
  source_id: string
  source_name: string
  lead_count: number
  responded_count: number
  quoted_count: number
  deposit_count: number
  won_count: number
  avg_response_minutes?: number | null
}
