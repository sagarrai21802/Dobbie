'use client';

import Link from 'next/link';
import { PrimaryButton } from '@/components/buttons';

export default function AuthPage() {
  return (
    <div className="min-h-screen bg-[var(--background)] flex flex-col">
      <div className="flex-1 flex flex-col items-center justify-center p-6">
        <div className="w-full max-w-sm">
          <div className="text-center mb-10">
            <h1 className="text-4xl font-bold text-[var(--foreground)] mb-3">Dobbie</h1>
            <p className="text-lg text-[var(--muted)]">Automate your LinkedIn content</p>
          </div>

          <div className="space-y-4">
            <Link href="/auth/signin" className="block">
              <PrimaryButton text="Sign In" onClick={() => {}} />
            </Link>

            <Link href="/auth/signup" className="block">
              <button
                className="w-full h-14 rounded-xl font-semibold text-[var(--primary)] text-base
                  bg-transparent border-2 border-[var(--primary)]
                  hover:bg-[var(--primary)] hover:text-white
                  transition-colors duration-150"
              >
                Sign Up
              </button>
            </Link>
          </div>

          <p className="text-center text-sm text-[var(--muted)] mt-8">
            By continuing, you agree to our Terms of Service
          </p>
        </div>
      </div>
    </div>
  );
}