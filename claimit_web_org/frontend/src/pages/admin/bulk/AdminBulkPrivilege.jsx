// Admin → Claimit Privilege bulk upload.
//
// This already existed, but only as a tab buried inside the Privilege
// partner-management screen, with no category-image pool at all. It is now a
// page of its own with the same four steps as the other three features.
import api from '../../../utils/api'
import FeatureBulkPage from './FeatureBulkPage'

export default function AdminBulkPrivilege() {
  return <FeatureBulkPage cfg={{
    scope:        'privilege',
    label:        'Claimit Privilege',
    blurb:        'Add many privilege partners at once — hotels, clinics, salons, showrooms.',
    titleCol:     'name',
    requiredCols: 'name, category, discount_percent and a 6-digit pincode are required.',
    templateFile: 'claimit_privilege_template.xlsx',
    imageFolder:  'privilege/images',
    getTemplate:  () => api.admin.privilegeTemplate(),
    doUpload:     (payload, replace) => api.admin.privilegeBulkUpload(payload, replace),
    replaceNote:  'this clears ALL privilege partners, including any added by hand',
  }} />
}
