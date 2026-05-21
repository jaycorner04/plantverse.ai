# PlantVerse Scan Accuracy Harness

Put real test photos in `test/scan_accuracy/images/` using the filenames in
`manifest.json`, then run:

```powershell
.\scripts\run_scan_accuracy.ps1
```

The script sends each image to the configured backend, checks the returned
common/scientific name plus candidate matches, and fails when the expected plant
is missing or confidence is below the manifest threshold.

Use `-Strict` when preparing a release so missing images fail the run.
