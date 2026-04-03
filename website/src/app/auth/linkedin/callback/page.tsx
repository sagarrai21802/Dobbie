'use client';

import { Suspense, useEffect, useState } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';

function LinkedInCallbackContent() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const [status, setStatus] = useState<'loading' | 'success' | 'error'>('loading');
  const [message, setMessage] = useState('');
  
  useEffect(() => {
    const statusParam = searchParams.get('status');
    const messageParam = searchParams.get('message');
    
    if (statusParam === 'success') {
      setStatus('success');
      setMessage('LinkedIn connected successfully!');
      setTimeout(() => {
        router.push('/create');
      }, 1500);
    } else {
      setStatus('error');
      setMessage(messageParam || 'Failed to connect LinkedIn');
    }
  }, [searchParams, router]);

  return (
    <div className="min-h-screen bg-[var(--background)] flex items-center justify-center p-6">
      <div className="text-center max-w-sm">
        {status === 'loading' && (
          <>
            <div className="w-12 h-12 border-4 border-[var(--primary)] border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
            <p className="text-[var(--foreground)]">Connecting LinkedIn...</p>
          </>
        )}
        
        {status === 'success' && (
          <>
            <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-[var(--cta)]/10 flex items-center justify-center">
              <svg className="w-8 h-8 text-[var(--cta)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <p className="text-xl font-bold text-[var(--foreground)] mb-2">Success!</p>
            <p className="text-[var(--muted)]">{message}</p>
          </>
        )}
        
        {status === 'error' && (
          <>
            <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-[var(--error)]/10 flex items-center justify-center">
              <svg className="w-8 h-8 text-[var(--error)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </div>
            <p className="text-xl font-bold text-[var(--foreground)] mb-2">Error</p>
            <p className="text-[var(--muted)] mb-4">{message}</p>
            <button
              onClick={() => router.push('/account')}
              className="px-6 py-3 bg-[var(--primary)] text-white rounded-xl font-semibold"
            >
              Go to Account
            </button>
          </>
        )}
      </div>
    </div>
  );
}

export default function LinkedInCallbackPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-[var(--background)] flex items-center justify-center">
        <div className="w-12 h-12 border-4 border-[var(--primary)] border-t-transparent rounded-full animate-spin"></div>
      </div>
    }>
      <LinkedInCallbackContent />
    </Suspense>
  );
}