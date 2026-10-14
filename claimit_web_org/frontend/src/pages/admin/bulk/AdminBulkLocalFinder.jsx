// Admin → Local Finder bulk upload.
//
// Local Finder and Classifieds share one database collection and are told
// apart by listing_type. They used to share one admin page behind a product
// picker, which made it easy to upload a sheet against the wrong product.
// They are now two pages and the listing_type is fixed by the page itself.
import api from '../../../utils/api'
import FeatureBulkPage from './FeatureBulkPage'

export default function AdminBulkLocalFinder() {
  return <FeatureBulkPage cfg={{
    scope:        'local_find',
    label:        'Local Finder',
    blurb:        'Business directory listings — shops and services people browse by zone.',
    titleCol:     'business_name',
    requiredCols: 'business_name, category, phone, latitude and longitude are required.',
    templateFile: 'claimit_local_finder_template.xlsx',
    imageFolder:  'local_find/images',
    getTemplate:  () => api.admin.downloadClassifiedsTemplate('local_find'),
    doUpload:     (payload, replace) =>
                    api.admin.bulkUploadClassifieds(payload, 'local_find', replace),
    replaceNote:  'listings people posted themselves, and all Classifieds, are never touched',
  }} />
}
