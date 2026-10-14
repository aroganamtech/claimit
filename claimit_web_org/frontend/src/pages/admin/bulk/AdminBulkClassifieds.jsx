// Admin → Local Classifieds bulk upload. See AdminBulkLocalFinder for why
// these are two separate pages rather than one with a picker.
import api from '../../../utils/api'
import FeatureBulkPage from './FeatureBulkPage'

export default function AdminBulkClassifieds() {
  return <FeatureBulkPage cfg={{
    scope:        'classified',
    label:        'Local Classifieds',
    blurb:        'Item and service posts — things people buy, sell or offer.',
    titleCol:     'title',
    requiredCols: 'title, category and phone are required.',
    templateFile: 'claimit_classifieds_template.xlsx',
    imageFolder:  'classified/images',
    getTemplate:  () => api.admin.downloadClassifiedsTemplate('classified'),
    doUpload:     (payload, replace) =>
                    api.admin.bulkUploadClassifieds(payload, 'classified', replace),
    replaceNote:  'ads people posted themselves, and all Local Finder listings, are never touched',
  }} />
}
