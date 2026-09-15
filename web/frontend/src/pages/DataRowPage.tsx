import { useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import { Link, useParams, useSearchParams } from 'react-router'
import { api, errorText } from '../api'
import { Card } from '../components/Card'
import { PageHeader } from '../components/PageHeader'
import { ErrorMessage, Loadable } from '../components/States'
import {
  DATETIME_TYPES,
  DECIMAL_TYPES,
  INTEGER_TYPES,
  readOnlyReason,
  rowEditorPath,
  toInputValue,
  typeLabel,
} from '../dataEditor'
import type { ColumnInfo, DataRow, ForeignKeyOptions, TableInfo } from '../types'
import { useApi } from '../useApi'

// Tables that also have a regular page on the site.
const PAGE_LINKS: Record<string, (key: URLSearchParams) => string> = {
  Shipments: (key) => `/shipments/${key.get('ShipmentId')}`,
  Customers: (key) => `/customers/${key.get('CustomerId')}`,
  Invoices: (key) => `/invoices/${key.get('InvoiceId')}`,
}

export function DataRowPage() {
  const { table = '' } = useParams()
  const [params] = useSearchParams()
  const [saved, setSaved] = useState(false)
  const base = `/data/tables/${encodeURIComponent(table)}`
  const meta = useApi<TableInfo>(base)
  const row = useApi<DataRow>(`${base}/row?${params}`)
  const options = useApi<ForeignKeyOptions>(`${base}/options`)

  const keyParts: string[] = []
  params.forEach((value, name) => keyParts.push(`${name} ${value}`))
  const pageLink = PAGE_LINKS[table]

  return (
    <>
      <PageHeader
        back={{ to: `/data/${encodeURIComponent(table)}`, label: table }}
        title={`${table} · ${keyParts.join(', ')}`}
        subtitle="Анхдагч түлхүүрээс бусад утгыг засаж болно. Өгөгдлийн сангийн хязгаарлалт, триггерүүд хэвээр үйлчилнэ."
        actions={
          pageLink && (
            <Link className="button" to={pageLink(params)}>
              Хуудсаар харах
            </Link>
          )
        }
      />
      {saved && (
        <p className="notice saved-notice" role="status">
          Хадгалагдлаа.
        </p>
      )}
      <Loadable state={meta}>
        {(info) => (
          <Loadable state={row}>
            {(values) => (
              <RowForm
                key={JSON.stringify(values)}
                table={info}
                row={values}
                options={options.data ?? {}}
                keyQuery={params.toString()}
                onSaved={() => {
                  setSaved(true)
                  row.reload()
                }}
                onEdit={() => setSaved(false)}
              />
            )}
          </Loadable>
        )}
      </Loadable>
    </>
  )
}

interface RowFormProps {
  table: TableInfo
  row: DataRow
  options: ForeignKeyOptions
  keyQuery: string
  onSaved: () => void
  onEdit: () => void
}

function RowForm({ table, row, options, keyQuery, onSaved, onEdit }: RowFormProps) {
  const initial = useMemo(
    () => Object.fromEntries(table.columns.map((column) => [column.name, toInputValue(column, row[column.name])])),
    [table, row],
  )
  const [values, setValues] = useState<Record<string, string>>(initial)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const changed = table.columns.filter((column) => column.editable && values[column.name] !== initial[column.name])
  const versionColumn = table.columns.find((column) => column.row_version)

  function update(name: string, value: string) {
    setValues((current) => ({ ...current, [name]: value }))
    onEdit()
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (changed.length === 0) return
    setSaving(true)
    setError(null)
    try {
      await api.patch(`/data/tables/${encodeURIComponent(table.name)}/row?${keyQuery}`, {
        changes: Object.fromEntries(changed.map((column) => [column.name, values[column.name]])),
        row_version: versionColumn ? row[versionColumn.name] : null,
      })
      onSaved()
    } catch (err) {
      setError(errorText(err))
      setSaving(false)
    }
  }

  return (
    <form className="stack" onSubmit={submit}>
      {error && <ErrorMessage message={error} />}
      <Card>
        <div className="form-grid">
          {table.columns.map((column) => (
            <FieldEditor
              key={column.name}
              column={column}
              value={values[column.name]}
              changed={changed.includes(column)}
              options={options[column.name]}
              onChange={(value) => update(column.name, value)}
            />
          ))}
        </div>
      </Card>
      <div className="save-bar">
        <span className="muted small">
          {changed.length === 0 ? 'Өөрчлөлт алга' : `Өөрчлөгдсөн: ${changed.map((column) => column.name).join(', ')}`}
        </span>
        <div className="page-actions">
          <button
            type="button"
            className="button"
            disabled={changed.length === 0 || saving}
            onClick={() => setValues(initial)}
          >
            Буцаах
          </button>
          <button type="submit" className="button primary" disabled={changed.length === 0 || saving}>
            {saving ? 'Хадгалж байна…' : 'Хадгалах'}
          </button>
        </div>
      </div>
    </form>
  )
}

interface FieldEditorProps {
  column: ColumnInfo
  value: string
  changed: boolean
  options: ForeignKeyOptions[string] | undefined
  onChange: (value: string) => void
}

function FieldEditor({ column, value, changed, options, onChange }: FieldEditorProps) {
  const id = `field-${column.name}`
  const reason = readOnlyReason(column)
  const wide = column.editable && !column.references && (column.max_length === null || column.max_length > 200) && isText(column)
  const classes = ['control', changed ? 'is-changed' : '', wide ? 'wide' : ''].filter(Boolean).join(' ')

  return (
    <div className={classes}>
      <label htmlFor={id} className="field-name">
        <span>{column.name}</span>
        <span className="field-type">{typeLabel(column)}</span>
      </label>
      {reason ? (
        <input id={id} className="input" value={value === '' ? 'NULL' : value} readOnly />
      ) : (
        <EditorInput id={id} column={column} value={value} options={options} onChange={onChange} />
      )}
      {reason && <span className="hint">{reason}</span>}
      {column.references && value !== '' && (
        <span className="hint">
          <Link to={rowEditorPath(column.references.table, { [column.references.column]: value })}>
            {`${column.references.table} мөрийг нээх`}
          </Link>
        </span>
      )}
    </div>
  )
}

function isText(column: ColumnInfo) {
  return ['char', 'varchar', 'text', 'nchar', 'nvarchar', 'ntext'].includes(column.type)
}

interface EditorInputProps {
  id: string
  column: ColumnInfo
  value: string
  options: ForeignKeyOptions[string] | undefined
  onChange: (value: string) => void
}

function EditorInput({ id, column, value, options, onChange }: EditorInputProps) {
  const required = !column.nullable
  const change = (event: { target: { value: string } }) => onChange(event.target.value)

  if (column.type === 'bit') {
    return (
      <select id={id} className="select" required={required} value={value} onChange={change}>
        {column.nullable && <option value="">NULL</option>}
        <option value="1">1 · Тийм</option>
        <option value="0">0 · Үгүй</option>
      </select>
    )
  }
  if (column.references && options) {
    const known = options.some((option) => String(option.value) === value)
    return (
      <select id={id} className="select" required={required} value={value} onChange={change}>
        {(column.nullable || value === '') && <option value="">{column.nullable ? 'NULL' : 'Сонгоно уу'}</option>}
        {value !== '' && !known && <option value={value}>{value}</option>}
        {options.map((option) => (
          <option key={String(option.value)} value={String(option.value)}>
            {option.label ? `${option.value} · ${option.label}` : String(option.value)}
          </option>
        ))}
      </select>
    )
  }
  if (INTEGER_TYPES.has(column.type)) {
    return <input id={id} className="input" type="number" step="1" required={required} value={value} onChange={change} />
  }
  if (DECIMAL_TYPES.has(column.type)) {
    const step = column.type === 'float' || column.type === 'real' ? 'any' : column.scale > 0 ? (10 ** -column.scale).toFixed(column.scale) : '1'
    return <input id={id} className="input" type="number" step={step} required={required} value={value} onChange={change} />
  }
  if (column.type === 'date') {
    return <input id={id} className="input" type="date" required={required} value={value} onChange={change} />
  }
  if (DATETIME_TYPES.has(column.type)) {
    return (
      <input id={id} className="input" type="datetime-local" step="1" required={required} value={value} onChange={change} />
    )
  }
  if (column.max_length === null || column.max_length > 200) {
    return (
      <textarea
        id={id}
        className="input textarea"
        rows={3}
        maxLength={column.max_length ?? undefined}
        required={required}
        value={value}
        onChange={change}
      />
    )
  }
  return (
    <input id={id} className="input" maxLength={column.max_length} required={required} value={value} onChange={change} />
  )
}
