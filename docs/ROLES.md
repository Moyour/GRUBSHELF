# GrubShelf Roles

## Owner

- Created when a user calls `set_self_admin_for_household` after creating a household.
- Exactly one owner per household (`users.is_owner = TRUE`).
- Exclusive capabilities:
  - Delete the household
  - Transfer ownership (`transfer_ownership`)
  - Promote/demote roles (`change_user_role`)
  - Set approval delegation limits (`set_approval_delegation`)
  - Remove any non-owner member

## Admin

- Promoted by the owner via `change_user_role(target, 'admin')`.
- Can approve/reject pending pantry and shopping items.
- Can remove **members** only (not other admins or the owner).
- Cannot delete the household or change roles.

## Member

- Default role for new invites (`accept_household_invite`).
- Adds pantry/shopping items as **pending**.
- Can edit/delete only their own pending submissions.
- Can invite others (rate-limited: 5 invites/hour).
- Can view household data and log transactions (read/insert per existing RLS).

## Guest

- Assigned by owner via `change_user_role(target, 'guest')`.
- Read-only: approved pantry items, shopping lists, shopping items.
- No financial write access; no invites.

## Promoting and demoting

```sql
-- Owner only
SELECT change_user_role('<user_id>', 'admin');
SELECT change_user_role('<user_id>', 'member');
SELECT change_user_role('<user_id>', 'guest');
```

The last admin cannot be demoted if they are the only non-owner admin.

## Ownership transfer

```sql
SELECT transfer_ownership('<new_owner_user_id>');
```

The previous owner becomes a regular admin (`is_owner = FALSE`).
