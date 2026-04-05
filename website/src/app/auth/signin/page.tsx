'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Input } from '@/components/input';
import { PrimaryButton, SecondaryButton } from '@/components/buttons';
import { authService } from '@/lib/auth';
import { API_CONFIG } from '@/lib/api-config';

const API_BASE_URL = API_CONFIG.baseUrl || 'http://localhost:8000';

function GoogleSignInButton() {
  const handleGoogleSignIn = () => {
    // Redirect to backend OAuth authorize endpoint (BFF pattern)
    window.location.href = `${API_BASE_URL}/api/v1/auth/google/authorize`;
  };

  return (
    <SecondaryButton
      text="Continue with Google"
      onClick={handleGoogleSignIn}
    />
  );
}

export default function SignInPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setIsLoading(true);

    try {
      await authService.login(email, password);
      router.push('/');
    } catch (err: unknown) {
      if (err && typeof err === 'object' && 'response' in err) {
        const axiosErr = err as { response?: { data?: { detail?: string } } };
        setError(axiosErr.response?.data?.detail || 'Login failed. Please try again.');
      } else {
        setError('Login failed. Please try again.');
      }
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[var(--background)] flex flex-col">
      <div className="p-6">
        <Link href="/auth" className="text-[var(--primary)]">
          ← Back
        </Link>
      </div>

      <div className="flex-1 flex flex-col items-center justify-center p-6">
        <div className="w-full max-w-sm">
          <h1 className="text-3xl font-bold text-[var(--foreground)] mb-2">Welcome Back</h1>
          <p className="text-[var(--muted)] mb-8">Sign in to continue</p>

          <form onSubmit={handleSubmit} className="space-y-4">
            <Input
              type="email"
              value={email}
              onChange={setEmail}
              placeholder="Email"
              label="Email"
              required
            />

            <Input
              type="password"
              value={password}
              onChange={setPassword}
              placeholder="Password"
              label="Password"
              required
            />

            {error && (
              <p className="text-[var(--error)] text-sm text-center">{error}</p>
            )}

            <PrimaryButton
              text="Sign In"
              onClick={() => {}}
              isLoading={isLoading}
            />
          </form>

          <div className="relative my-6">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-[var(--border)]"></div>
            </div>
            <div className="relative flex justify-center text-sm">
              <span className="px-4 bg-[var(--background)] text-[var(--muted)]">or</span>
            </div>
          </div>

          <GoogleSignInButton />

          <p className="text-center text-sm text-[var(--muted)] mt-6">
            Don't have an account?{' '}
            <Link href="/auth/signup" className="text-[var(--primary)] font-medium">
              Sign Up
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}