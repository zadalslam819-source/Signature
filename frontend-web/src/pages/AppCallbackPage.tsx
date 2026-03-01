// ABOUTME: Fallback page when deep links don't open the Divine app
// ABOUTME: Handles OAuth callbacks, email verification, and other app links

import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';

type Platform = 'android' | 'ios' | 'desktop';

function detectPlatform(): Platform {
  const ua = navigator.userAgent;
  if (/Android/i.test(ua)) return 'android';
  if (/iPhone|iPad|iPod/i.test(ua)) return 'ios';
  return 'desktop';
}

const APP_STORE_URL = 'https://apps.apple.com/app/divine/id6744894353';
const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=co.openvine.app';

export function AppCallbackPage() {
  const [searchParams] = useSearchParams();
  const code = searchParams.get('code');
  const [platform] = useState<Platform>(detectPlatform);
  const [triedIntent, setTriedIntent] = useState(false);

  // On Android, attempt intent:// with fallback
  useEffect(() => {
    if (platform === 'android' && code && !triedIntent) {
      setTriedIntent(true);

      // Use S.browser_fallback_url to prevent redirect loops
      // If app not installed, Android will go to Play Store instead of looping
      const fallbackUrl = encodeURIComponent(PLAY_STORE_URL);
      const intentUrl = `intent://divine.video/app/callback?code=${encodeURIComponent(code)}#Intent;scheme=https;package=co.openvine.app;S.browser_fallback_url=${fallbackUrl};end`;

      window.location.href = intentUrl;
    }
  }, [platform, code, triedIntent]);

  // Desktop users
  if (platform === 'desktop') {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center bg-background p-4">
        <div className="text-center space-y-4 max-w-md">
          <h1 className="text-2xl font-bold">Open on Your Phone</h1>
          <p className="text-muted-foreground">
            This link needs to be opened in the Divine app on your mobile device.
          </p>
          <p className="text-muted-foreground">
            If you received this link via email, open it on the phone where you have Divine installed.
          </p>
          <div className="flex gap-4 justify-center pt-4">
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="px-4 py-2 bg-primary text-primary-foreground rounded-lg font-medium hover:opacity-90 transition-opacity"
            >
              App Store
            </a>
            <a
              href={PLAY_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="px-4 py-2 bg-primary text-primary-foreground rounded-lg font-medium hover:opacity-90 transition-opacity"
            >
              Google Play
            </a>
          </div>
        </div>
      </div>
    );
  }

  // Mobile users (iOS or Android after intent attempt)
  const storeUrl = platform === 'ios' ? APP_STORE_URL : PLAY_STORE_URL;
  const storeName = platform === 'ios' ? 'App Store' : 'Google Play';

  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-background p-4">
      <div className="text-center space-y-4 max-w-md">
        <h1 className="text-2xl font-bold">Open in Divine</h1>
        <p className="text-muted-foreground">
          This link should open in the Divine app. If it didn't open automatically:
        </p>
        <ul className="text-left text-muted-foreground space-y-2 pl-4">
          <li>• Make sure Divine is installed on this device</li>
          <li>• Try opening Divine and signing in again</li>
        </ul>
        <a
          href={storeUrl}
          className="inline-block mt-4 px-6 py-2 bg-primary text-primary-foreground rounded-lg font-medium hover:opacity-90 transition-opacity"
        >
          Get Divine on {storeName}
        </a>
        <p className="text-sm text-muted-foreground pt-4">
          If you clicked a link from email, make sure you're on the same device where you registered.
        </p>
      </div>
    </div>
  );
}

export default AppCallbackPage;
