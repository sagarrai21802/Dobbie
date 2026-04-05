'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { authService, User } from '@/lib/auth';
import { linkedInService } from '@/lib/linkedin';
import { profileService, UserProfile } from '@/lib/profile';

export default function AccountPage() {
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [isLinkedInConnected, setIsLinkedInConnected] = useState(false);
  const [isLinkedInLoading, setIsLinkedInLoading] = useState(false);
  const [profileComplete, setProfileComplete] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const currentUser = await authService.getCurrentUser();
      if (!currentUser) {
        router.push('/auth/signin');
        return;
      }
      setUser(currentUser);

      // Check LinkedIn status
      try {
        const status = await linkedInService.getStatus();
        setIsLinkedInConnected(status.connected);
      } catch {
        const connected = await linkedInService.isConnected();
        setIsLinkedInConnected(connected);
      }

      // Check profile
      try {
        const profile = await profileService.getProfile();
        setProfileComplete(!!profile?.is_complete);
      } catch {
        setProfileComplete(false);
      }
    } catch {
      router.push('/auth/signin');
    } finally {
      setIsLoading(false);
    }
  };

  const handleLinkedInToggle = async () => {
    if (isLinkedInConnected) {
      // Disconnect
      setIsLinkedInLoading(true);
      try {
        await linkedInService.disconnect();
        setIsLinkedInConnected(false);
      } catch {
        // Handle error
      } finally {
        setIsLinkedInLoading(false);
      }
    } else {
      // Connect
      try {
        const oauthUrl = await linkedInService.getOAuthUrl();
        window.location.href = oauthUrl;
      } catch {
        // Handle error
      }
    }
  };

  const handleLogout = async () => {
    if (confirm('Are you sure you want to sign out?')) {
      await authService.logout();
      router.push('/auth/signin');
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-[var(--background)] flex items-center justify-center">
        <div className="animate-spin w-8 h-8 border-4 border-[var(--primary)] border-t-transparent rounded-full"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[var(--background)]">
      {/* Header */}
      <header className="bg-[var(--primary)] px-4 py-4 flex items-center">
        <Link href="/" className="text-white mr-4">
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </Link>
        <h1 className="text-xl font-bold text-white">Account</h1>
      </header>

      <main className="p-4 space-y-4">
        {/* User Card */}
        <div className="bg-white p-4 rounded-2xl">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-full bg-[#BAE6FD] flex items-center justify-center">
              <svg className="w-6 h-6 text-[var(--text)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
              </svg>
            </div>
            <div>
              <p className="font-semibold text-[var(--foreground)]">{user?.full_name || 'User'}</p>
              <p className="text-sm text-[var(--muted)]">{user?.email || ''}</p>
            </div>
          </div>
        </div>

        {/* Profile Completion */}
        <Link href="/personalization">
          <div className="bg-white p-4 rounded-2xl flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className={`w-10 h-10 rounded-full flex items-center justify-center ${profileComplete ? 'bg-[var(--cta)]/10' : 'bg-yellow-100'}`}>
                {profileComplete ? (
                  <svg className="w-5 h-5 text-[var(--cta)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                ) : (
                  <svg className="w-5 h-5 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                  </svg>
                )}
              </div>
              <div>
                <p className="font-semibold text-[var(--foreground)]">Profile Personalization</p>
                <p className="text-sm text-[var(--muted)]">
                  {profileComplete ? 'Complete' : 'Set up your profile'}
                </p>
              </div>
            </div>
            <svg className="w-5 h-5 text-[var(--muted)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
            </svg>
          </div>
        </Link>

        {/* LinkedIn Connection */}
        <div className="bg-white p-4 rounded-2xl flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-[#0077B5]/10 flex items-center justify-center">
              <svg className="w-5 h-5 text-[#0077B5]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
              </svg>
            </div>
            <div>
              <p className="font-semibold text-[var(--foreground)]">LinkedIn Connection</p>
              <p className="text-sm text-[var(--muted)]">
                {isLinkedInConnected ? 'Connected' : 'Not connected'}
              </p>
            </div>
          </div>
          <button
            onClick={handleLinkedInToggle}
            disabled={isLinkedInLoading}
            className={`w-12 h-6 rounded-full transition-colors ${
              isLinkedInConnected ? 'bg-[var(--cta)]' : 'bg-gray-300'
            }`}
          >
            <div className={`w-5 h-5 rounded-full bg-white shadow transform transition-transform ${
              isLinkedInConnected ? 'translate-x-6' : 'translate-x-0.5'
            }`}></div>
          </button>
        </div>

        {/* Sign Out */}
        <button
          onClick={handleLogout}
          className="w-full bg-white p-4 rounded-2xl flex items-center gap-3"
        >
          <div className="w-10 h-10 rounded-full bg-[var(--error)]/10 flex items-center justify-center">
            <svg className="w-5 h-5 text-[var(--error)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
            </svg>
          </div>
          <div className="text-left">
            <p className="font-semibold text-[var(--foreground)]">Sign Out</p>
            <p className="text-sm text-[var(--muted)]">Log out from this device</p>
          </div>
        </button>
      </main>
    </div>
  );
}