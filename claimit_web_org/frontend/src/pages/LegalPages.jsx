// Public Privacy Policy / Terms & Conditions / Support pages.
//
// These are the canonical, publicly-reachable pages — the URL submitted to
// Google Play Console (Settings → App content → Privacy Policy) should point
// here, e.g. https://www.claimitapp.in/privacy-policy. The Claimit mobile app
// shows the same content natively (see claimitapporg/lib/core/constants/
// legal_content.dart) — keep both copies in sync if you edit the source text.

const SUPPORT_EMAIL = 'support@claimitapp.in'
const MERCHANT_EMAIL = 'merchant@claimitapp.in'
const ADVERTISING_EMAIL = 'advertising@claimitapp.in'
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

Claimit is a hyper-local rewards, discounts, cashback, advertising, and classifieds platform connecting customers with participating businesses through mobile and digital services.

This Privacy Policy explains how Claimit collects, uses, stores, and protects user information while using the Claimit mobile application, website, and related services.

By using Claimit, you agree to the collection and use of information in accordance with this Privacy Policy.`],
  ['2. Information We Collect',
    `A. Personal Information — name, mobile number, email address, gender, date of birth, location details, referral information, device information.

B. Location Information — Claimit uses location services to show nearby offers and businesses, provide nearby deals and notifications, improve local search results, and validate reward and redemption transactions. Users may disable location access, but certain services may not function properly.

C. Transaction Information — scanned bill data, merchant details, transaction amount, date and time of transaction, reward and cashback records.

D. Device & Technical Information — device model, operating system, IP address, app usage information, crash and analytics data.`],
  ['2A. App Permissions',
    `To provide certain features, Claimit may request access to:
• Camera — for bill scanning and OCR processing
• Photos / Media Storage — for uploading bill images
• Location Services — for displaying nearby merchants, offers, and notifications
• Notifications — for transaction alerts, rewards, cashback updates, and promotional communications

Users may control these permissions through their device settings. Certain app features may not function correctly if permissions are disabled.`],
  ['3. How We Use Information',
    `We use collected information to create and manage user accounts; provide rewards, cashback, and redemption services; process scanned bills; verify transactions; improve app functionality; send notifications and alerts; display nearby deals and advertisements; provide customer support; prevent fraud and misuse; and comply with legal obligations.`],
  ['4. Rewards & Cashback',
    `Reward points and cashback are promotional benefits provided through Claimit and participating merchants. They may be subject to verification, transaction validation, merchant eligibility, promotional conditions, and fraud prevention checks. Claimit reserves the right to review, modify, delay, or cancel rewards in cases of suspected misuse or policy violations.`],
  ['5. Bill Scanning & OCR',
    `Claimit may use OCR (Optical Character Recognition) technology to process bills submitted by users. Users agree that uploaded bills are genuine, duplicate or manipulated bills are prohibited, and fraudulent submissions may lead to account suspension. Bill data may be temporarily stored for verification, analytics, and fraud prevention purposes.`],
  ['6. Sharing of Information',
    `Claimit does not sell personal user information. Information may be shared with participating merchants, service providers, payment and notification partners, analytics providers, and legal authorities when required. Only necessary information required for service delivery will be shared.`],
  ['7. Notifications & Communications',
    `Users may receive transaction alerts, reward notifications, nearby deals, promotional offers, app updates, and service-related communications. Users may manage notification preferences within the app.`],
  ['8. Data Security',
    `Claimit uses reasonable technical and administrative measures to protect user information. However, no digital platform can guarantee absolute security. Users are responsible for maintaining the confidentiality of their login and device access.`],
  ['8A. Data Retention',
    `Claimit retains user information only for as long as necessary to provide platform services, process rewards and cashback, verify transactions, prevent fraud and misuse, comply with legal obligations, and resolve disputes. Data may be deleted, anonymised, or archived when no longer required for these purposes.`],
  ['9. User Responsibilities',
    `Users agree not to upload fake or manipulated bills; misuse rewards or cashback systems; engage in fraudulent activities; misuse classifieds or advertisements; or violate applicable laws. Claimit may suspend or terminate accounts for violations.`],
  ['9A. Account Deletion',
    `Users may request account deletion through the Claimit application or by contacting ${SUPPORT_EMAIL}. Upon verification, Claimit will delete or anonymize personal information, except where retention is required for legal compliance, fraud prevention, dispute resolution, or financial record keeping. Certain transaction records may be retained where required by applicable laws.`],
  ['10. Third-Party Services',
    `Claimit may use third-party services including maps and location services, notification providers, payment gateways, analytics tools, OCR services, and advertising services. These services may operate under their own policies and terms.`],
  ["11. Children's Privacy",
    `Claimit services are not intended for users below the legally permitted age under applicable laws.`],
  ['12. Policy Updates',
    `Claimit may update this Privacy Policy from time to time. Updated policies will be posted within the app or website. Continued use of Claimit constitutes acceptance of updated policies.`],
  ['13. Governing Law',
    `Any disputes arising out of these Terms shall be subject to the exclusive jurisdiction of the courts located in Chennai, Tamil Nadu, India.`],
  ['14. Contact Us',
    `For privacy-related concerns:
