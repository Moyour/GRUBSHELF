# GrubShelf Audit Logs

## Table: `audit_logs`

| Column | Description |
|--------|-------------|
| `user_id` | Actor (authenticated user at time of event) |
| `household_id` | Household scope |
| `action` | Event type (see below) |
| `target_entity` | Table or resource type |
| `target_id` | Primary key of affected row |
| `metadata` | JSON details |
| `performed_by` | Same as actor (explicit) |
| `affected_user` | User impacted, when applicable |
| `old_value` / `new_value` | Optional state snapshots |
| `created_at` | Timestamp |

## Logged actions

| Action | When |
|--------|------|
| `ownership_transferred` | Owner transfers household |
| `member_removed` | Member removed from household |
| `role_changed` | Owner changes a member role |
| `item_approved` | Admin approves pantry/shopping item |
| `item_rejected` | Admin rejects item |
| `bulk_items_approved` | Bulk approve RPC |
| `invite_created` | Household invite sent |
| `invite_approved` / `invite_rejected` | Admin reviews invite |
| `member_joined` | Invite accepted |
| `permission_granted` / `permission_revoked` | Custom permission change |
| `budget_permission_changed` | `can_modify_budget` updated |
| `delegation_set` | Approval amount limit set |
| `category_approval_rule_set` | Category approval rule updated |

## Writing audit events

Use the RPC from application or other RPCs:

```sql
SELECT log_audit_event(
  'custom_action',
  'entity_name',
  '<uuid>',
  '{"key": "value"}'::jsonb,
  p_affected_user := '<uuid>',
  p_old_value := NULL,
  p_new_value := NULL
);
```

Direct `INSERT` into `audit_logs` is blocked by RLS.

## Reading audit logs

Household members can `SELECT` rows where `household_id` matches their household (see migration 020).
