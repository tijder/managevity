// Once Flutter has painted its first frame the static text has done its job.
window.addEventListener('flutter-first-frame', function () {
  var el = document.getElementById('static-content');
  if (el) el.remove();
});