Email: ${SUPPORT_EMAIL}
Website: ${WEBSITE}`],
]

const termsSections = [
  ['1. Acceptance of Terms',
    `By downloading, accessing, or using Claimit, users agree to comply with these Terms & Conditions. If users do not agree, they should discontinue use of the platform.`],
  ['2. About Claimit',
    `Claimit is a hyper-local digital platform offering rewards, cashback, merchant discounts, nearby deals, advertising services, and local classifieds. Claimit acts as a technology platform connecting customers and participating businesses.`],
  ['3. User Eligibility',
    `Users must provide accurate information during registration and are responsible for maintaining account confidentiality and device security. Claimit is intended only for users who are at least 18 years of age, or the minimum age permitted under applicable laws.`],
  ['4. Reward Zone Terms',
    `At participating Reward Zone businesses, users may receive reward points based on eligible bill values and cashback based on promotional terms. Rewards are subject to verification and approval. Claimit reserves the right to modify or discontinue reward programs.`],
  ['4A. Reward Point Disclaimer',
    `Reward Points provided through Claimit are promotional loyalty benefits. They do not constitute cash, are not legal tender, are not transferable unless specifically permitted, and cannot be exchanged for money except through approved platform promotions. Claimit reserves the right to modify, suspend, or discontinue reward programs at its discretion.`],
  ['5. Redeem Zone Terms',
    `At participating Redeem Zone businesses, merchants independently decide discount percentages, discounts are subject to merchant participation and validity, and customers must present valid Claimit eligibility screens where applicable. Claimit is not responsible for merchant refusal outside agreed platform conditions.`],
  ['6. Cashback Terms',
    `Cashback may require minimum thresholds, require account verification, be credited to wallets before transfer, or be modified under promotional campaigns. Claimit reserves the right to investigate suspicious activity before cashback release.`],
  ['7. Bill Submission Rules',
    `Users agree not to upload duplicate bills, manipulate or edit bills, or submit fake transactions. Fraudulent activity may result in cancellation of rewards, account suspension, permanent ban, and/or legal action where applicable.`],
  ['8. Merchant Listings & Advertisements',
    `Businesses are responsible for the accuracy of offers, descriptions, pricing, contact details, and advertisements. Claimit does not guarantee merchant products or services.`],
  ['9. Nearby Deals & Notifications',
    `Nearby deals and notifications may depend on location access, user preferences, merchant participation, and availability. Claimit does not guarantee continuous availability of offers.`],
  ['10. Local Classifieds',
    `Users are solely responsible for transactions conducted through classifieds. Claimit is not responsible for product quality, delivery disputes, payment disputes, or third-party transactions. Users are advised to verify independently before transactions.`],
  ['11. Intellectual Property',
    `All Claimit branding, logos, software, content, and designs are protected intellectual property. Unauthorized copying or misuse is prohibited.`],
  ['12. Limitation of Liability',
    `Claimit shall not be liable for merchant disputes, service interruptions, indirect losses, technical issues, third-party failures, or unauthorized access beyond reasonable control.`],
  ['13. Account Suspension',
    `Claimit reserves the right to suspend or terminate accounts for fraudulent activity, misuse of rewards, abusive behaviour, or policy violations.`],
  ['14. Changes to Terms',
    `Claimit may modify these Terms & Conditions at any time. Updated terms will be published through the app or website.`],
  ['15. Governing Law',
    `Any disputes arising out of these Terms shall be subject to the exclusive jurisdiction of the courts located in Chennai, Tamil Nadu, India.`],
  ['16. Contact Information',
    `For Terms and Conditions-related concerns:
