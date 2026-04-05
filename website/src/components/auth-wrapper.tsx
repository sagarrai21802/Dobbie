'use client';

import React, { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import { authService } from '@/lib/auth';
import { LoadingScreen } from '@/components/loading';

interface AuthWrapperProps {
  children: React.ReactNode;
}

export function AuthWrapper({ children }: AuthWrapperProps) {
  const router = useRouter();
  const pathname = usePathname();
  const [isChecking, setIsChecking] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  useEffect(() => {
    const checkAuth = async () => {
      try {
        const user = await authService.getCurrentUser();
        setIsAuthenticated(!!user);
      } catch {
        setIsAuthenticated(false);
      } finally {
        setIsChecking(false);
      }
    };

    checkAuth();
  }, []);

  useEffect(() => {
    if (isChecking) return;

    const publicPaths = ['/auth/signin', '/auth/signup', '/auth/google/callback', '/auth/linkedin/callback'];
    const isPublicPath = publicPaths.includes(pathname);

    if (!isAuthenticated && !isPublicPath) {
      router.push('/auth/signin');
    } else if (isAuthenticated && (pathname === '/auth/signin' || pathname === '/auth/signup')) {
      router.push('/');
    }
  }, [isChecking, isAuthenticated, pathname, router]);

  if (isChecking) {
    return <LoadingScreen message="Loading..." />;
  }

  return <>{children}</>;
}