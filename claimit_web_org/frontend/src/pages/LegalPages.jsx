// Public Privacy Policy / Terms & Conditions / Support pages.
//
// These are the canonical, publicly-reachable pages — the URL submitted to
// Google Play Console (Settings → App content → Privacy Policy) should point
// here, e.g. https://www.claimitapp.in/privacy-policy. The Claimit mobile app
// shows the same content natively (see claimitapporg/lib/core/constants/
// legal_content.dart) — keep both copies in sync if you edit the source text.

const SUPPORT_EMAIL = 'support@claimitapp.in'
const WEBSITE = 'www.claimitapp.in'
const EFFECTIVE_DATE = 'Effective Date: June 2026'

const styles = {
  page: { minHeight: '100vh', paddingTop: 64, background: '#fff' },
  header: { textAlign: 'center', padding: '48px 32px 24px' },
  title: { fontSize: 32, fontWeight: 700, color: '#1565C0', marginBottom: 8 },
  meta: { fontSize: 14, color: '#6b7280' },
  container: { maxWidth: 800, margin: '0 auto', padding: '0 32px 80px' },
  heading: { fontSize: 19, fontWeight: 700, color: '#1A1A2E', marginTop: 32, marginBottom: 10 },
  body: { fontSize: 15.5, color: '#374151', lineHeight: 1.7, whiteSpace: 'pre-line' },
}

function LegalLayout({ title, subtitle, sections }) {
  return (
    <div style={styles.page}>
      <div style={styles.header}>
        <h1 style={styles.title}>{title}</h1>
        <p style={styles.meta}>{subtitle || EFFECTIVE_DATE} · Claimit Mobile Application &amp; Website · Verso AI</p>
      </div>
      <div style={styles.container}>
        {sections.map(([heading, body]) => (
          <section key={heading}>
            <h2 style={styles.heading}>{heading}</h2>
            <p style={styles.body}>{body}</p>
          </section>
        ))}
      </div>
    </div>
  )
}

