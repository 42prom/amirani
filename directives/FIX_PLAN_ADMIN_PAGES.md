# Fix Plan: Super Admin & Gym Owner Pages

## Executive Summary
After thorough scanning of all Super Admin and Gym Owner pages, I identified **27 issues** across buttons, inputs, filters, API mismatches, and database inconsistencies.

---

## CRITICAL ISSUES (Priority 1 - Breaking Functionality)

### 1. Missing Backend Endpoint: Branch Admin Creation
**Location:**
- Frontend: `admin/lib/api.ts:92-93`
- Backend: `backend/src/modules/admin/admin.controller.ts` (missing)

**Problem:** Frontend calls `POST /admin/branch-admins` but this endpoint doesn't exist.

**Fix:**
```typescript
// Add to admin.controller.ts
router.post('/branch-admins', gymOwnerOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const branchAdmin = await AdminService.createBranchAdmin(
      req.user!.userId,
      req.user!.role,
      req.body
    );
    created(res, branchAdmin);
  } catch (err) {
    // error handling
  }
});
```

Also add `createBranchAdmin` method to `AdminService`.

---

### 2. Equipment API Route Mismatch
**Location:**
- Frontend: `admin/lib/api.ts:113-124` uses `/equipment/gyms/:gymId`
- Backend: `backend/src/modules/gyms/gym-owner.controller.ts:506-602` uses `/gym-owner/gyms/:gymId/equipment`

**Problem:** Frontend equipment API calls wrong endpoint path.

**Fix:** Update `admin/lib/api.ts`:
```typescript
export const equipmentApi = {
  getByGym: (gymId: string, token: string) =>
    api<Equipment[]>(`/gym-owner/gyms/${gymId}/equipment`, { token }),
  create: (gymId: string, data: CreateEquipmentData, token: string) =>
    api<Equipment>(`/gym-owner/gyms/${gymId}/equipment`, { method: "POST", body: data, token }),
  update: (id: string, data: Partial<CreateEquipmentData>, token: string) =>
    api<Equipment>(`/gym-owner/equipment/${id}`, { method: "PATCH", body: data, token }),
  delete: (id: string, token: string) =>
    api(`/gym-owner/equipment/${id}`, { method: "DELETE", token }),
  getStats: (gymId: string, token: string) =>
    api<EquipmentStats>(`/gym-owner/gyms/${gymId}/equipment/stats`, { token }), // This endpoint also needs creation
};
```

---

### 3. Equipment Stats Endpoint Missing
**Location:** Backend missing `/gym-owner/gyms/:gymId/equipment/stats`

**Problem:** Frontend calls `equipmentApi.getStats()` but endpoint doesn't exist.

**Fix:** Add to `gym-owner.controller.ts`:
```typescript
router.get('/gyms/:gymId/equipment/stats', async (req: AuthenticatedRequest, res: Response) => {
  const gym = await prisma.gym.findUnique({ where: { id: req.params.gymId } });
  if (!gym) return notFound(res, 'Gym not found');
  if (req.user!.role !== Role.SUPER_ADMIN && gym.ownerId !== req.user!.userId) {
    return forbidden(res, 'Access denied');
  }

  const stats = await prisma.equipment.groupBy({
    by: ['status'],
    where: { gymId: req.params.gymId },
    _count: { id: true },
    _sum: { quantity: true },
  });

  const result = {
    total: stats.reduce((acc, s) => acc + (s._sum.quantity || 0), 0),
    available: stats.find(s => s.status === 'AVAILABLE')?._sum.quantity || 0,
    maintenance: stats.find(s => s.status === 'MAINTENANCE')?._sum.quantity || 0,
    outOfOrder: stats.find(s => s.status === 'OUT_OF_ORDER')?._sum.quantity || 0,
  };

  return success(res, result);
});
```

---

## HIGH PRIORITY ISSUES (Priority 2 - Non-functional Buttons)

### 4. Trainers Page: "EDIT SPECIFICATIONS" Button Non-functional
**Location:** `admin/app/dashboard/trainers/page.tsx:305-307`

**Problem:** Button exists but has no onClick handler.

**Fix:**
```typescript
<button
  onClick={() => {
    setEditingTrainer(trainer);
    setShowEditModal(true);
  }}
  className="w-full py-3 bg-white/5 hover:bg-white/10..."
>
  EDIT SPECIFICATIONS
</button>
```

Also need to create an edit trainer modal and update mutation.

---

