<!-- Created: 2026-07-16 18:54 (WEST) · Updated: 2026-07-16 18:54 (WEST) -->
# App Store Connect submission playbook — B3 / B4 / B5 / H2 / H3

Owner-executed paperwork. Everything here happens in App Store Connect (ASC) or on squirl.pt — none of it is code. Prepared answers are grounded in the shipping binary as audited 2026-07-16 (no data collection, on-device processing, 3 named ADHD stimulants with typical SmPC values, disclaimer UI added on `fix/app-store-readiness`).

---

## B3 — Regulated medical device declaration (blocks new-app submission)

Required since 2026-03-26 for any app whose primary/secondary category is Health & Fitness or Medical, or whose age-rating answers flag frequent Medical/Treatment references. Source: [developer.apple.com/news/?id=nyqbfz1y](https://developer.apple.com/news/?id=nyqbfz1y).

**Where:** ASC ▸ App ▸ App Information ▸ Regulated Medical Device Status.

**Recommended answers:**

| Question | Answer | Why |
|---|---|---|
| Is this app a regulated medical device (EEA/UK/US)? | **No** | Squirl logs what the user says; it does not diagnose, treat, prevent, or dose-advise. Journaling/wellness apps without clinical claims are outside MDR/FDA device scope. The in-app copy now consistently frames catalog values as "typical, may differ" — keep it that way; a dosing-recommendation feature would flip this answer. |
| Contact details | support@squirl.pt | MX verified live 2026-07-16 (securemail.pro) — **create the mailbox before submitting.** |
| Safety information | Point at the in-app disclaimer + privacy policy URL | The Settings ▸ "Medication info" section is the safety statement. |

---

## B4 — EU DSA trader status (blocks EU distribution)

Required + identity-verified since 2025-02-17; non-compliant apps are removed from all 27 EU storefronts. Source: [developer.apple.com/news/?id=x60uzbu9](https://developer.apple.com/news/?id=x60uzbu9), [ASC help](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/).

**Where:** ASC ▸ Business ▸ Digital Services Act.

**Decisions to make first (the only real work):**
1. **Trader or non-trader?** Distributing a monetized or business-like app in the EU ⇒ **trader** (safe assumption for a planned commercial launch; non-trader is only for genuinely non-commercial hobby distribution).
2. **Public address:** trader status publishes **address + phone + email on the App Store product page in the EU**. As a solo dev, do not publish your home address — use a **PO box / registered business address / virtual office** (allowed). Decide this before starting verification; changing it later re-triggers verification.
3. Verification (Apple checks the details) takes days — start early.

---

## B5 — Age rating questionnaire (blocks submission until redone)

New 4+/9+/13+/16+/18+ system; every app had to re-answer by 2026-01-31. Source: [developer.apple.com/news/?id=ks775ehf](https://developer.apple.com/news/?id=ks775ehf).

**Where:** ASC ▸ App ▸ Age Rating (new questionnaire).

**Expected drivers for Squirl:**

| Topic | Honest answer | Effect |
|---|---|---|
| Medical/treatment information | **Frequent/Intense** — the app is medication-centric (catalog, dose log, dose guard) | Pushes rating up; also *triggers B3's declaration requirement* |
| Drug references | References to prescription stimulants exist but nothing promotes use | Expect **16+ or 18+** overall |
| UGC | User's own private journal — not shared/visible to others | Answer "no UGC shared with others"; no moderation apparatus needed |
| AI chatbot | **No** — on-device transcription/extraction is not a conversational assistant | Avoids the AI-assistant rating bump |
| Unrestricted web access | No | — |

PRODUCT.md already declares the audience 18+; a 16+/18+ rating is consistent with the product, not a problem. Don't shade answers downward — mismatch between rating answers and binary content is itself a rejection reason.

---

## H2 — Privacy policy + support URL (required ASC fields)

Domain status verified 2026-07-16: `squirl.pt` live (HTTP 200), MX present. `whisperhealth.app` dead (no A/MX) — the in-app support email was swapped to support@squirl.pt on `fix/app-store-readiness`.

**Owner actions:**
1. Create the **support@squirl.pt** mailbox (MX already routes).
2. Publish [PRIVACY_POLICY.md](PRIVACY_POLICY.md) at `https://squirl.pt/privacy` (review the draft first — set the effective date).
3. ASC fields: Privacy Policy URL = `https://squirl.pt/privacy`; Support URL = `https://squirl.pt` (page should mention the support email).
4. ASC ▸ App Privacy nutrition label: **"Data Not Collected"** — accurate per the 2026-07-16 egress audit (no analytics, no accounts, no upload; the only network call is the model download).

---

## H3 — App Review notes (paste into ASC ▸ App Review Information ▸ Notes)

> Squirl is a fully on-device voice journal: no account, no server, no login — no demo credentials are needed.
>
> One thing to know while testing: on first launch the app downloads its on-device speech-recognition model (~500 MB, one time, from Hugging Face's CDN) in the background. The app is fully usable immediately; a check-in recorded before the model finishes is saved with the status "Ready shortly…" and transcribes automatically once the download completes. Transcription itself runs entirely on the device (WhisperKit/CoreML) — audio never leaves the phone. Download progress is visible in Settings ▸ AI Models.
>
> The medication features are a passive log of what the user reports taking. The app provides no dosing advice or treatment recommendations; catalog values are labeled as typical product-information figures, and a medical disclaimer appears in onboarding and Settings ▸ Medication info.

Also attach: nothing. No special configuration is required.

**Residual risk to accept:** if the reviewer's network blocks/slows the Hugging Face CDN, transcription stays pending during review. The notes above are the standard mitigation; bundling the ~500 MB model in the IPA is the fallback if a rejection actually happens (bad tradeoff to pay preemptively).

---

## Order of operations

1. Create support@squirl.pt mailbox → publish privacy page (H2).
2. Start DSA trader verification (B4) — longest lead time.
3. Complete age rating questionnaire (B5) — its answers trigger B3's form.
4. Declare medical-device status = No (B3).
5. Fill App Privacy ("Data Not Collected") + Review Notes (H3).