const privacySections = [
  ['1. Introduction',
    `Welcome to Claimit.

Claimit is an insurance policy and claims management platform that helps users keep track of their health, motor, life, travel, and other insurance policies, and submit, track, and manage insurance claims in one place.

This Privacy Policy explains how Claimit collects, uses, stores, and protects user information while using the Claimit mobile application, website, and related services.

By using Claimit, you agree to the collection and use of information in accordance with this Privacy Policy.`],
  ['2. Information We Collect',
    `A. Personal Information — full name, email address, mobile number, date of birth, residential address, city, state, and pincode.

B. Identity Verification Information — with your consent, government-issued identity information such as your Aadhaar number and PAN number, collected only where needed to verify your identity for a specific insurance claim or policy request (see "4. Identity Verification & Sensitive Information" below).

C. Insurance Policy & Claims Information — policy number, policy type, insurer name, premium amount, sum insured, coverage details, policy start/end dates, claim number, claim type, incident date and description, claimed amount, claim status, approved amount, rejection reason, and related claim history.

D. Documents & Photos — photos and scans of policy documents, claim documents, supporting evidence, and identity proofs captured or uploaded via the camera, gallery, or file picker, including data extracted from these documents using on-device text recognition (OCR) to help pre-fill forms. An optional profile photo.

E. Location Information (optional) — with your permission, Claimit may access your approximate or precise location to help you select your area/locality (for example, via GPS-based address lookup) or to record where an insured incident occurred. You may deny or revoke location access at any time in your device settings.

F. Voice Input (optional) — if you use the microphone/voice-search feature, your speech is converted to text using your device's speech-recognition service; Claimit does not store the audio recording itself.

G. Login & Account Information — the mobile number or email address used for OTP-based login, and — if you choose to sign in with Google or Facebook — the name, email address, and profile identifier shared by that provider.

H. Device & Technical Information — device model, operating system, IP address, app version, push-notification token, crash logs, and basic usage/analytics data.`],
  ['2A. App Permissions',
    `To provide certain features, Claimit may request access to:
• Camera — to scan or photograph policy and claim documents
• Photos / File Storage — to upload existing documents, images, or your profile photo
• Location — to help select your area/locality or record an incident location (optional)
• Microphone — for the in-app voice-search feature (optional)
• Notifications — for claim status updates, policy reminders, and account activity

You can manage these permissions at any time in your device settings. Some features may not work correctly if the related permission is disabled.`],
  ['3. How We Use Information',
    `We use collected information to create and manage your account; let you add, view, and manage your insurance policies; let you submit, track, and manage insurance claims; verify your identity when required for a claim; extract data from scanned documents to reduce manual entry; send claim-status and policy-reminder notifications; provide customer support; detect and prevent fraud or misuse; and comply with legal and regulatory obligations.`],
  ['4. Identity Verification & Sensitive Information',
    `Aadhaar and PAN numbers are sensitive personal information. We collect them only when you choose to provide them for identity verification connected to a policy or claim, and we do not use them for any purpose unrelated to verifying your identity or processing your policy/claim.

This information is stored using access-restricted, encrypted storage, is shared only with the insurer or claims-processing party relevant to your specific claim where that insurer requires it, and is never shared for advertising or marketing purposes. You may decline to provide this information, though doing so may limit our ability to assist with claims that require identity verification.`],
  ['5. Document Scanning & OCR',
    `Claimit may use on-device optical character recognition (OCR) to read text from photographed or uploaded policy and claim documents, so details such as the policy number or insurer name can be pre-filled instead of typed manually. You remain responsible for reviewing and correcting any auto-filled information before submitting it.

Submitting fake, altered, or duplicate documents is prohibited and may result in claim rejection and/or account suspension.`],
  ['6. Sharing of Information',
    `Claimit does not sell your personal information. We may share information: with the insurance company, third-party administrator (TPA), or claims-processing partner named on your policy, solely to process the claim or policy request you submit; with service providers who help us operate the app (cloud storage, email/SMS providers, push-notification infrastructure); with Google or Facebook only to the extent needed to authenticate you if you choose those sign-in methods; and with legal or regulatory authorities where required by law.`],
  ['7. Notifications & Communications',
    `You may receive notifications about claim status changes, policy reminders, OTP codes, account security alerts, and service-related updates. You can manage notification preferences in your device settings.`],
  ['8. Data Security',
    `Claimit uses reasonable technical and administrative safeguards — including encrypted storage and access controls — to protect your information. However, no digital platform can guarantee absolute security. You are responsible for keeping your login credentials and device secure.`],
  ['8A. Data Retention',
    `We retain your information for as long as your account is active and as necessary to provide policy and claims-management services, resolve disputes, and meet legal or regulatory record-keeping requirements — which can require retaining certain claim records for a number of years even after a claim is closed. Data no longer needed for these purposes is deleted or anonymised.`],
  ['9. User Responsibilities',
    `You agree to provide accurate information about yourself, your policies, and your claims; not upload fake, altered, or duplicate documents; not impersonate another person or misuse another person's policy or identity information; and comply with applicable laws. Claimit may suspend or terminate accounts that violate these responsibilities.`],
  ['9A. Account Deletion',
    `You may request account deletion through the app or by contacting ${SUPPORT_EMAIL}. Upon verification, we will delete or anonymize your personal information, except where retention is required for legal compliance, an open or disputed claim, fraud prevention, or record-keeping obligations.`],
  ['10. Third-Party Services',
    `Claimit uses third-party services to operate, including Google Sign-In and Facebook Login (authentication), Firebase Cloud Messaging (push notifications), cloud storage providers (document and image storage), and email/SMS providers (OTP delivery). These providers process data under their own privacy policies in addition to this one.`],
  ["11. Children's Privacy",
    `Claimit is not intended for use by individuals below the legally permitted age under applicable law, or below 18 years of age, whichever is lower.`],
  ['12. Policy Updates',
    `We may update this Privacy Policy from time to time. Updated versions will be posted within the app and on our website. Continued use of Claimit after an update constitutes acceptance of the revised policy.`],
  ['13. Governing Law',
    `Any disputes arising out of this Privacy Policy shall be subject to the exclusive jurisdiction of the courts located in Chennai, Tamil Nadu, India.`],
  ['14. Contact Us',
    `For privacy-related concerns:
Email: ${SUPPORT_EMAIL}
Website: ${WEBSITE}`],
]

