**TASK:** Completely rebuild the Super Admin and Gym Owner dashboards in `admin/app/dashboard/page.tsx` with perfect role-based logic.

**REQUIREMENTS (follow exactly):**

1. **Single page architecture**
   - Use existing `page.tsx` as the main entry point
   - Detect user role via auth (Super Admin vs Gym Owner)
   - Render either SuperAdminDashboard or GymOwnerDashboard component

2. **Super Admin Dashboard (Platform Overview)**
   - 4 large KPI StatCards: Total Gym Owners, Total Branches, Total Platform Revenue (this month), Avg Revenue per Owner
   - Charts (use Recharts or Tremor, match existing dark theme #121721 + #F1C40F accent):
     - Revenue Trend (line chart, last 30/90 days)
     - New Gym Owners Growth
     - Top 10 Gym Owners by Revenue (bar chart)
   - Real-time active gyms counter
   - Table: All Gym Owners with revenue, branches count, status (sortable + searchable + CSV export)

3. **Gym Owner Dashboard (Branch Cards ONLY — NO AVERAGES)**
   - Display ONLY individual Branch Cards in a responsive grid
   - Each Branch Card must show:
     - Branch name + location
     - Today’s Check-ins
     - Monthly Revenue (specific to this branch)
     - Total Visitors (today / this month)
     - Door Activity (today)
     - Active Members
     - Staff Performance (sessions + completion rate)
   - Each card is clickable (goes to branch detail page)
   - Real-time updates on check-ins and door activity
   - Date range picker (Week / Month / Custom)

4. **Design & UX Rules (must match existing style perfectly)**
   - Dark theme: bg-[#121721], border-zinc-800, accent #F1C40F
   - Use existing StatCard component where possible
   - Modern, clean, productive, fast-loading
   - Fully responsive
   - Real-time WebSocket updates where possible
   - Add subtle AI Summary box on both dashboards (e.g. “+28% revenue this month”)

**Files to create / modify:**

- `admin/app/dashboard/page.tsx` (main role-based page)
- `admin/components/dashboard/SuperAdminDashboard.tsx` (new)
- `admin/components/dashboard/GymOwnerDashboard.tsx` (new)
- `admin/components/ui/BranchCard.tsx` (new reusable card)

Use existing components, icons (lucide-react), and styling. Make it production-ready and visually flagship level.

Start implementing now.
