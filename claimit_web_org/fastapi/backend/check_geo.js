// Read-only check: did the geo backfill + 2dsphere index actually land?
// Run with:  mongosh --quiet claimit_db check_geo.js
var withLatLng = db.shops.countDocuments({ lat: { $ne: null }, lng: { $ne: null } });
var withGeo = db.shops.countDocuments({ geo: { $exists: true } });
var geoIndexes = db.shops.getIndexes().filter(function (i) { return i.name.indexOf("geo") !== -1; });

print("shops with lat/lng : " + withLatLng);
print("shops with geo     : " + withGeo);
print("geo indexes        : " + JSON.stringify(geoIndexes));