### 5. Gym Detail Page: "Edit Information Matrix" Button Non-functional
**Location:** `admin/app/dashboard/gyms/[gymId]/page.tsx:193-196`

**Problem:** Button shows but does nothing.

**Fix:**
```typescript
const [showEditModal, setShowEditModal] = useState(false);
// ...
<button
  onClick={() => setShowEditModal(true)}
  className="w-full py-6 bg-white/[0.03]..."
>
  Edit Information Matrix
  <ArrowRight size={18} className="group-hover:translate-x-2 transition-transform" />
</button>
```

Create EditGymModal component using `gymsApi.update()`.

---

### 6. Gym Owners Page: Missing Edit/Deactivate Actions
**Location:** `admin/app/dashboard/gym-owners/page.tsx:68-101`

**Problem:** List displays gym owners but no edit or deactivate functionality.

**Fix:** Add action buttons:
```typescript
<div className="flex items-center gap-2">
  <button onClick={() => handleEdit(owner)} className="p-2 hover:bg-zinc-800 rounded-lg">
    <Edit2 size={16} className="text-zinc-400" />
  </button>
  <button
    onClick={() => handleDeactivate(owner.id)}
    className="p-2 hover:bg-red-500/10 rounded-lg"
  >
    <UserX size={16} className="text-red-400" />
  </button>
</div>
```

---

### 7. File Upload Buttons Show Alert Only
**Locations:**
- `admin/app/dashboard/trainers/page.tsx:496-503` (Trainer avatar)
- `admin/app/dashboard/equipment/page.tsx:500-508` (Equipment image)
- `admin/app/dashboard/equipment-catalog/page.tsx:411-420` (Catalog image)

**Problem:** All file uploads just show `alert()` - no actual upload.

**Fix:** Implement proper file upload:
```typescript
const uploadImage = async (file: File): Promise<string> => {
  const formData = new FormData();
  formData.append('file', file);
  const response = await fetch(`${API_BASE_URL}/uploads/image`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: formData,
  });
  const data = await response.json();
  return data.url;
};

// In onChange handler:
onChange={async (e) => {
  const file = e.target.files?.[0];
  if (file) {
    const url = await uploadImage(file);
    setFormData({ ...formData, imageUrl: url });
  }
}}
```

Also need to create upload endpoint in backend.

---

## MEDIUM PRIORITY ISSUES (Priority 3 - Missing Features)

### 8. Members Page: No Member Actions
**Location:** `admin/app/dashboard/members/page.tsx`

**Problem:** Can only view members, cannot:
- Edit membership
- Cancel membership
- Assign/change trainer
- Change plan

**Fix:** Add action column with dropdown menu:
```typescript
<td className="px-6 py-4">
  <DropdownMenu>
    <DropdownMenuTrigger>
      <MoreVertical size={16} />
    </DropdownMenuTrigger>
    <DropdownMenuContent>
      <DropdownMenuItem onClick={() => handleEditMembership(membership)}>
        Edit Membership
      </DropdownMenuItem>
      <DropdownMenuItem onClick={() => handleAssignTrainer(membership)}>
        Assign Trainer
      </DropdownMenuItem>
      <DropdownMenuItem onClick={() => handleCancelMembership(membership.id)}>
        Cancel Membership
      </DropdownMenuItem>
    </DropdownMenuContent>
  </DropdownMenu>
</td>
```

---

### 9. Members Page: No Status Filter
**Location:** `admin/app/dashboard/members/page.tsx:33-36`

**Problem:** Only filters by name/email, not by status (ACTIVE, EXPIRED, etc.)

**Fix:**
```typescript
const [statusFilter, setStatusFilter] = useState<string>("");

const filteredMembers = members?.filter((m) =>
  (m.user.fullName.toLowerCase().includes(searchTerm.toLowerCase()) ||
   m.user.email.toLowerCase().includes(searchTerm.toLowerCase())) &&
  (!statusFilter || m.status === statusFilter)
);

// Add status filter dropdown
<select
  value={statusFilter}
  onChange={(e) => setStatusFilter(e.target.value)}
  className="..."
>
  <option value="">All Statuses</option>
  <option value="ACTIVE">Active</option>
  <option value="EXPIRED">Expired</option>
  <option value="CANCELLED">Cancelled</option>
  <option value="PENDING">Pending</option>
</select>
```

---

### 10. Equipment Quantity Display Hardcoded
**Location:** `admin/app/dashboard/equipment/page.tsx:387`

**Problem:** Shows "Qty: 01" hardcoded instead of actual quantity.

