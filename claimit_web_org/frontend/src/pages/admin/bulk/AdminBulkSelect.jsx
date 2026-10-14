// Admin → Claimit Select bulk upload. Config only; the page is FeatureBulkPage.
import api from '../../../utils/api'
import FeatureBulkPage from './FeatureBulkPage'

export default function AdminBulkSelect() {
  return <FeatureBulkPage cfg={{
    scope:        'select',
    label:        'Claimit Select',
    blurb:        'Add many professionals at once — doctors, lawyers, architects, consultants.',
    titleCol:     'name',
    requiredCols: 'name, category and phone are required.',
    templateFile: 'claimit_select_template.xlsx',
    imageFolder:  'select/images',
    getTemplate:  () => api.admin.downloadSelectTemplate(),
    doUpload:     (payload, replace) => api.admin.bulkUploadSelect(payload, replace),
    replaceNote:  'professionals who registered themselves are never touched',
  }} />
}