Email: ${SUPPORT_EMAIL}
Website: ${WEBSITE}`],
  ['Merchant Terms & Conditions',
    `By registering as a Claimit Affiliate Merchant, the merchant agrees to comply with these Terms & Conditions and all applicable Claimit policies.

Merchant Registration — Merchants must provide accurate and complete information (business name, contact information, address, business category, promotional details, and other requested information) and keep it updated.

Reward Zone Participation — Customers may receive Reward Points and cashback based on platform rules, which Claimit may modify from time to time.

Redeem Zone Participation — Merchants determine discount percentages; approved discounts will be honoured during the validity period and merchants shall not unfairly deny valid Claimit redemptions.

Merchant Listings — Merchants authorize Claimit to display their business name, address, contact details, description, images, GPS location, and promotional information on the platform and in related marketing materials.

Merchant Responsibilities — Merchants are solely responsible for product/service quality, pricing, warranties, customer interactions, and compliance with applicable laws. Claimit acts only as a technology platform and does not guarantee merchant products or services.

Cashback & Rewards Verification — Claimit may validate transactions, review reward claims, investigate suspicious activities, and delay, modify, or reject rewards where fraud or misuse is suspected.

Subscription Fees & Refunds — Merchant subscriptions, renewals, and promotional plans may be subject to fees, which are generally non-refundable unless otherwise specified by Claimit in writing.

Merchant Conduct — Merchants agree not to provide misleading information, manipulate transactions, create fake purchases, abuse reward systems, or engage in fraudulent activities.

Suspension & Termination — Claimit may suspend or terminate merchant participation for fraudulent activity, policy violations, misrepresentation, or abuse of platform services.

Limitation of Liability — Claimit shall not be liable for business losses, customer disputes, service interruptions, third-party failures, or promotional performance outcomes. Cashback balances do not constitute bank deposits and do not earn interest.

Force Majeure — Claimit shall not be liable for delays or failures caused by events beyond its reasonable control, including internet outages, government actions, natural disasters, technical failures, or third-party service interruptions.

Merchant Support: ${MERCHANT_EMAIL} · ${WEBSITE}`],
  ['Advertising Terms & Conditions',
    `Claimit provides advertising opportunities through Home Page Advertisements, Nearby Deals, Brand Deals, Promo Reelz, Local Classified Listings, Promotional Notifications, and other future advertising formats.

Advertiser Responsibilities — Advertisers must ensure all submitted content is accurate, lawful, non-misleading, and appropriate for public display. Prohibited content includes illegal products or services, fraudulent schemes, misleading claims, offensive or abusive content, copyright-infringing content, and content violating applicable laws. Claimit reserves the right to reject or remove any advertisement.

Approval & Placement — All advertisements are subject to review and approval before publication. Placement may depend on the selected advertising format, target pincode, slot availability, and campaign schedule; Claimit does not guarantee exclusive placement unless specifically agreed.

Performance — Claimit does not guarantee sales, leads, clicks, customer visits, or conversion rates; results may vary based on campaign quality, audience response, and market conditions.

