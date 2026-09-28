import { Button, EmptyState } from '../components/UI'
import { useNavigate } from 'react-router-dom'
export function NotFoundPage(){const nav=useNavigate();return <div className="page"><EmptyState title="Không tìm thấy trang" description="Đường dẫn này không tồn tại hoặc bạn không có quyền truy cập." action={<Button onClick={()=>nav('/today')}>Về Hôm nay</Button>}/></div>}