**Fix:**
```typescript
// Change from:
<span>Qty: 01</span>
// To:
<span>Qty: {String(item.quantity).padStart(2, '0')}</span>
```

---

### 11. Door Access Page: No System Management
**Location:** `admin/app/dashboard/access/page.tsx`

**Problem:** Can view door systems but cannot:
- Add new door system
- Edit door system
- Delete door system

**Fix:** Add CRUD functionality for door systems with proper API calls.

---

### 12. Analytics Page: Hardcoded Trend Values
**Location:** `admin/app/dashboard/analytics/page.tsx:123-150`

**Problem:** Shows "+2 this month", "+12% from last month" as hardcoded strings.

**Fix:** Calculate actual trends from historical data or remove fake trends.

---

## LOW PRIORITY ISSUES (Priority 4 - Form Validation)

### 13. Plan Creation: No Price Validation
**Location:** `admin/app/dashboard/gyms/[gymId]/plans/page.tsx:395-400`

**Problem:** Can enter negative prices.

**Fix:**
```typescript
<input
  type="number"
  min="0"
  step="0.01"
  value={formData.priceMonthly}
  onChange={(e) => setFormData({
    ...formData,
    priceMonthly: Math.max(0, parseFloat(e.target.value) || 0)
  })}
/>
```

---

### 14. Time Restriction: No End > Start Validation
**Location:** `admin/app/dashboard/gyms/[gymId]/plans/page.tsx:436-479`

**Problem:** Can set end time before start time.

**Fix:**
```typescript
const validateTimeRange = () => {
  if (!formData.hasTimeRestriction) return true;
  const start = formData.accessStartTime?.split(':').map(Number) || [0, 0];
  const end = formData.accessEndTime?.split(':').map(Number) || [0, 0];
  return (end[0] * 60 + end[1]) > (start[0] * 60 + start[1]);
};

// In handleSubmit:
if (!validateTimeRange()) {
  alert('End time must be after start time');
  return;
}
```

---

### 15. Features Array: Can Add Empty Features
**Location:** `admin/app/dashboard/gyms/[gymId]/plans/page.tsx:163-168`

**Problem:** Clicking "Add" with empty input adds empty string.

**Fix:** Already has `newFeature.trim()` check, but button should be disabled:
```typescript
<button
  type="button"
  onClick={addFeature}
  disabled={!newFeature.trim()}
  className="px-4 py-2 bg-zinc-700 text-white rounded-lg hover:bg-zinc-600 disabled:opacity-50"
>
  Add
</button>
```

---

### 16. Trainer Modal: Missing Required Field Validation
**Location:** `admin/app/dashboard/trainers/page.tsx:331-551`

**Problem:** Branch Admin requires email/password but validation only on form submit.

**Fix:** Add inline validation and disable submit until valid:
```typescript
const isFormValid = useMemo(() => {
  if (!formData.fullName.trim()) return false;
  if (!formData.gymId) return false;
  if (formData.staffType === 'BRANCH_ADMIN') {
    if (!formData.email?.trim() || !formData.password?.trim()) return false;
    if (formData.password.length < 6) return false;
  }
  return true;
}, [formData]);
```

---

## DATABASE/SCHEMA ISSUES (Priority 5)

### 17. Equipment API Type Missing `model` Field
**Location:** `admin/lib/api.ts:219-227` and `admin/lib/api.ts:307-314`

**Problem:** `Equipment` and `CreateEquipmentData` types don't include `model` field that exists in Prisma schema.

**Fix:**
```typescript
export interface Equipment {
  id: string;
  name: string;
  category: string;
  brand?: string;
  model?: string;  // Add this
  quantity: number;
  status: "AVAILABLE" | "MAINTENANCE" | "OUT_OF_ORDER";
  notes?: string;
}

export interface CreateEquipmentData {
  name: string;
  category: string;
  brand?: string;
  model?: string;  // Add this
  quantity?: number;
  status?: "AVAILABLE" | "MAINTENANCE" | "OUT_OF_ORDER";
  notes?: string;
}
```

---

### 18. Trainer Type Missing `email` and `role` for Branch Admins
**Location:** `admin/lib/api.ts:182-196`

**Problem:** When trainers list includes Branch Admins, they have `userId` set but the `Trainer` type doesn't properly handle this.

**Fix:** Already has `email?: string` and `role?: Role` but need to use them properly in the UI to distinguish Branch Admins.

---

## UI/UX ISSUES (Priority 6)

### 19. Gym Selector Auto-Selection Side Effect
**Location:** Multiple pages (`trainers/page.tsx:37-39`, `members/page.tsx:22-24`, etc.)

