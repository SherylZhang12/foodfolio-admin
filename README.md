# Foodfolio Studio — Week 6 Admin Panel

Separate Next.js application for the existing Foodfolio Supabase database.
Do not deploy this folder into the Week 1–5 Vercel project. Create a NEW GitHub
repository and NEW Vercel project, as required by the assignment.

## Features and rubric mapping

- Overview: exact account, AI creation, published post and vote totals; positive-vote
  share; persona popularity; seven-day creation activity; private draft and preference counts.
- Users: read registered users, emails, profile names, IDs, join dates and admin flags.
- AI media: read text and signed photo previews, search, create/import a genuine
  AI-generated reaction with its original prompts, edit, delete with typed confirmation.
- Ratings: read upvotes/downvotes, personal food preferences and earlier sample ratings.
- Consistent navigation, friendly failure/empty states, responsive layout, clear action labels.

## Local setup

Use Node 20.9 or later. Run `npm install` in this folder.
Create `.env.local` from `.env.example` and set the same URL and publishable key
as the existing Foodfolio app. Do NOT put a service-role key into the browser or
NEXT_PUBLIC variables. No service-role key is required by this app.

Run `npm run dev` and open http://localhost:3004.

## Database setup (existing Foodfolio database only)

1. Run `supabase/week6_admin.sql` in the existing Foodfolio project's SQL Editor.
   Then run `supabase/week6_admin_photos.sql` to enable photo attachments.
   It assumes the Week 3–5 tables already exist. Both migrations run in transactions.
2. Sign in with your Google account in the main Foodfolio app at least once.
3. Find YOUR exact UUID under Supabase Authentication > Users.
4. In SQL Editor, run `update public.profiles set is_superadmin=true where id='YOUR-EXACT-UUID';`.
5. Verify ONLY the intended account was promoted. Do not mass-update profiles.
6. Sign into the admin app using that same Google account.

This is the assignment's bootstrap answer: the Supabase dashboard database owner
can grant the initial role outside the protected application. Ordinary profile
updates cannot change the role because of the database trigger.

## Google OAuth and deployment

1. Create an EMPTY GitHub repository named `foodfolio-admin`. Do not initialize a
   README remotely when pushing this already initialized repository.
2. Add its HTTPS URL as origin and push main:

   git remote add origin https://github.com/SherylZhang12/foodfolio-admin.git
   git push -u origin main

3. In Vercel, Add New > Project > Import foodfolio-admin. Use Next.js and root `./`.
4. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY to the
   existing Foodfolio project's values. Deploy.
5. In Supabase Authentication > URL Configuration, retain all main-app redirect
   URLs and ADD the new admin stable URL and chosen commit-specific URL followed
   by `/auth/callback`. Add `http://localhost:3004/auth/callback` for local testing.
   Keep the main app's Site URL intact.
6. Vercel project Settings > Deployment Protection: turn Vercel Authentication off
   for the submission deployment. The application Google/admin wall stays ON.
7. Open the new deployment in an Incognito window. It must show the app's Google
   login page WITHOUT a Vercel login prompt. It must not show private admin data.

## Required acceptance tests before submission

- Signed out: visit /admin, /admin/users, /admin/media, /admin/ratings; all redirect to login.
- Ordinary Google user: all protected routes deny access, including manually typed URLs.
- Superadmin: all four pages load real database data.
- Create ONE disposable media record using a genuine AI response and its prompts.
  Refresh to verify it persists. Update that record, refresh, then delete ONLY that
  disposable record. Check that the delete confirmation is required.
- Confirm vote and rating rows match the main app's database.
- Verify a normal user's profile update cannot set is_superadmin=true.
- Main Foodfolio app: create, preview, publish and vote still work.
- Check mobile layout, loading/error states and signed image previews.
- Record the ACTUAL Week 5 feedback and demonstrate each implemented change.
  Prior known feedback was clearer first-time navigation and character introductions;
  this is not evidence of any additional Week 5 feedback.

## Submission

Submit TWO latest commit-specific Vercel visit URLs, not dashboard URLs:

1. Main Foodfolio AI creation/rating deployment.
2. This NEW admin app deployment.

Never substitute an old deployment or only the mutable stable domain.
Deployment, OAuth and SQL must be verified online before claiming completion/full marks.

## Security and limitations

Every page has a server-side role check; mutations check again. Database RPCs
verify the authenticated UUID, Google identity and protected profile role, use
an empty search_path, and revoke anonymous execution. The app never directly
grants broad CRUD policies to nonadmins. Admin image URLs expire in ten minutes.
Deletion removes the database record and cascading votes/bookmarks; retained
storage files are intentionally not deleted. Creation imports actual AI output;
it does not call the model again. New and edited records support optional JPG, PNG,
WebP photo uploads (10 MB) with a local preview. Uploads use private Storage; the
admin-only RPC validates ownership, existence, MIME type and size before linking a photo.
Replacing a photo retains the previous storage file. Statistics currently
fetch the complete small class-project dataset; add pagination before large-scale use.

Run `npm test`, `npm run check`, and `npm run build` to validate locally.
