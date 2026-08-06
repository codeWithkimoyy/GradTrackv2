# GradTrack Frontend

Flutter client for GradTrack. The application supports Android, web, and
Windows while sharing the existing Firebase authentication, Firestore, and
storage integrations.

```powershell
Copy-Item assets/.env.example assets/.env
flutterfire configure --project=<your-project-id>
flutter pub get
flutter run
```

See the repository root `README.md` for backend setup and security guidance.
