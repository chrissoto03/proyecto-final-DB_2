'use strict';
// SQL datetime stores business wall-clock time, not an instant. The UTC fields
// of this transport Date must match that value; never use the host timezone.
// Z is accepted for existing clients that serialize SQL values as ISO strings.
function readBusinessDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,3})?)?Z?$/.test(value)) return null;
  let local = value.replace(/Z$/, '');
  if (local.length === 16) local += ':00';
  const date = new Date(local + 'Z');
  if (!Number.isFinite(date.getTime()) || date.getUTCFullYear() < 1753 || date.toISOString().slice(0,19) !== local.slice(0,19)) return null;
  return date;
}
module.exports = { readBusinessDate };