Fees & Refunds — Advertising fees are payable according to the selected campaign package; campaigns may commence only after payment confirmation. Advertising fees are generally non-refundable once a campaign has been approved or published, except where required by applicable law.

Modification, Cancellation & Termination — Claimit may modify advertisement schedules, suspend campaigns, or remove advertisements that violate policies, and may suspend or terminate advertising accounts for policy violations, fraudulent activity, non-payment, or misrepresentation.

Intellectual Property — Advertisers confirm they own or are authorized to use all submitted content (images, videos, logos, text, and promotional materials).

Limitation of Liability — Claimit shall not be liable for campaign performance, business losses, third-party actions, technical interruptions, or user behaviour.

Governing Law — Any disputes arising out of these Terms shall be subject to the exclusive jurisdiction of the courts located in Chennai, Tamil Nadu, India.

Advertising Support: ${ADVERTISING_EMAIL} · ${WEBSITE}`],
]

const supportSections = [
  ['Need Help?',
    `We are here to help you with your Claimit experience. Contact our support team for help with: rewards and cashback, bill scanning issues, merchant offers, account access, notifications, wallet queries, technical support, and classified listings.`],
  ['Customer Support',
    `Website: ${WEBSITE}
Support Email: ${SUPPORT_EMAIL}

Support Hours
Monday – Saturday, 9:30 AM – 6:30 PM IST`],
  ['Merchant Support',
    `For merchant onboarding, advertising, Redeem Zone affiliation, and business promotions:
Email: ${MERCHANT_EMAIL}`],
  ['Technical Support',
    `For app-related technical issues such as login problems, OTP issues, bill scan errors, wallet update delays, and app crashes:
Email: ${SUPPORT_EMAIL}
Website: ${WEBSITE}`],
]

const refundSections = [
  ['Overview',
    `This Refund Policy explains when amounts paid through Claimit — by customers, merchants, and advertisers — may or may not be refunded. It should be read together with our Terms & Conditions.`],
  ['Rewards, Cashback & Wallet Balances',
    `Reward Points and cashback are promotional loyalty benefits, not cash or legal tender, and are not refundable or exchangeable for money except through approved platform promotions. Wallet/cashback balances do not constitute bank deposits and do not earn interest. Cashback may be delayed, modified, or withheld pending verification, transaction validation, or fraud-prevention checks, in line with our Terms & Conditions.`],
  ['Merchant Subscription & Promotional Fees',
    `Merchant subscriptions, renewals, listing fees, and promotional plan charges are generally non-refundable, unless otherwise specified by Claimit in writing. Where Claimit agrees to a refund (e.g. a duplicate charge or a service that was never activated), it will be processed to the original payment method within a reasonable time after approval.`],
  ['Advertising Fees',
    `Advertising fees are generally non-refundable once a campaign has been approved or published, except where required by applicable law. Campaigns may commence only after payment confirmation, and cancellations requested before a campaign goes live may be considered on a case-by-case basis.`],
  ['Failed or Duplicate Payments',
    `If a payment is debited but the corresponding service (subscription, promotion, or in-app purchase) is not activated due to a technical error, or the same amount is charged more than once, please contact support with your transaction details. Verified failed or duplicate transactions will be refunded to the original payment method, typically within 7–10 business days of confirmation.`],
  ['How to Request a Refund',
    `Email ${SUPPORT_EMAIL} (merchants/advertisers may also write to ${MERCHANT_EMAIL} or ${ADVERTISING_EMAIL}) with your registered mobile number/email, transaction ID or order reference, date of payment, and the reason for the request. Claimit may ask for additional information to verify the claim before approving any refund.`],
  ['Force Majeure',
    `Claimit shall not be liable for delays or failures in providing services or processing refunds caused by events beyond its reasonable control, including internet outages, government actions, natural disasters, technical failures, or third-party service interruptions (e.g. payment gateway delays).`],
  ['Changes to this Policy',
    `Claimit may update this Refund Policy from time to time. Updated versions will be posted within the app or on the website, and continued use of Claimit constitutes acceptance of the updated policy.`],
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
