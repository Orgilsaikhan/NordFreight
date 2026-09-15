import * as fmt from '../format'

interface PaginationProps {
  page: number
  pageSize: number
  total: number
  onPage: (page: number) => void
}

export function Pagination({ page, pageSize, total, onPage }: PaginationProps) {
  const pages = Math.max(1, Math.ceil(total / pageSize))
  const first = total === 0 ? 0 : (page - 1) * pageSize + 1
  const last = Math.min(total, page * pageSize)

  return (
    <div className="pagination">
      <span>{total === 0 ? 'Илэрц алга' : `${fmt.num(first)}–${fmt.num(last)} / нийт ${fmt.num(total)}`}</span>
      <div className="pagination-buttons">
        <button type="button" className="button small" disabled={page <= 1} onClick={() => onPage(page - 1)}>
          Өмнөх
        </button>
        <button type="button" className="button small" disabled={page >= pages} onClick={() => onPage(page + 1)}>
          Дараах
        </button>
      </div>
    </div>
  )
}
