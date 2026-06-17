# GrubShelf Permission System

## Role hierarchy

| Role | Description |
|------|-------------|
| **Owner** | Primary household admin (`is_owner = TRUE`). One per household. |
| **Admin** | Can manage pantry/shopping, approve items, invite/remove members (with limits). |
| **Member** | Can contribute; pantry/shopping adds go to `pending` until approved. |
| **Guest** | Read-only access to approved pantry and shopping data. |

## Permission matrix

| Action | Owner | Admin | Member | Guest |
|--------|-------|-------|--------|-------|
| Delete household | Yes | No | No | No |
| Transfer ownership | Yes | No | No | No |
| Change roles | Yes | No | No | No |
| Remove admins | Yes | No | No | No |
| Remove members | Yes | Yes | No | No |
| Approve/reject items | Yes | Yes | No | No |
| Add items (approved) | Yes | Yes | No | No |
| Add items (pending) | Yes | Yes | Yes | No |
| Edit own pending items | Yes | Yes | Yes | No |
| Delete pantry items | Yes | Yes | No | No |
| View approved items | Yes | Yes | Yes | Yes |
| Modify budget settings | Yes* | Yes* | No** | No |
| Invite members | Yes | Yes | Yes | No |
| View audit logs | Yes | Yes | Yes | Yes |

\* With `can_modify_budget = TRUE` (default for owner/admin).  
\*\* Unless granted `can_manage_budget` via `member_permissions`.

## Database enforcement

- **RLS** on all household-scoped tables via `get_my_household_id()`.
- **RPCs** for sensitive actions: `transfer_ownership`, `remove_household_member`, `change_user_role`, approval functions.
- **Approval workflow**: members insert `approval_status = 'pending'`; admins insert `approved`.

## Client helper

Call `get_my_permissions()` to receive a JSON capability map for UI gating.

## Related docs

- [ROLES.md](./ROLES.md) — role responsibilities
- [AUDIT_LOGS.md](./AUDIT_LOGS.md) — logged events