**Problem:** Using `if (!selectedGymId && gyms && gyms.length > 0) { setSelectedGymId(gyms[0].id); }` inside render causes React state update during render.

**Fix:** Use `useEffect`:
```typescript
useEffect(() => {
  if (!selectedGymId && gyms && gyms.length > 0) {
    setSelectedGymId(gyms[0].id);
  }
}, [gyms, selectedGymId]);
```

---

### 20. Create Gym Modal: ownerId Set to Current User
**Location:** `admin/app/dashboard/gyms/page.tsx:27-28`

**Problem:** When Super Admin creates gym, ownerId is set to Super Admin's ID, not a selected Gym Owner.

**Fix:** Add gym owner selector for Super Admin:
```typescript
{isSuperAdmin(user?.role) && (
  <CustomSelect
    label="Assign to Gym Owner"
    value={selectedOwnerId}
    onChange={(value) => setSelectedOwnerId(value)}
    options={gymOwners?.map(o => ({ value: o.id, label: o.fullName })) || []}
    required
  />
)}
```

---

### 21. Loading States Without Error Handling
**Location:** Multiple pages

**Problem:** Loading states show spinner but failed queries don't show error messages.

**Fix:** Add error handling:
```typescript
const { data, isLoading, error } = useQuery(...);

if (error) {
  return (
    <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-4">
      <p className="text-red-400">Failed to load data: {error.message}</p>
      <button onClick={() => queryClient.invalidateQueries(...)}>
        Retry
      </button>
    </div>
  );
}
```

---

### 22. Confirm Dialogs Using `confirm()`
**Location:** Multiple pages (equipment delete, plan delete, etc.)

**Problem:** Browser `confirm()` dialogs don't match the app's premium UI.

**Fix:** Create custom confirmation modal component.

---

### 23. Missing Pagination
**Location:** All list pages

**Problem:** Large datasets will cause performance issues.

**Fix:** Implement pagination:
- Backend: Add `?page=1&limit=20` support
- Frontend: Add pagination component

---

## IMPLEMENTATION ORDER

### Phase 1: Critical Fixes (Week 1)
1. Fix Equipment API routes mismatch (#2)
2. Add Branch Admin endpoint (#1)
3. Add Equipment Stats endpoint (#3)

### Phase 2: Button Functionality (Week 1-2)
4. Trainer Edit button (#4)
5. Gym Edit button (#5)
6. Gym Owner actions (#6)

### Phase 3: File Uploads (Week 2)
7. Implement file upload system (#7)

### Phase 4: Feature Completion (Week 2-3)
8. Member actions (#8)
9. Member status filter (#9)
10. Equipment quantity (#10)
11. Door system management (#11)

### Phase 5: Validation & Polish (Week 3)
12-16. Form validations
17-18. Type fixes
19-23. UI/UX improvements

---

## FILES TO MODIFY

### Backend
- `backend/src/modules/admin/admin.controller.ts` - Add branch admin endpoint
- `backend/src/modules/admin/admin.service.ts` - Add createBranchAdmin method
- `backend/src/modules/gyms/gym-owner.controller.ts` - Add equipment stats endpoint
- `backend/src/index.ts` - Add uploads route
- New: `backend/src/modules/uploads/upload.controller.ts`

### Frontend
- `admin/lib/api.ts` - Fix equipment routes, add upload function, fix types
- `admin/app/dashboard/trainers/page.tsx` - Add edit functionality
- `admin/app/dashboard/gym-owners/page.tsx` - Add edit/deactivate
- `admin/app/dashboard/gyms/[gymId]/page.tsx` - Add edit modal
- `admin/app/dashboard/members/page.tsx` - Add actions and filters
- `admin/app/dashboard/equipment/page.tsx` - Fix quantity, file upload
- `admin/app/dashboard/gyms/[gymId]/plans/page.tsx` - Add validations
- `admin/app/dashboard/access/page.tsx` - Add CRUD for door systems
- `admin/app/dashboard/analytics/page.tsx` - Remove fake trends
- New: `admin/components/modals/ConfirmModal.tsx`
- New: `admin/components/Pagination.tsx`

### Database
- May need migrations if schema changes are required

---

## ESTIMATED EFFORT
- Phase 1: 4-6 hours
- Phase 2: 6-8 hours
- Phase 3: 4-6 hours
- Phase 4: 8-10 hours
- Phase 5: 6-8 hours

**Total: ~28-38 hours**
