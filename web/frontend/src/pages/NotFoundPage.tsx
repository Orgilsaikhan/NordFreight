import { Link } from 'react-router'
import { PageHeader } from '../components/PageHeader'

export function NotFoundPage() {
  return (
    <>
      <PageHeader title="Хуудас олдсонгүй" subtitle="Энэ хаягаар хуудас алга." />
      <Link className="button" to="/">
        Тойм руу буцах
      </Link>
    </>
  )
}
