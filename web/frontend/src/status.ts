export type Tone = 'good' | 'warning' | 'serious' | 'critical' | 'open' | 'neutral'

export const SHIPMENT_STATUSES = ['Booked', 'PickedUp', 'InTransit', 'OutForDelivery', 'Delivered', 'Exception', 'Cancelled']
export const INVOICE_STATUSES = ['Issued', 'PartiallyPaid', 'Overdue', 'Paid', 'Draft', 'Cancelled']
export const AGEING_BUCKETS = ['Current', '1-30 days', '31-60 days', '61-90 days', '90+ days']

// Status colours are reserved for states that mean good or bad. Work still in motion
// gets a hollow dot, and settled-but-neutral states a grey one. Every badge also has a label.
const TONES: Record<string, Tone> = {
  Delivered: 'good',
  Paid: 'good',
  'On Time': 'good',
  Valid: 'good',
  Completed: 'good',
  Available: 'good',
  Active: 'good',

  Booked: 'open',
  PickedUp: 'open',
  InTransit: 'open',
  OutForDelivery: 'open',
  Issued: 'open',
  'In Progress': 'open',
  Planned: 'open',
  Dispatched: 'open',
  OnTrip: 'open',

  PartiallyPaid: 'warning',
  'At Risk': 'warning',
  'Due Today': 'warning',
  'Licence Expiring Soon': 'warning',
  InMaintenance: 'warning',

  Late: 'serious',
  Overdue: 'serious',

  Exception: 'critical',
  Breached: 'critical',
  'Licence Expired': 'critical',
}

export function toneOf(value: string): Tone {
  return TONES[value] ?? 'neutral'
}
