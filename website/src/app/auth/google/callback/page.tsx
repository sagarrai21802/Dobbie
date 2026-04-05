'use client';

import { Suspense, useEffect, useState } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import apiClient from '@/lib/api';

function GoogleCallbackContent() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const [status, setStatus] = useState<'loading' | 'success' | 'error'>('loading');
  
  useEffect(() => {
    const token = searchParams.get('token');
    const refresh = searchParams.get('refresh');
    const error = searchParams.get('error');
    
    if (error) {
      setStatus('error');
      setTimeout(() => {
        router.push(`/auth/signin?error=${encodeURIComponent(error)}`);
      }, 2000);
      return;
    }
    
    if (token && refresh) {
      // Store tokens using the API client
      apiClient.setTokens(token, refresh);
      setStatus('success');
      setTimeout(() => {
        router.push('/');
      }, 1000);
    } else {
      setStatus('error');
      setTimeout(() => {
        router.push('/auth/signin');
      }, 2000);
    }
  }, [searchParams, router]);

  return (
    <div className="min-h-screen bg-[var(--background)] flex items-center justify-center">
      <div className="text-center">
        {status === 'loading' && (
          <>
            <div className="w-8 h-8 border-4 border-[var(--primary)] border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
            <p className="text-[var(--foreground)]">Completing sign in...</p>
          </>
        )}
        {status === 'success' && (
          <>
            <div className="w-8 h-8 border-4 border-[var(--cta)] border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
            <p className="text-[var(--foreground)]">Sign in successful!</p>
          </>
        )}
        {status === 'error' && (
          <>
            <div className="w-8 h-8 border-4 border-[var(--error)] border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
            <p className="text-[var(--error)]">Sign in failed. Redirecting...</p>
          </>
        )}
      </div>
    </div>
  );
}

export default function GoogleCallbackPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-[var(--background)] flex items-center justify-center">
        <div className="text-center">
          <div className="w-8 h-8 border-4 border-[var(--primary)] border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-[var(--foreground)]">Loading...</p>
        </div>
      </div>
    }>
      <GoogleCallbackContent />
    </Suspense>
  );
}
