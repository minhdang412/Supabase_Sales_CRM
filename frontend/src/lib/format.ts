export const money = (value?: number | null) => {
  if (value == null) return 'Chưa có'
  return new Intl.NumberFormat('vi-VN').format(value) + ' đ'
}

export const shortMoney = (value?: number | null) => {
  if (value == null) return 'Chưa có'
  if (value >= 1_000_000_000) return (value / 1_000_000_000).toFixed(value % 1_000_000_000 ? 1 : 0) + ' tỷ'
  if (value >= 1_000_000) return (value / 1_000_000).toFixed(value % 1_000_000 ? 1 : 0) + ' triệu'
  return new Intl.NumberFormat('vi-VN').format(value) + ' đ'
}

export const dateTime = (iso?: string | null) => {
  if (!iso) return 'Chưa có'
  const d = new Date(iso)
  return new Intl.DateTimeFormat('vi-VN', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }).format(d)
}

export const timeOnly = (iso: string) => new Intl.DateTimeFormat('vi-VN', { hour: '2-digit', minute: '2-digit' }).format(new Date(iso))

export const localDate = (date: Date) => [date.getFullYear(), String(date.getMonth()+1).padStart(2,'0'), String(date.getDate()).padStart(2,'0')].join('-')

export const relativeTime = (iso?: string | null) => {
  if (!iso) return 'Chưa chăm sóc'
  const diff = Date.now() - new Date(iso).getTime()
  const mins = Math.max(0, Math.round(diff / 60000))
  if (mins < 60) return `${mins} phút trước`
  const hrs = Math.round(mins / 60)
  if (hrs < 24) return `${hrs} giờ trước`
  const days = Math.round(hrs / 24)
  if (days === 1) return 'Hôm qua'
  return `${days} ngày trước`
}

export const roleLabel = (role: string) => ({
  sales: 'Nhân viên bán hàng', team_leader: 'Trưởng nhóm bán hàng', sales_manager: 'Trưởng phòng bán hàng', admin: 'Quản trị viên'
}[role] ?? role)

export const priorityLabel = (p: string) => p === 'high' ? 'Cao' : 'Bình thường'
export const potentialLabel = (p?: string) => p === 'hot' ? 'Nóng' : p === 'potential' ? 'Tiềm năng' : 'Theo dõi'
