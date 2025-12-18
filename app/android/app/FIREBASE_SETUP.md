# Firebase Configuration Setup

## google-services.json

The `google-services.json` file is required for Firebase to work but is not tracked in Git for security reasons.

### For New Developers

1. Download `google-services.json` from the Firebase Console:
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project
   - Go to Project Settings > General
   - Scroll down to "Your apps" section
   - Click on the Android app
   - Click "Download google-services.json"

2. Place the file in: `app/android/app/google-services.json`

3. The file should already be in `.gitignore` and will not be committed

### File Location

```
app/
  android/
    app/
      google-services.json  <-- Place file here
```

### Security Note

While Firebase API keys in `google-services.json` are safe to expose (they're meant for client apps), we keep this file out of version control to:
- Avoid accidental exposure of project-specific configuration
- Allow different environments (dev/staging/prod) to use different Firebase projects
- Follow security best practices

