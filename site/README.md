# VitalLoop GitHub Pages

This folder is the static website for App Store review materials.

Expected privacy policy URL after GitHub Pages is enabled:

```text
https://jhb175.github.io/vitalloop/privacy-policy.html
```

Expected marketing and support URLs:

```text
https://jhb175.github.io/vitalloop/
https://jhb175.github.io/vitalloop/support.html
```

If your GitHub username or repository name is different, update:

- `site/README.md`
- `BodyCoachApp/Shared/AppPrivacyLinks.swift`
- `docs/app-store-release-checklist.md`
- App Store Connect Privacy Policy URL

## GitHub Pages Setup

1. Push this project to a GitHub repository named `vitalloop`.
2. In GitHub, open `Settings` > `Pages`.
3. Set source to `GitHub Actions`.
4. The workflow in `.github/workflows/pages.yml` will publish the `site/` folder.
5. Open the URL above and confirm the page is public before App Store submission.

Current app privacy policy URL:

```text
https://jhb175.github.io/vitalloop/privacy-policy.html
```

Use the same support, marketing, and privacy URLs in App Store Connect before submission.