const termsSections = [
  ['1. Acceptance of Terms',
    `By downloading, accessing, or using Claimit, you agree to comply with these Terms & Conditions. If you do not agree, please discontinue use of the app.`],
  ['2. About Claimit',
    `Claimit is a policy and claims management platform that helps you organise your insurance policies and submit, track, and manage insurance claims. Claimit is not an insurance company, insurance broker, or underwriter; it does not issue or sell insurance policies; and it does not decide whether a claim is approved or rejected — those decisions are made solely by the relevant insurer or claims-processing party. Claimit only helps you record policy details and submit or track claim information.`],
  ['3. User Eligibility',
    `You must be at least 18 years of age, or the minimum age permitted under applicable law, to create an account. You must provide accurate information during registration and are responsible for maintaining the confidentiality of your account and device.`],
  ['4. Accuracy of Policy & Claims Information',
    `You are solely responsible for the accuracy of the policy and claim information you enter or upload, including policy numbers, insurer details, incident descriptions, claimed amounts, and supporting documents. Claimit does not independently verify this information with insurers unless explicitly stated.`],
  ['5. Identity Verification',
    `Where a claim or policy action requires identity verification, you may be asked to voluntarily provide identity details such as Aadhaar or PAN information. You confirm that any identity information you provide is your own and accurate.`],
  ['6. Document Submission Rules',
    `You agree not to upload fake, altered, duplicated, or fraudulently obtained documents. Fraudulent submissions may result in claim rejection, account suspension, and reporting to the relevant insurer or, where applicable, law-enforcement authorities.`],
  ['7. Claim Processing & Outcomes',
    `Claimit facilitates the submission and tracking of claims but does not control, guarantee, or influence the decision, timeline, or amount approved by the insurer or claims-processing party. Any claim status, approval, rejection, or settlement amount shown in the app reflects information provided by, or obtained from, the relevant insurer and is subject to that insurer's own policies and terms.`],
  ['8. Third-Party Sign-In',
    `If you sign in using Google or Facebook, you authorize Claimit to receive your basic profile information (name and email address) from that provider for the purpose of creating and authenticating your account.`],
  ['9. Intellectual Property',
    `All Claimit branding, logos, software, content, and design are protected intellectual property. Unauthorized copying, reproduction, or misuse is prohibited.`],
  ['10. Limitation of Liability',
    `Claimit is not liable for decisions made by insurers or claims-processing parties, delays in claim settlement, inaccuracies in information provided by you or by an insurer, service interruptions, or losses arising from unauthorized account access beyond our reasonable control.`],
  ['11. Account Suspension',
    `Claimit reserves the right to suspend or terminate accounts found to be engaged in fraudulent activity, submission of false documents, misuse of the platform, or violation of these Terms.`],
  ['12. Changes to Terms',
    `Claimit may modify these Terms & Conditions at any time. Updated terms will be published within the app or on our website.`],
  ['13. Governing Law',
    `Any disputes arising out of these Terms shall be subject to the exclusive jurisdiction of the courts located in Chennai, Tamil Nadu, India.`],
  ['14. Contact Information',
    `For Terms and Conditions-related concerns:
Email: ${SUPPORT_EMAIL}
Website: ${WEBSITE}`],
]

const supportSections = [
  ['Need Help?',
    `We're here to help with your Claimit experience — adding or managing policies, submitting and tracking claims, document upload or scanning issues, login/OTP problems, and notifications.`],
  ['Customer Support',
    `Website: ${WEBSITE}
Support Email: ${SUPPORT_EMAIL}

Support Hours
Monday – Saturday, 9:30 AM – 6:30 PM IST`],
  ['Claims & Policy Support',
    `For help adding a policy, submitting a claim, or understanding a claim's status:
Email: ${SUPPORT_EMAIL}`],
  ['Technical Support',
    `For app-related issues such as login problems, OTP issues, document scan errors, or app crashes:
Email: ${SUPPORT_EMAIL}
Website: ${WEBSITE}`],
]

const refundSections = [
  ['Overview',
    `${EFFECTIVE_DATE}

Claimit is a free policy and claims management tool. We do not charge any fee to add policies, submit claims, or use the app's core features, and we do not process insurance premium payments on behalf of any insurer through the app. This Refund Policy explains how the limited cases below — and any paid features introduced in the future — would be handled.`],
  ['Insurance Premiums',
    `Any insurance premium you pay is paid directly to your insurer through that insurer's own official channels, not through Claimit. Refunds, cancellations, or premium disputes must be raised directly with your insurer in accordance with its policies — Claimit has no role in collecting, holding, or refunding premium payments.`],
  ['Future Paid Features',
    `If Claimit introduces a paid feature, subscription, or add-on service in the future, the applicable refund terms will be published here and within the app before you are charged.`],
  ['Failed or Duplicate Payments',
    `If, after a paid feature is introduced, a payment is debited but the corresponding service is not activated due to a technical error, or you are charged more than once for the same item, contact support with your transaction details. Verified failed or duplicate charges will be refunded to the original payment method within a reasonable time.`],
  ['How to Request a Refund',
    `Email ${SUPPORT_EMAIL} with your registered mobile number/email, transaction ID (if any), date of payment, and the reason for your request.`],
  ['Changes to this Policy',
    `We may update this Refund Policy from time to time. Updated versions will be posted within the app and on our website.`],
  ['Governing Law',
    `Any disputes arising out of this Refund Policy shall be subject to the exclusive jurisdiction of the courts located in Chennai, Tamil Nadu, India.`],
  ['Contact Us',
    `For refund-related concerns:
Email: ${SUPPORT_EMAIL}
Website: ${WEBSITE}`],
]

export function RefundPolicy() {
  return <LegalLayout title="Refund Policy" sections={refundSections} />
}

export function PrivacyPolicy() {
  return <LegalLayout title="Privacy Policy" sections={privacySections} />
}

export function Terms() {
  return <LegalLayout title="Terms & Conditions" sections={termsSections} />
}

export function Support() {
  return <LegalLayout title="Help & Support" subtitle="We usually reply within 1 business day." sections={supportSections} />
}
