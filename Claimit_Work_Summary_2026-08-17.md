# Work Summary — Claimit (17 Aug 2026)

**To:** [Client name]
**From:** [Your name]
**Subject:** Claimit — today's work: Learn Claimit feature, S3 storage fix, Featured Zones bug fixes

---

Hi [Client name],

Summary of everything completed on Claimit today (app, website, and both backends), plus what's still pending deployment.

## 1. Production incident — resolved

The server went down (MongoDB stopped, backend API errored, app showed network errors). Root cause: an automatic Ubuntu kernel update (to 6.19) broke MongoDB 8.0.x due to a known MongoDB bug (SERVER-121912). Fixed by pinning MongoDB to version 8.0.4 and holding it there. Took a full database backup before touching anything — **no data was lost or changed.** Confirmed the app and both backends were back to normal after the fix.

Not yet done (flagged, not urgent): the underlying cause — automatic OS updates that can reboot the server unattended — hasn't been disabled/reviewed yet. Recommend doing this soon so this can't repeat.

## 2. Shop list — pagination, location, and premium-first ordering

Finished the Reward Zone / Redeem Zone shop list: shops now load in pages (instead of all at once), sorted by the user's location (nearest first) with premium shops prioritized, and more load automatically as the user scrolls. Fully backward-compatible — nothing else that calls the shop list broke.

## 3. Featured Zones (home screen popup) — icon sizing + two overflow bugs fixed

- Increased and then rebalanced the zone icon sizes twice per feedback; made all icons a consistent size (previously the "More" tile was oddly bigger than the rest).
- Reward Zone, Redeem Zone, and Local Finder icons are now ~2.5% bigger than the other zones, as requested.
- Fixed a layout overflow on the shop cards (traced back to the pagination change above — a card badge row wasn't handling the new location data properly).
- Fixed a layout overflow in the Featured Zones popup itself — the root cause was a missing `isScrollControlled` setting on the popup, which silently caps its height regardless of content. Also added a scroll fallback so this class of bug can't recur on any screen size.
- Fixed an unrelated pre-existing overflow on the Reels screen's offer badge while in the area.

## 4. Home screen category icons

Replaced the 16 scrolling category icons (and added a 17th "All" icon) with the new artwork provided — asset swap only, categories, names, and functionality unchanged.

## 5. "Claim Your Business" — new feature

Shops that were bulk-uploaded by admin (no owner yet) now show a "Claim Your Business" banner on their shop page in the app. Tapping it opens the website's registration page. The banner automatically disappears once a shop is claimed and paid for. Moved to the top of the page and restyled to be more prominent, per feedback.

Confirmed: full payment transaction history was already being recorded in its own database collection (`transactions`), with an existing admin page to view it — no new work needed there.

## 6. Learn Claimit — new feature (built end-to-end)

A new "Learn Claimit" tile in the Featured Zones popup opens a list of how-to-use-the-app questions; tapping a question plays its answer video fullscreen (with sound, a mute toggle, and a like button).

Content is fully dynamic — admin adds/removes lessons from a new admin panel page (enter a question, upload a video), and they appear in the app immediately, no app update needed.

Built:
- New admin page (web) — add question + video, list, delete.
- New admin API (web backend) — video upload reuses the existing secure S3 upload flow.
- New public API (app backend) — serves the lesson list to the app, with per-user like tracking.
- New app screens (Flutter) — question list + fullscreen video player, matching the look of the existing Reels player.

Also fixed two video-playback bugs found during testing today: the video wasn't filling the screen (was shrinking to fit instead of covering edge-to-edge), and a related layout issue was cutting the video off partway down the screen. Both fixed; video is now properly fullscreen.

## 7. Storage clean-up — orphaned files in S3

You flagged a good question: when an image or video gets deleted, does the actual file get removed from S3 storage too, or does it just get orphaned there forever (wasting storage)? Audited every delete action across both backends and found several places where the answer was "orphaned":

- Deleting a shop (admin panel) — its photos stayed in S3.
- Deleting a user — their shops' photos stayed in S3.
- Deleting a user — their claim documents and scanned bill photos stayed in S3.
- Removing an image from a category's image pool — the removed image stayed in S3.
- A shop owner removing one gallery photo — that photo stayed in S3.
- Deleting a classified ad listing — its photos stayed in S3.

All six now clean up their S3 files properly when deleted. (Ad deletion and the new Learn Claimit deletion already handled this correctly — left those as-is.) These are all "best-effort" — if S3 is briefly unreachable, the delete still succeeds, it just won't retry the S3 cleanup, matching how the existing ad-delete code already worked.

## Pending — deployment (next)

Nothing above is live on the server yet — it's all in the local repo, ready to push:

1. **App server** (`claimit.service`) — pagination, Claim Your Business, Learn Claimit API, S3 clean-up fixes (shops, claims, bill reviews, classifieds).
2. **Website server** (`claimit_web.service`) — Learn Claimit admin API, S3 clean-up fixes (shops, category images, gallery photos).
3. **Website** — rebuild and redeploy the frontend for the new "Learn Claimit" admin page.
4. **App** — rebuild for the Featured Zones fixes, new icons, Claim Your Business, and Learn Claimit screens.

Also still outstanding from the server incident review (not urgent, but worth scheduling):
- Disable/review unattended OS updates on the server (the actual root cause of today's outage risk).
- Set up automated database backups + rotation.
- Set up uptime monitoring/alerting for both backends.

Thanks,
[Your name]
