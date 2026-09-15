import { Link } from 'react-router'
import { PageHeader } from '../components/PageHeader'

export function NotFoundPage() {
  return (
    <>
      <PageHeader title="Page not found" subtitle="That address doesn't match anything here." />
      <Link className="button" to="/">
        Back to overview
      </Link>
    </>
  )
}
