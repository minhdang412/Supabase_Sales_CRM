import { CircleDollarSign } from 'lucide-react'
import { Card, PageTitle } from '../components/UI'

export function QuotesPage() {
  return <div className="page">
    <PageTitle title="Báo giá" subtitle="Báo giá hiện được quản lý trực tiếp trong từng hồ sơ khách hàng."/>
    <Card className="coming-soon-card">
      <div className="coming-soon-icon"><CircleDollarSign className="h-5 w-5" strokeWidth={1.75}/></div>
      <strong>Hoàn thiện sau</strong>
      <p>Phần Báo giá ở menu riêng sẽ được thiết kế lại ở giai đoạn sau. Hiện tại hãy tạo và xem báo giá ngay trong hồ sơ từng khách hàng.</p>
    </Card>
  </div>
}
